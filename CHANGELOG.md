# Changelog

All notable changes to moonbit-indexmap will be documented in this file.

## [Unreleased]

### Changed
- **Module renamed** from `indexmap` to `aurasuisui/indexmap` for mooncakes.io publishing
- **O(1) remove**: `remove_from_order` rewritten from linear scan (O(n)) to swap-remove with position map
- **O(1) get_index_of**: now uses direct position lookup instead of linear scan
- **O(1) last / pop**: simplified without fallback loops
- `retain` rewritten as collect-then-remove to work with swap-remove semantics

### Added
- `Eq` and `Hash` trait implementations for IndexSet
- Examples directory: `config_parse.mbt`, `lru_cache.mbt`, `json_order.mbt`
- Benchmark comparison tests: IndexMap vs built-in Map

### Fixed
- `get_mut` deletion now uses tombstone pattern (was setting bucket to `None`, breaking probe chains)
- VERSION fixed to "0.2.0" in `lib.mbt`, `moon.mod.json`, and test

### Removed
- Dead code: `robin_hood_find_or_insertion_point` alias, unused `sort_entries`/`sort_entries_by` wrappers
- Dead code from `hash.mbt`: unused constants and functions

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
- Updated ROADMAP.md and CHANGELOG.md

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
- Documentation: README, ARCHITECTURE, CONTRIBUTING, ROADMAP, CHANGELOG
