# Changelog

All notable changes to moonbit-indexmap will be documented in this file.

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
