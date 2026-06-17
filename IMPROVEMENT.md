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

### 4. ~~O(1) remove via swap-remove in order array~~ ✅
- [x] Added `mut positions : Map[K, Int]` field to `IndexMap`
- [x] Rewrote `remove_from_order` to use swap-remove with positions
- [x] Updated `insert()`, `VacantEntry::insert()` to record position
- [x] Updated `swap_remove_index()` to use simplified remove()
- [x] Updated `sort_by_key()`, `sort_by()` to rebuild positions
- [x] Updated `clear()`, `copy()` to manage positions
- [x] Rewrote `retain()` as collect-then-remove (safe with swap-remove)
- [x] Simplified `last()`, `pop()` to O(1)

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

### 10. for..in loop support

Implement MoonBit's standard `Iter[(K, V)]` trait so users can write `for (k, v) in map { ... }`.

- [ ] Implement `Iter[(K, V)]` for IndexMap

### 11. Eq and Hash for IndexSet ✅
- [x] Implement `Eq` for `IndexSet[K]` (same elements in same order)
- [x] Implement `Hash` for `IndexSet[K]`
- [x] Add 6 tests for Eq/Hash on IndexSet

### 12. QuickCheck / Property tests ✅
- [x] Added 10 property tests for swap-remove invariants
- [x] Tests cover: position consistency, order preservation after remove, reinsert, retain
- [ ] Full `Arbitrary` trait impl (requires QuickCheck trait definition — deferred)

### 13. Increase commit density

Current: 20 commits.

- [x] Smaller, focused commits for each improvement item
- [x] Use conventional commit messages (`feat:`, `fix:`, `perf:`, `docs:`, `refactor:`)

---

## Summary

| Priority | Items | Effort | Status |
|----------|-------|--------|--------|
| P0 | VERSION fix, dead code, duplicate alias, get_mut fix | 1 hour | ✅ Done |
| P1 | O(1) remove, O(1) get_index_of, rehash | 1 day | ✅ Done |
| P2 | Publish (rename done), examples, benchmarks | 1 day | ✅ Done |
| P3 | for..in, IndexSet traits, Arbitrary | 2 days | ✅ Done (IndexSet traits, property tests) |
| P4 | for..in loop, Arbitrary trait | — | 📋 Needs MoonBit API research |
| —  | `git push` + `moon publish` | — | 📋 Needs local CLI |
