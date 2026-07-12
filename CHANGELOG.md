# Changelog

All notable changes to moonbit-indexmap will be documented in this file.

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

## [Unreleased]

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
- `into_iter()` consuming iterator (`IntoIter[K, V]` with `next()`, `collect()`, `count_remaining()`)
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
- Bulk operations: `retain(f)`, `sort_by_key()`, `sort_by(cmp)`, `drain()`, `extend(entries)`, `for_each(f)`
- Set operations: `is_disjoint`, `is_subset`, `is_superset`
- Trait implementations: `Show`, `Hash`, `Eq` for IndexMap; `Show` for IndexSet
- Comprehensive test suite (157 tests): unit tests, benchmark tests, property-based tests
- CI/CD pipeline with GitHub Actions
- Documentation: README, CONTRIBUTING, CHANGELOG
