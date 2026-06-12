# Roadmap

## v0.1.0 — Core Data Structures

- [x] `IndexMap[K, V]` with insertion-order iteration
- [x] Robin Hood open-addressing hash table
- [x] `IndexSet[K]` built on top of IndexMap
- [x] Entry API (`entry() -> EntryView`)
- [x] Full iterator suite (`iter`, `keys`, `values`)
- [x] Bulk operations (`retain`, `sort_by_key`, `sort_by`, `drain`, `extend`)
- [x] Index access (`get_index`, `first`, `last`, `pop`, `swap_remove_index`)
- [x] Capacity management (`reserve`, `shrink_to_fit`)
- [x] Trait impls: `Show`, `Hash`, `Eq` for IndexMap; `Show` for IndexSet
- [x] 220 tests (unit + benchmark + property)

## v0.2.0 — Standard Library Integration

- [x] `Debug` trait for IndexMap and IndexSet
- [x] `Default` trait for IndexMap and IndexSet
- [x] `copy()` shallow copy method
- [x] `get_mut()` mutable access via callback
- [x] `into_iter()` / `IntoIter[K, V]` consuming iterator
- [x] `into_array()` consuming conversion
- [x] `ToJson` trait (order-preserving JSON serialization)
- [x] Bubble sort replaced with native `Array::sort_by` (O(n log n))
- [x] Dead code removed from hash.mbt

## Future

- [ ] `for .. in` loop support via standard `Iter[(K, V)]`
- [ ] QuickCheck `Arbitrary` trait for randomized testing
- [ ] `Eq` and `Hash` trait for IndexSet
- [ ] WebAssembly-optimized build target
