# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build / Test / Lint

```bash
moon check                    # Type check (expect 14 [0083] warnings, 0 errors)
moon test                     # Run all 277 tests
moon test --test-filter "pattern"  # Run matching tests (use --test-filter, NOT -f)
moon fmt --check              # Format check (CI gate)
moon fmt                      # Auto-format
moon info                     # Regenerate pkg.generated.mbti
moon build                    # Build
```

The CI pipeline (`.github/workflows/ci.yml`) runs these in order: `moon fmt --check` → `moon check` → `moon info && git diff --exit-code` → `moon test` → `moon build`. The toolchain used is `version: latest` (via `hustcer/setup-moonbit@v1`). CI does **not** use `--deny-warn`, so `moon check` warnings are non-blocking.

## Architecture

IndexMap uses two parallel structures:

- **`buckets: Array[Entry[K, V]?]`** — Robin Hood open-addressing hash table. `None` = empty, `Some` with `hash == TOMBSTONE_HASH (-1)` = tombstone.
- **`order: Array[K]`** — insertion-order log. Iteration walks this, looks up each key in the hash table.
- **`positions: Map[K, Int]`** — key → index into `order[]`, enabling O(1) `get_index_of`.

Robin Hood hashing: when inserting and the incoming key has probed farther than the occupant, the incoming key steals the slot. This equalizes probe distances. Each `Entry` stores a `distance` field tracking displacement from its ideal bucket.

Three probe functions power all operations:
- `probe_find` — simple linear probe, used by `get`/`remove`/`contains`/`get_mut`/`rehash`
- `robin_hood_find` — Robin Hood probe with tombstone reuse, used by `insert`/`entry`
- `robin_hood_insert_at` — insert with displacement (rich-get-richer)

All deletion creates tombstones (preserving probe chains), then calls `remove_from_order` (O(n) shift-remove that preserves insertion order). Auto-rehash triggers when tombstone ratio exceeds 25%.

The struct also carries a private `mut version : Int` mutation counter. Every structural mutation bumps it; `iter`/`keys`/`values` snapshot it at creation and abort (`IndexMap: map mutated during iteration`) if it changes mid-iteration (true fail-fast).

`get_mut(key, f)` is authoritative: it re-applies `f`'s result via a fresh `insert`/`remove` — `Some(v)` upserts, `None` removes — so callbacks may safely mutate the map (including triggering a resize).

Key constants: `MIN_CAPACITY = 16`, load factor = 3/4 (0.75), `TOMBSTONE_HASH = -1`, `NO_DISTANCE = -1`.

## File Map

| File | Purpose |
|------|---------|
| `src/map.mbt` | `IndexMap[K,V]` — all core logic: hash table, insertion, deletion, iteration, Entry API, sorting |
| `src/set.mbt` | `IndexSet[K]` — thin wrapper over `IndexMap[K, Unit]` |
| `src/hash.mbt` | Shared constants (`LOAD_FACTOR_NUMERATOR`, `LOAD_FACTOR_DENOMINATOR`) |
| `src/lib.mbt` | Public API re-exports (`new()`, `with_capacity()`) + `VERSION` constant |
| `src/moon.pkg` | Package config — imports `moonbitlang/core/test`, `quickcheck`, `debug` |
| `src/pkg.generated.mbti` | Auto-generated public interface (CI-tracked via `moon info && git diff --exit-code`) |
| `src/map_test.mbt` | 131 black-box tests for IndexMap |
| `src/set_test.mbt` | 52 black-box tests for IndexSet |
| `src/property_test.mbt` | 47 invariant/property tests |
| `src/bench_test.mbt` | 36 correctness-under-load tests (5k-10k entries) |
| `src/arbitrary_test.mbt` | 11 QuickCheck property tests |
| `cmd/*/` | Example packages (lru_cache, config_parse, json_order) — **excluded from `moon.work`** |

## Invariants That Must Hold

- `self.len == count of non-tombstone entries in buckets`
- `self.order.length() == self.len`
- `self.positions.size() == self.len`
- `self.positions[key] == index` for each `order[index] == key`
- `self.mask == self.buckets.length() - 1`
- `self.buckets.length()` is a power of 2
- `self.max_probe_distance >= max(entry.distance for all live entries)`
- After `sort_by` / `sort_by_key`: call `recalc_max_probe()` to maintain the max_probe_distance invariant

## Test Conventions

All tests use `@aurasuisui/indexmap.` prefix (black-box). Use `debug_inspect` for expect-test snapshots. For assertions inside loops with varying values, prefer `@test.assert_eq` / `@test.fail` — `moon test -u` generates unstable snapshots when one `debug_inspect` runs N times with different values.

```moonbit
test "descriptive name in english" {
  let map = @aurasuisui/indexmap.new()
  map.insert("key", 42) |> ignore
  debug_inspect(map.get("key"), content="Some(42)")
}
```

## Style

- Functions: `snake_case` | Types: `PascalCase` | Constants: `UPPER_CASE`
- Doc comments: `///|` blocks on all public API and internal helpers
- Section separators: `// ---` with label
- Public API functions take `[K : Hash + Eq, V]` type params even for operations that don't hash (iteration, sorting) — the bounds are needed because iterators may look up keys in the hash table.

## Known Decisions

- **14 `[0083]` warnings (multi-trait-bound dot-call deprecation) are intentionally not fixed.** The fix (qualified calls like `Hash::hash(key)`) was written then reverted per user decision. CI passes without `--deny-warn`.
- **`cmd/*` packages are excluded from `moon.work`** because their `options("is-main")` syntax conflicts with CI's `version: latest` toolchain. Source remains for reference.
- **`swap_remove_index` is O(n), not O(1).** Despite the name (kept for Rust API compat), it delegates to the order-preserving `remove` path.
- **`Eq` and `Hash` are insertion-order-sensitive.** Two maps with same entries in different order are not equal. (The built-in `Map`'s `Eq` is order-independent; IndexMap's is not.)
- **`get_mut` return value is authoritative (v0.3.3).** `Some(v)` upserts, `None` removes — even if the callback re-inserted the key. The v0.3.2 "preserve re-insert" behavior was removed because it broke plain deletion.
- **`ToJson` keys use `k.to_string()` (`K : Show` bound, v0.3.3)** — canonical for String keys. The old `@debug.to_string(k.to_json())` mangled keys into `String("name")`.
- **Iterators are fail-fast (v0.3.3).** Mutating the map before an iterator is exhausted aborts with a clear message (via the mutation `version` counter).
