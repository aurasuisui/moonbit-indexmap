# Changelog

All notable changes to moonbit-indexmap will be documented in this file.

## [Unreleased]

## [0.4.0] - 2026-08-01

### Added
- **`from_json` / `from_json_with` deserialization.** `IndexMap::from_json(json)`
  decodes a JSON object into an `IndexMap[String, V]` (`V : FromJson`), preserving
  insertion order (core JSON objects are ordered). Because `Eq` is order-sensitive,
  `from_json(m.to_json()) == m` is a lossless round-trip for String-keyed maps.
  `from_json_with(json, parse_key)` parses each object key from `String` into `K`
  for non-String keys. A non-object JSON value raises `@json.JsonDecodeError`.
  Package-level `from_json` / `from_json_with` aliases mirror `new`.
  - Public API addition; `pkg.generated.mbti` updated. Warrants a **minor version
    bump (0.4.0)** at release.

### Changed
- **Reworked deletion and lookup internals.** Removed tombstones and the
  tombstone-cleanup rehash path. `remove` now uses backward-shift compaction,
  `load_factor()` is strictly `len / capacity`, and a unified exhaustive
  `locate` path serves lookup, insertion, Entry and rehash operations. Normal
  insertion and rehash share `robin_hood_insert_into`.
- Replaced the 14 deprecated multi-trait-bound dot-calls with qualified calls
  (`Hash::hash`, `Hash::hash_combine`, `Show::output`, `Show::to_string`,
  `ToJson::to_json`, `Compare::compare`). `moon check --deny-warn` is now clean;
  no public-signature change (`pkg.generated.mbti` unaffected by this item).
