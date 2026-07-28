# moonbit-indexmap

[![License](https://img.shields.io/badge/license-Apache%202.0-blue.svg)](LICENSE)
[![CI](https://github.com/aurasuisui/moonbit-indexmap/actions/workflows/ci.yml/badge.svg)](https://github.com/aurasuisui/moonbit-indexmap/actions/workflows/ci.yml)

A hash map that preserves insertion order — MoonBit port of Rust's [`indexmap`](https://github.com/indexmap-rs/indexmap) crate.

MoonBit's built-in `Map[K, V]` preserves insertion order but offers no way to address entries by position. IndexMap pairs that insertion-order guarantee with **index-based access** (`get_index`, `get_index_of`, `first`, `last`, `pop`, `swap_remove_index`), an **Entry API**, and order-sensitive `Eq`/`Hash`, making it ideal for configuration parsing, JSON serialization, LRU caches, and deterministic tests.

```moonbit
let map = @aurasuisui/indexmap.new()
map.insert("b", 2) |> ignore
map.insert("a", 1) |> ignore
map.insert("c", 3) |> ignore

// Iteration follows insertion order: b, a, c
let iter = map.iter()
while true {
  match iter.next() {
    Some((k, v)) => println("\{k}: \{v}")
    None => break
  }
}
```

## Features

- **Insertion-order iteration** — entries yield in the order they were first inserted
- **O(1) average lookups** — Robin Hood open-addressing hash table
- **Index-based access** — `get_index(i)`, `first()`, `last()`, `pop()`
- **Entry API** — `OccupiedEntry` / `VacantEntry` for in-place manipulation
- **IndexSet** — ordered hash set with `is_disjoint`, `is_subset`, `is_superset`
- **JSON support** — `ToJson` preserves key order; `from_json` / `from_json_with`
  deserialize back (order-preserving, so `from_json(m.to_json()) == m` is a lossless
  round-trip for `String`-keyed maps)
- **Standard traits** — `Debug`, `Default`, `Show`, `Hash`, `Eq`, `ToJson` for both IndexMap and IndexSet
- **QuickCheck support** — `Arbitrary` trait for property-based testing

## Installation

Add to `moon.mod`:

```json
{ "dependencies": { "aurasuisui/indexmap": "0.3.3" } }
```

Or clone directly:

```bash
git clone https://github.com/aurasuisui/moonbit-indexmap
```

## API Overview

### IndexMap[K, V]

| Category | Methods |
|----------|---------|
| Construct | `new()`, `with_capacity(n)`, `from_array(entries)`, `default()`, `copy()` |
| Query | `len()`, `is_empty()`, `capacity()`, `load_factor()`, `max_probe()` |
| Core | `insert(k, v) -> V?`, `get(k) -> V?`, `remove(k) -> V?`, `contains(k) -> Bool`, `clear()`, `get_mut(k, f)` |
| Entry | `entry(k) -> EntryView` (Occupied: `get`/`insert`/`remove`/`key`, Vacant: `insert`/`key`) |
| Index | `get_index(i)`, `get_full(k)`, `get_index_of(k)`, `first()`, `last()`, `pop()`, `swap_remove_index(i)` |
| Capacity | `reserve(n)`, `shrink_to_fit()` |
| Iterate | `iter()`, `keys()`, `values()`, `for_each(f)`, `into_iter()`, `into_array()` |
| Bulk | `retain(f)`, `sort_by_key()`, `sort_by(cmp)`, `drain()`, `extend_from_array(entries)` |
| Traits | `Debug`, `Default`, `Show`, `Hash`, `Eq`, `ToJson` |

### IndexSet[K]

| Category | Methods |
|----------|---------|
| Construct | `new()`, `with_capacity(n)`, `from_array(elements)`, `default()`, `copy()` |
| Query | `len()`, `is_empty()`, `capacity()` |
| Core | `insert(v) -> Bool`, `contains(v) -> Bool`, `remove(v) -> Bool`, `clear()` |
| Set ops | `is_disjoint(other)`, `is_subset(other)`, `is_superset(other)` |
| Iterate | `iter()`, `into_array()` |
| Bulk | `retain(f)`, `drain()`, `extend_from_array(elements)` |
| Traits | `Debug`, `Default`, `Show`, `Hash`, `Eq`, `ToJson` |

## Design

Two parallel structures:

1. **Robin Hood hash table** (`Array[Entry[K, V]?]`) — O(1) average lookup, reduced probe variance
2. **Order array** (`Array[K]`) — tracks insertion order for deterministic iteration

Deletion uses tombstone markers to preserve probe chains, with automatic rehash when the tombstone ratio exceeds 25%.

### Compared to built-in Map

| Property | `Map[K, V]` | `IndexMap[K, V]` |
|----------|-------------|-------------------|
| Lookup | O(1) avg | O(1) avg |
| Iteration order | Insertion order (linked map) | Insertion order |
| Index access (`get_index`, `first`, `pop`, …) | No | Yes |
| Entry API (`Occupied` / `Vacant`) | No | Yes |
| `Eq` / `Hash` semantics | Independent of insertion order | Dependent on insertion order |

## Gotchas

Known design choices and limitations — see the
[independent test report](https://github.com/aurasuisui/indexmap-test-suite/blob/main/TEST_REPORT.md)
for reproduction details.

1. **`get_mut` semantics: the callback's return value is authoritative
   (reworked in v0.3.3).** `get_mut(key, f)` passes the current value to `f`
   (or `None` if the key is absent) and then re-applies the result through
   `insert`/`remove`: `Some(v)` stores `v` under `key` (inserting it if the
   callback removed it), and `None` removes `key`. Returning `None` therefore
   removes the key *even if the callback re-inserted it* — return `Some(v)` to
   keep a value. Because the result is re-applied via a fresh probe, the callback
   may safely mutate the map (including triggering a resize). Earlier versions
   wrote back to a stale bucket index, which could corrupt the table and silently
   broke plain deletion.

2. **`Eq` and `Hash` are insertion-order-sensitive.** Two maps with identical
   key-value pairs but different insertion orders are *not* equal and produce
   different hashes. Avoid using an `IndexMap` or `IndexSet` as a key in another
   hash container unless you can guarantee consistent insertion order.

3. **`swap_remove_index` is actually O(n) shift-remove.** Despite the name
   (kept for Rust indexmap API compatibility), it calls the order-preserving
   `remove` path — elements after the target are shifted one slot left. It does
   *not* swap with the last element in O(1). If you need actual O(1)
   order-breaking removal, you would need a dedicated method that directly
   swaps with the last element before popping — `swap_remove_index` does not
   do this.

4. **`max_probe()` is refreshed after `sort_by` / `sort_by_key` (fixed in v0.3.2).**
   Sorting rebuilds `order[]` and `positions[]`; as of v0.3.2 the internal
   `max_probe_distance` is also recalculated after sorting, so `max_probe()`
   reports the current (post-sort) probe distribution. (Sorting does not move
   buckets, so previously the value happened to remain correct — it is now
   maintained explicitly.)

5. **Don't mutate the map while an iterator is active.** Each iterator snapshots
   the map's mutation version at creation; if the map is structurally modified
   (`insert`, `remove`, `clear`, `retain`, `sort_by*`, `reserve`, `shrink_to_fit`,
   or an Entry / `get_mut` mutation) before the iterator is exhausted, the next
   `next()` aborts with `IndexMap: map mutated during iteration` — true fail-fast,
   added in v0.3.3. Earlier versions silently skipped entries and could crash with
   an out-of-bounds access. Finish all mutations first, then create a fresh
   iterator.

## Independent Test Report

An independent black-box test suite ([`indexmap-test-suite`](https://github.com/aurasuisui/indexmap-test-suite))
covers every public API, stress up to 100k entries, property-based invariants,
edge-case traps, **plus** (as of the latest reorganization) HashDoS / adversarial
collision, fail-fast iterator aborts, real benchmarks + a regression gate,
`from_json` round-trip, and Rust `indexmap` differential tests. The library
itself keeps the **white-box + library-specific** tests in-repo — the model/oracle
property test, fuzz harness, and IndexMap-vs-builtin-Map parity (see
[CLAUDE.md](CLAUDE.md) for the per-file breakdown and
[`docs/RELEASE_CHECKLIST.md`](docs/RELEASE_CHECKLIST.md) for the full Tier 0–4
status against the release checklist).

> **Status caveat:** the `from_json` API addition and test-suite reorganization
> described here are **unreleased** (VERSION is still `0.3.3`). See
> [CHANGELOG.md](CHANGELOG.md) `[Unreleased]` and the duplicate-key insert bug
> note in [`docs/BUG-insert-duplicate-key.md`](docs/BUG-insert-duplicate-key.md)
> before relying on this state.

## Examples

The example packages live in [`cmd/`](cmd/):

- `cmd/lru_cache` — LRU eviction demo
- `cmd/config_parse` — order-preserving config parser
- `cmd/json_order` — `ToJson` key ordering

> **Note:** the `cmd/*` example packages stay out of `moon.work` (they import
> the *published* `aurasuisui/indexmap`, smoke-testing the user-facing install
> path) but use `pkgtype(kind: "executable")` (migrated off the deprecated
> `options("is-main")`), so the CI `examples` job compiles and runs each one
> against the published version. To run one locally: `cd cmd/<name> && moon run .`.

## Development

```bash
moon check            # Type check (0 warnings, 0 errors; --deny-warn clean)
moon test             # Run all in-package tests (white-box + library-specific)
moon test --target <t># t = wasm-gc | wasm | js | native (CI tests all four)
moon fmt              # Format code
moon bench -p aurasuisui/indexmap   # Statistical benchmarks
```

CI: `check` job (fmt / check --deny-warn / mbti drift) + a `target × mode` test
matrix + an `examples` job + a `bench` job. The black-box robustness battery
(HashDoS, fail-fast, perf, Rust differential, JSON round-trip) lives in
[`indexmap-test-suite`](https://github.com/aurasuisui/indexmap-test-suite). See
[CONTRIBUTING.md](CONTRIBUTING.md) for project layout, roadmap, and contribution
guidelines.

## License

Apache 2.0 — see [LICENSE](LICENSE).

Built for the **MoonBit Open Source Ecosystem Competition 2026**.
