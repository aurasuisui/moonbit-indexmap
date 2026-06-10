# Roadmap

Planned features and improvements for moonbit-indexmap.

## v0.1.0 (Current)

- [x] `IndexMap[K, V]` core with insertion-order iteration
- [x] Robin Hood open-addressing hash table
- [x] `IndexSet[K]` built on top of IndexMap
- [x] Entry API (`entry()`) for in-place manipulation
- [x] `drain()` for consuming iteration
- [x] `reserve()` for explicit capacity management
- [x] `shrink_to_fit()` for memory optimization
- [x] `swap_remove_index()` for O(1) order-disrupting removal
- [x] `pop()` to remove the most recently inserted entry
- [x] `first()` / `last()` accessors
- [x] `for_each()` functional iteration
- [x] `extend()` bulk insertion
- [x] `sort_by()` custom comparator support
- [x] `IndexMap::from_array()` constructor
- [x] Comprehensive test suite (157 tests)
- [x] Benchmark tests
- [x] Property-based tests

## v0.2.0 (Current)

- [x] `Debug` trait implementations for IndexMap and IndexSet
- [x] `Default` trait implementations for IndexMap and IndexSet
- [x] `copy()` method for IndexMap and IndexSet
- [x] `get_mut()` for mutable value access via callback
- [x] `into_iter()` consuming iterator (`IntoIter[K, V]`)
- [x] `into_array()` consuming conversion to array
- [x] `ToJson` trait implementations (order-preserving JSON serialization)
- [x] Comprehensive tests for all new features (220 total)

## Future

- [ ] Thread-safe variant (`SyncIndexMap`)
- [ ] Sorted index map with custom comparators
- [ ] JSON serialization helpers
- [ ] WebAssembly-optimized build target