- Replaced 3 deprecated `to_repr(x)` call sites with `Repr(x)` (`map.mbt`/`set.mbt
  `Debug` impls); `--deny-warn` clean. Behavior-preserving.

### Changed (tests — reorganization: library minimal, suite strong)
The library's in-package tests were trimmed to **white-box + library-specific**
only; black-box robustness tests moved to the separate `indexmap-test-suite`
repository. Net effect in this repo:
- **Removed** `src/property_test.mbt` (47 hand-written deterministic invariants
  — fully subsumed by `model_wbtest.mbt`'s randomized oracle + the suite's
  stress tests; no coverage lost).
- **Removed** `src/bench_test.mbt` (36 large-N correctness tests — the model/fuzz
  streams and the suite's stress tests cover scale). Kept its 7 *unique* tests
  (IndexMap-vs-builtin-Map parity + benign-key probe bound) as
  `src/cmp_builtin_test.mbt`.
- **Moved to `indexmap-test-suite/tests/`** (black-box, `@indexmap.` prefix):
  `adversarial_test.mbt` (HashDoS), `failfast_panic_test.mbt` (fail-fast abort),
  `perf_bench_test.mbt` + `perf_gate_test.mbt` (real benchmarks + regression gate).

### Changed (CI)
- CI reworked into `check` (`fmt --check` / `check --deny-warn` / mbti drift) +
  a `target × mode` matrix (`wasm-gc`/`wasm`/`js`/`native` × `debug`/`release`)
  + an `examples` job. The statistical **bench job moved to the suite CI**
  (since `perf_bench_test.mbt` now lives in `indexmap-test-suite`).
- `cmd/*` re-added to `moon.work` (the `options("is-main")` / `version: latest`
  conflict is resolved by `pkgtype(kind: "executable")`). The `examples` job now
  runs them against the **local** library via `moon run cmd/<name>` —
  registry-independent. This fixes the CI failure where `cmd/*` could not resolve
  the (unpublished) package from mooncakes.

### Added (tests — RELEASE_TEST_CHECKLIST Tier 1/2)
- Model / stateful property tests + white-box internal-invariant checks
  (`src/model_wbtest.mbt`, **stays in-repo** — reads private fields): a naive-array
  oracle driven by hand-crafted golden sequences, LCG streams, and QuickCheck,
  asserting step-by-step agreement and all eight CLAUDE.md invariants after every
  mutation.
- Op-stream + decoded-stream fuzzing (`src/fuzz_wbtest.mbt`, **stays in-repo** —
  shares the oracle's private probe helpers).
- HashDoS / adversarial-collision tests (now in the **suite** as
  `tests/adversarial_test.mbt`): total and clustered collision floods, with a
  deterministic assertion that probe distance stays bounded and scales linearly.
- Fail-fast iterator panic tests (now in the **suite** as
  `tests/failfast_panic_test.mbt`): in-process assertion of the mid-iteration
  `abort` via the `test "panic …"` convention.
- Real benchmarks + scaling-ratio regression gate (now in the **suite** as
  `tests/perf_bench_test.mbt` + `tests/perf_gate_test.mbt`): `moon bench`
  statistical timing, plus self-normalizing ratio gates that fail only on
  superlinear regression.
- `from_json` round-trip + golden + Rust `indexmap` differential (in the **suite**
  as `tests/json_roundtrip_test.mbt` + `tests/rust_diff_test.mbt`).

### Fixed
- **Duplicate-key insert corruption.** Tombstone reuse could create a bucket
  layout where the insertion-only early-stop probe missed an existing key found
  by ordinary lookups, returning `None` and appending a duplicate key. The
  tombstone-free deletion engine and unified `locate` path remove that split.
  The 8000-step model, insert-heavy model and 60-seed fuzz regressions are now
  required to pass; see `docs/BUG-insert-duplicate-key.md`.

## [0.3.3] - 2026-07-22

Post-competition quality pass fixing four correctness defects named by the
acceptance review (Entry expansion, `get_mut` deletion, JSON keys) plus a fourth
(iterator invalidation), and closing the reproduced edge-case gaps in the test
suite (255 → 277 tests).

### Fixed
- **Entry API + expansion (could hang / corrupt).** `entry()`'s `VacantEntry::insert`
  skipped the resize gate, so filling the table purely through the Entry API drove it
  to 100% occupancy and the next insert spun forever in `robin_hood_insert_at`.
  `VacantEntry::insert` now delegates to `insert` (resize-aware, fresh probe);
  `OccupiedEntry::get`/`insert` re-probe by key instead of trusting a cached
  `bucket_index` that went stale after a resize or a displacing insert; and
  `robin_hood_insert_at` gained a full-circle termination guard as defense in depth.
  The now-unused `bucket_index` field was removed from both entry structs.
- **`get_mut` deletion (silent corruption).** The callback's return value is now
  authoritative and re-applied via a fresh probe through `insert`/`remove`:
  `Some(v)` stores `v` (inserting if the callback removed the key), `None` removes the
  key. This fixes plain deletion (the v0.3.2 BUG-001 `contains` guard had turned it
  into a no-op), the double `len--` / double tombstone when a callback removes the key
  itself, ghost entries (remove-then-`Some`), and stale-index mis-writes when a
  callback triggers a resize.
  - **Behavior change:** returning `None` removes the key even if the callback
    re-inserted it (the v0.3.2 "preserve re-insert" behavior is removed); use
    `Some(v)` to keep a value. `get_mut` on a missing key with `Some(v)` now inserts
    (upsert) rather than discarding.
- **`ToJson` key mangling.** Object keys were built via `@debug.to_string(k.to_json())`,
  which rendered a String key `name` as the literal object key `String("name")` (and
  `42` as `Number(42)`). Keys now use the key's `Show` rendering (`k.to_string()`),
  matching `moonbitlang/core`'s own `Map` convention — String keys are canonical.
  - **Breaking (bound change):** the `IndexMap` `ToJson` impl bound changed from
    `K : ToJson` to `K : Show`. The previous output was unusable, so no working code
    relied on it; `pkg.generated.mbti` updated accordingly.
- **Iterators are now truly fail-fast.** `iter`/`keys`/`values` snapshot a private
  mutation `version` at creation and abort with `IndexMap: map mutated during
  iteration` if the map is structurally modified before the iterator is exhausted.
  Previously, mutating mid-iteration silently skipped entries and could crash with an
  out-of-bounds access (README Gotcha #5 claimed "fail-fast" but it was not).

### Tests
- Regression tests for each of the four fixes (each fails on the pre-fix code and
  passes after).
- Corrected vacuous/misleading tests: `sort_by_key`+`max_probe` (now also asserts the
  sorted order), the `eq trait` tests (now actually use `==` and `.hash()`; added a
  hash-equality test — the `IndexMap` `Eq`/`Hash` impls were previously never
  executed), the `to_json` QuickCheck test (now verifies every key appears verbatim),
  `get_mut` on a missing key (now asserts the no-op / upsert behavior), and the
  `swap_remove` property test (now asserts the resulting order).
- Ported the independent suite's reproduced edge cases: filling via the Entry API past
  capacity, an `OccupiedEntry` handle across a resize, `get_mut` delete/remove/resize
  variants, `ToJson` output for String and non-string keys, `swap_remove_index` order
  semantics, `from_array` with duplicate keys (IndexMap + IndexSet), edge keys (empty
  string, negative int, Bool, Char), a 16→256 resize cascade, sort/copy/drain/retain
  over tombstones, 50% mass deletion, `for`-in iteration, and `IndexSet::to_json`.

### Docs
- README: reframed the built-in-`Map` comparison (the current core `Map` is a linked
  hash map that preserves insertion order with order-independent `Eq`; IndexMap's
  differentiator is index access + the Entry API); rewrote Gotcha #1 (authoritative
  `get_mut`) and Gotcha #5 (true fail-fast).
- `cmd/json_order`: corrected the stale "built-in Map does NOT preserve order" framing.

## [0.3.2] - 2026-07-12

### Fixed
- **BUG-001**: `get_mut` callback that re-inserts the same key and then returns
  `None` no longer loses data. A `contains(key)` guard is now checked in the `None`
  branch before writing the tombstone — if the key was re-inserted by the callback
  (e.g. `map.insert(same_key, new_val)` inside `f`), the tombstone and deletion
  logic are skipped, so the just-inserted value survives. New regression test
  `IndexMap get_mut callback re-inserts same key then None preserves value` added.
- **WARN-003**: `max_probe_distance` is now explicitly recalculated after
  `sort_by` and `sort_by_key` via a new internal `recalc_max_probe()` helper.
  Sorting only rebuilds `order[]`/`positions[]` and does not move entries between
  buckets, so the value previously happened to stay correct — it is now maintained
  explicitly and is robust to future bucket-level changes. New test
  `sort_by_key refreshes max_probe` added. README Gotcha #4 updated to reflect the
  fix (marked "fixed in v0.3.2").

### Docs
- **WARN-002**: README Gotcha #3's self-contradictory last sentence clarified —
  `swap_remove_index` is O(n) order-preserving shift-remove, not O(1)
  order-breaking. The misleading "use `swap_remove_index` [for O(1) order-breaking
  removal]" phrasing is gone.
- README Gotcha #1 (`get_mut` data loss) updated to reflect BUG-001 being fixed
  (marked "fixed in v0.3.2"). Gotchas #2 (`Eq`/`Hash` order-sensitivity) and #5
  (fail-fast iterator invalidation) remain valid known limitations, unchanged.

### Changed
- **Workspace narrowed to the library only**: `moon.work` now lists just `.`,
  excluding the `cmd/*` example packages. This keeps the library's CI pipeline
  (`moon fmt --check` / `moon check` / `moon info && git diff --exit-code` / `moon test` /
  `moon build`) green across the CI `latest` toolchain without being tripped by example-package main
  declaration syntax (`options("is-main")` vs `pkgtype(kind: "executable")`, which is
  toolchain-version-sensitive). The example sources remain in `cmd/` for reference;
  see the README Examples section for how to run them with a separately-configured
  toolchain. `cmd/*/moon.pkg` are unchanged from v0.3.1 (`options("is-main": true)`).
- Version bump 0.3.1 → 0.3.2 (patch). No API changes to the library. `cmd/*` example
  `moon.mod` deps and the README install snippet updated to `@0.3.2`.
- Test suite now **255** (the two regression tests above bring the v0.3.1 count of
  253 to 255: `map_test` 111, `set_test` 50, `property_test` 47, `bench_test` 36,
  `arbitrary_test` 11).

## [0.3.1] - 2026-07-12

### Changed
- **Migrated all `inspect` calls to `debug_inspect`** across tests, examples, and source.
  `inspect` was deprecated by `moonbitlang/core` in favor of `debug_inspect`, which binds
  to the `Debug` trait instead of `Show`. All `content=` snapshots were refreshed
  (via `moon test -u`) to the `Debug` rendering format.
- **`Show::to_string` → `@debug.to_string`** in `src/map.mbt` (ToJson impl) and
  `cmd/json_order` example. Replaces the deprecated `Show::to_string` on `Json` with
  the `Debug`-based `@debug.to_string`. `src/moon.pkg` and `cmd/json_order/moon.pkg`
  now import `moonbitlang/core/debug`.
- `cmd/config_parse` and `cmd/json_order` examples: interpolation in `println` replaced
  with string concatenation to silence `[0002]` unused-value warnings (MoonBit's
  interpolation elides the variable-use detection).
- `cmd/json_order`: `Map::new()` → `Map([])` (deprecated constructor).

### Fixed
- Two loop-based tests (`sequential insert and iterate`, `property: insert order
  equals iteration order`) rewritten to use `@test.assert_eq` instead of
  `debug_inspect` inside hot loops — expect-test snapshots are not stable when a
  single `debug_inspect` runs N times with N different values, which previously
  led to file corruption on `moon test -u`.
- `property: first equals get_index 0`: explicit `ignore(gk)` for an unused binding.

### Result
- `moon check`: **0 warnings, 0 errors** (was 110 warnings)
- `moon check --deny-warn` passes (exit 0)
- `moon test`: 253/253 pass
- No breaking API changes (patch release)

## [0.3.0] - 2026-07-07

### Breaking
- **`extend` renamed to `extend_from_array`**: the method name `extend` is now a
  reserved keyword in MoonBit (`[0035]`). `IndexMap::extend` and `IndexSet::extend`
  are renamed to `extend_from_array`. Users upgrading from 0.2.x must update call sites.

### Added
- **Runnable example packages in `cmd/`**: three self-contained MoonBit programs —
  `cmd/lru_cache` (LRU eviction demo), `cmd/config_parse` (order-preserving config parser),
  `cmd/json_order` (JSON key-order demo). Run with `moon run cmd/<name>`.

### Changed
- **CI updated** to the competition's required 4-step pipeline: `moon fmt --check`,
  `moon check`, `moon info && git diff --exit-code`, `moon test`, `moon build`.
  Toolchain pinned to `0.1.20260703`. (Previously used `latest` and lacked `moon info`.)
- **Removed deprecated `moon.mod.json`**: the toolchain now fully supports TOML
  `moon.mod` for `moon publish`; the dual-manifest warning is eliminated.
- **`src/pkg.generated.mbti`** committed and tracked; `moon info && git diff --exit-code`
  in CI ensures it stays current with the public API.

### Fixed
- `config_parse` and `lru_cache` examples adapted to the 0.1.20260703 toolchain
  (StringView from `split()`, `fn[V]` generic syntax, `starts_with` → `has_prefix`).

## [0.2.1] - 2026-07-05

### Changed
- Bumped version to 0.2.1 for re-publish to mooncakes.io (no code changes; v0.2.0 already on the registry)
- **README Gotchas section**: documented the 1 confirmed bug + 4 design warnings found
  by the independent `indexmap-test-suite` (get_mut same-key delete+insert data loss,
  insertion-order-sensitive `Eq`/`Hash`, `swap_remove_index` is O(n) shift-remove,
  stale `max_probe()` after `sort_by`/`sort_by_key`, fail-fast iterator invalidation)
  as known limitations — no source code changed
- **README Independent Test Report section**: linked the 485-test black-box suite
- **examples/README.md** (new): clarified the three snippet files are copy-paste
  examples, not a runnable package
- **IMPROVEMENT.md**: corrected 6 stale items that no longer matched the source
  after the iterator migration landed (v0.2.0 tag exists, `moon publish` done,
  `for..in` supported via built-in `Iter[T]`, `Arbitrary` done, iterator-rename
  plan superseded, `swap_remove_index` clarified) and fixed `moon.pkg.json` → `moon.pkg`
- **CONTRIBUTING.md**: added `arbitrary_test.mbt` (11 tests) to the test table and
  reconciled per-file counts to 253; added historical-record note to Known Issues
- **CHANGELOG.md**: dropped references to the removed `ROADMAP.md` and `ARCHITECTURE.md`

## [0.2.x — pre-release development notes]

> These changes shipped across the 0.2.0 / 0.2.1 releases. This block was never
> collapsed into a dated entry and is preserved here as a historical record; it
> does not represent unreleased work.

### Changed
- **Module renamed** from `indexmap` to `aurasuisui/indexmap` for mooncakes.io publishing
- **Order-preserving remove**: `remove_from_order` uses shift-remove (O(n)) so the insertion
  order of remaining elements is preserved. (A swap-remove prototype broke ordering and was
  reverted before release.)
- `get_index_of` uses direct position lookup; `last` / `pop` simplified without fallback loops
- `retain` rewritten as collect-then-remove, compatible with shift-remove semantics
- **Iterators migrated to built-in `Iter[T]`**: `iter()`, `keys()`, `values()` now return
  `Iter[(K, V)]` / `Iter[K]` / `Iter[V]` via `Iter::new`, supporting `for x in map { ... }`.
  The old custom `MapIter` / `MapKeys` / `MapValues` structs are removed; `count_remaining`
  is no longer available on these iterators (use `.collect().length()`).
- **Toolchain compatibility (moon 0.1.20260629)**: `Map::at` now returns `V` (use `Map::get`
  for `V?`); `Arbitrary` impls qualified as `@quickcheck.Arbitrary` and declared `pub impl`;
  `Map::new()` replaced with `Map([])`; exported `Show`/`Debug`/`Hash`/`Eq`/`ToJson` impls
  marked `pub impl`; project config migrated to `moon.mod` / `moon.pkg` format.
- Test count now 253 (was 220 at v0.2.0)

### Added
- `Eq` and `Hash` trait implementations for IndexSet (6 new tests)
- Examples directory: `config_parse.mbt`, `lru_cache.mbt`, `json_order.mbt`
- Benchmark comparison tests: IndexMap vs built-in Map (6 new tests)
- 10 new property tests for remove/retain ordering invariants
- `Arbitrary` trait implementations for IndexMap and IndexSet (QuickCheck support)
- 11 QuickCheck property tests in `arbitrary_test.mbt`
- GitHub issue/PR templates and CODEOWNERS

### Fixed
- `get_mut` deletion now uses tombstone pattern (was setting bucket to `None`, breaking probe chains)
- VERSION fixed to "0.2.0" in `lib.mbt`, `moon.mod`, and test
- CI workflow referenced a non-existent `actions/setup-moonbit`; switched to `hustcer/setup-moonbit@v1`
  and added `moon fmt --check` + `moon build` steps

### Removed
- Dead code: `robin_hood_find_or_insertion_point` alias, unused `sort_entries`/`sort_entries_by` wrappers
- Dead code from `hash.mbt`: unused constants and functions
- Custom `MapIter` / `MapKeys` / `MapValues` iterator structs (replaced by built-in `Iter[T]`)

## [0.2.0] - 2026-06-10

### Added
- `Debug` trait implementations for IndexMap and IndexSet (`Repr::opaque_` wrapping)
- `Default` trait implementations (`IndexMap::default()`, `IndexSet::default()`)
- `copy()` method for shallow copy of IndexMap and IndexSet
- `get_mut()` for mutable value access via callback (supports in-place update/insert/delete)
- `into_iter()` consuming iterator (`IntoIter[K, V]` — since renamed `IntoMapIter[K, V]` — with `next()`, `collect()`, `count_remaining()`)
- `into_array()` consuming conversion to array (both IndexMap and IndexSet)
- `ToJson` trait implementations (order-preserving JSON serialization)
- 9 new tests for all v0.2.0 features (220 total)

### Changed
- Removed unused trait bounds from 8 internal functions ([0053] warnings fixed)
- Streamlined `probe_find`, `robin_hood_find`, `get_index_of`, `iter`, `values` signatures
- Eliminated unused variables in property tests ([0002] warnings fixed)
- Updated CHANGELOG.md

## [0.1.0] - 2026-05-25

### Added
- `IndexMap[K, V]` with insertion-order iteration via Robin Hood open-addressing hash table
- `IndexSet[K]` built on top of IndexMap with set operations
- Construction: `new()`, `with_capacity(n)`, `from_array(entries)`
- Core operations: `insert`, `get`, `remove`, `contains`, `clear`
- Entry API: `entry(key) -> EntryView` with `OccupiedEntry` and `VacantEntry`
- Index-based access: `get_index(i)`, `get_full(key)`, `get_index_of(key)`
- Positional access: `first()`, `last()`, `pop()`, `swap_remove_index(i)`
- Capacity management: `reserve(n)`, `shrink_to_fit()`, `capacity()`, `load_factor()`, `max_probe()`
- Iterators: `iter()`, `keys()`, `values()` with `next()`, `collect()`, `count_remaining()`
- Bulk operations: `retain(f)`, `sort_by_key()`, `sort_by(cmp)`, `drain()`, `extend(entries)` (renamed to `extend_from_array` in v0.3.0), `for_each(f)`
- Set operations: `is_disjoint`, `is_subset`, `is_superset`
- Trait implementations: `Show`, `Hash`, `Eq` for IndexMap; `Show` for IndexSet
- Comprehensive test suite (157 tests): unit tests, benchmark tests, property-based tests
- CI/CD pipeline with GitHub Actions
- Documentation: README, CONTRIBUTING, CHANGELOG
