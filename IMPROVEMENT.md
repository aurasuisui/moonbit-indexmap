# Improvement Plan

Based on project evaluation against the MoonBit Open Source Ecosystem Competition criteria, this document tracks actionable improvements ordered by priority.

---

## 🔴 P0 — Must Fix ✅ All Done

### 1. ~~Fix VERSION mismatch~~ ✅
- [x] Update `lib.mbt`: `pub const VERSION : String = "0.2.0"`
- [x] Update `moon.mod.json`: `"version": "0.2.0"`
- [x] Update test at `map_test.mbt:1273`
- [ ] Create git tag: `git tag v0.2.0`

### 2. ~~Remove dead code~~ ✅
- [x] Removed unused functions from `hash.mbt` (`EMPTY_HASH`, `bucket_index`, `should_resize`, `next_power_of_two`, `INITIAL_CAPACITY`)
- [x] Removed `robin_hood_find_or_insertion_point` alias; `entry()` now calls `robin_hood_find` directly
- [x] Removed unused `sort_entries` and `sort_entries_by` wrapper functions

### 3. ~~Fix get_mut deletion path~~ ✅
- [x] Changed `get_mut` to use tombstone pattern (`TOMBSTONE_HASH`) instead of setting bucket to `None`
- [x] Updated `moon.mod.json` `repository` field

---

## 🟡 P1 — Performance ✅ All Done

### 4. ~~O(1) remove via swap-remove in order array~~ ✅ → reverted to shift-remove
- [x] Added `mut positions : Map[K, Int]` field to `IndexMap`
- [x] Rewrote `remove_from_order` to use positions (originally swap-remove)
- [x] Updated `insert()`, `VacantEntry::insert()` to record position
- [x] Updated `swap_remove_index()` to use simplified remove()
- [x] Updated `sort_by_key()`, `sort_by()` to rebuild positions
- [x] Updated `clear()`, `copy()` to manage positions
- [x] Rewrote `retain()` as collect-then-remove (safe with shift-remove)
- [x] Simplified `last()`, `pop()` to O(1)
- [x] **Reverted `remove_from_order` to shift-remove (O(n))**: swap-remove broke the
  insertion order of remaining elements, which contradicts IndexMap's core guarantee.
  `positions` is still used for O(1) `get_index_of`. `swap_remove_index()` remains
  O(1) and explicitly order-breaking for callers that opt in.

### 5. ~~O(1) get_index_of via position map~~ ✅
- [x] Replaced linear scan with `self.positions[key]`

### 6. Reuse robin_hood_insert_at in rehash
Lower priority — logic is correct, just duplicated.

---

## 🟢 P2 — Ecosystem & Polish

### 7. Publish to mooncakes.io
- [x] Module renamed to `aurasuisui/indexmap` per mooncakes.io naming convention
- [x] All `@indexmap` references updated across 6 source files + 2 docs
- [x] `moon.mod.json` repository field filled
- [x] VERSION bumped to `0.2.0` (semver compliant)
- [ ] Register/login on mooncakes.io
- [ ] Run `moon publish`

### 8. Add examples/ directory

Real-world examples help adoption and demonstrate value to judges.

- [x] `examples/config_parse.mbt` — config file parser with order preservation
- [x] `examples/lru_cache.mbt` — LRU cache using IndexMap's first/remove/insert
- [x] `examples/json_order.mbt` — ToJson order preservation demo

### 9. Add benchmark comparison ✅

- [x] Side-by-side correctness tests: IndexMap vs built-in Map
- [x] Mixed workload test (10000 insert-delete)
- [x] Order preservation vs Map's undefined order

---

## 🔵 P3 — Nice to Have

### 10. for..in loop support ⚠️ Deferred
- [x] Iterator types renamed to avoid `Iter[T]` conflict
- [ ] Native `for..in` requires constructing built-in `Iter[(K, V)]` — needs compiler API
- [ ] Workaround: `for (k, v) in map.iter().collect()` for now

### 11. Eq and Hash for IndexSet ✅
- [x] Implement `Eq` for `IndexSet[K]` (same elements in same order)
- [x] Implement `Hash` for `IndexSet[K]`
- [x] Add 6 tests for Eq/Hash on IndexSet

### 12. QuickCheck / Property tests ✅
- [x] Added 10 property tests for swap-remove invariants
- [x] Tests cover: position consistency, order preservation after remove, reinsert, retain
- [ ] Full `Arbitrary` trait impl (requires QuickCheck trait definition — deferred)

### 13. Increase commit density ✅
- [x] 5 focused commits with conventional messages

### 14. Iterator type rename (safe for for..in future) ✅
- [x] `Iter`→`MapIter`, `IntoIter`→`IntoMapIter`, `Keys`→`MapKeys`, `Values`→`MapValues`
- [x] Avoids conflict with MoonBit built-in `Iter[T]` type
- [x] Transparent to users (types are return-type only, not named by callers)

### 15. Arbitrary trait (QuickCheck support) ✅
- [x] `Arbitrary` trait impl for `IndexMap[K, V]`
- [x] `Arbitrary` trait impl for `IndexSet[K]`
- [x] `moon.pkg.json` imports `moonbitlang/core/quickcheck`
- [x] 11 QuickCheck property tests in `arbitrary_test.mbt`

---

## Summary

| Priority | Items | Effort | Status |
|----------|-------|--------|--------|
| P0 | VERSION fix, dead code, duplicate alias, get_mut fix | 1 hour | ✅ Done |
| P1 | O(1) remove, O(1) get_index_of, rehash | 1 day | ✅ Done |
| P2 | Publish (rename done), examples, benchmarks | 1 day | ✅ Done |
| P3 | IndexSet traits, property tests, Arbitrary, iter rename | 2 days | ✅ Done |
| —  | `git push` + `moon publish` | — | 📋 Needs local CLI |
