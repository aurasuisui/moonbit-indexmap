# Improvement Plan

> **Status:** This was the sprint checklist for the competition acceptance review
> (2026-07-04). All P0–P3 items listed below are complete except P1 item 6 (reuse
> `robin_hood_insert_at` in `rehash`), a low-priority open item. The project has since
> progressed through v0.3.1 (warning cleanup, `inspect`→`debug_inspect` migration,
> independent test suite verification) and **v0.3.2** (BUG-001 / WARN-002 / WARN-003
> fixes from the test-suite Recommendations). For the current roadmap and full
> history, see [CONTRIBUTING.md](CONTRIBUTING.md) and [CHANGELOG.md](CHANGELOG.md).

Based on project evaluation against the MoonBit Open Source Ecosystem Competition criteria, this document tracks actionable improvements ordered by priority.

---

## 🔴 P0 — Must Fix ✅ All Done

### 1. ~~Fix VERSION mismatch~~ ✅
- [x] Update `lib.mbt`: `pub const VERSION : String = "0.2.0"`
- [x] Update `moon.mod.json`: `"version": "0.2.0"`
- [x] Update test at `map_test.mbt:1276`
- [x] Create git tag: `git tag v0.2.0` (tag pushed to origin)

### 2. ~~Remove dead code~~ ✅
- [x] Removed unused functions from `hash.mbt` (`EMPTY_HASH`, `bucket_index`, `should_resize`, `next_power_of_two`, `INITIAL_CAPACITY`)
- [x] Removed `robin_hood_find_or_insertion_point` alias; `entry()` now calls `robin_hood_find` directly
- [x] Removed unused `sort_entries` and `sort_entries_by` wrapper functions

### 3. ~~Fix get_mut deletion path~~ ✅
- [x] Changed `get_mut` to use tombstone pattern (`TOMBSTONE_HASH`) instead of setting bucket to `None`
- [x] Updated `moon.mod.json` `repository` field

---

## 🟡 P1 — Performance ✅ (item 6 deferred as low-priority)

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
  `positions` is still used for O(1) `get_index_of`. Note: `swap_remove_index(index)`
  delegates to `remove(order[index])`, so it is **also O(n) and order-preserving** despite
  its name (kept for Rust indexmap API familiarity) — see README Gotchas.

### 5. ~~O(1) get_index_of via position map~~ ✅
- [x] Replaced linear scan with `self.positions[key]`

### 6. Reuse robin_hood_insert_at in rehash — OPEN (low priority)
Lower priority — logic is correct, just duplicated. Not done; kept as a known minor
duplication (also tracked as CONTRIBUTING Known Issue #7).

---

## 🟢 P2 — Ecosystem & Polish ✅ All Done

### 7. Publish to mooncakes.io ✅
- [x] Module renamed to `aurasuisui/indexmap` per mooncakes.io naming convention
- [x] All `@indexmap` references updated across 6 source files + 2 docs
- [x] `moon.mod.json` repository field filled
- [x] VERSION bumped to `0.2.0` (semver compliant)
- [x] Register/login on mooncakes.io
- [x] Run `moon publish` (v0.2.0 published — Server status: 200 OK)

### 8. Add examples/ directory ✅ (now `cmd/`)

Real-world examples help adoption and demonstrate value to judges.

> Since superseded: the examples moved from `examples/*.mbt` snippets to runnable
> `cmd/` packages (`cmd/config_parse`, `cmd/lru_cache`, `cmd/json_order`).

- [x] `examples/config_parse.mbt` — config file parser with order preservation
- [x] `examples/lru_cache.mbt` — LRU cache using IndexMap's first/remove/insert
- [x] `examples/json_order.mbt` — ToJson order preservation demo

### 9. Add benchmark comparison ✅

- [x] Side-by-side correctness tests: IndexMap vs built-in Map
- [x] Mixed workload test (10000 insert-delete)
- [x] Order preservation vs Map's undefined order

---

## 🔵 P3 — Nice to Have

### 10. for..in loop support ✅
- [x] `iter()`, `keys()`, `values()` return MoonBit's built-in `Iter[T]` via `Iter::new`
- [x] Supports `for (k, v) in map { ... }` syntax directly (no `for x in map.iter().collect()` workaround needed)
- [x] Note: earlier "rename iterator types to avoid Iter[T] conflict" approach (P3.14 below) was superseded by adopting the built-in `Iter[T]` directly

### 11. Eq and Hash for IndexSet ✅
- [x] Implement `Eq` for `IndexSet[K]` (same elements in same order)
- [x] Implement `Hash` for `IndexSet[K]`
- [x] Add 6 tests for Eq/Hash on IndexSet

### 12. QuickCheck / Property tests ✅
- [x] Added 10 property tests for swap-remove invariants (later reinterpreted as
  shift-remove invariants after swap-remove was reverted — see item 4)
- [x] Tests cover: position consistency, order preservation after remove, reinsert, retain
- [x] Full `Arbitrary` trait impl — see item 15 below

### 13. Increase commit density ✅
- [x] Focused commits with Conventional Commits messages (28 total across the project history)

### 14. Iterator migration to built-in Iter[T] ✅ (superseded earlier rename plan)
- [x] `iter()` / `keys()` / `values()` now return MoonBit's built-in `Iter[T]` constructed via `Iter::new(closure, size_hint=len)`
- [x] Earlier plan (`Iter`→`MapIter`, `Keys`→`MapKeys`, `Values`→`MapValues` to avoid name conflict) was **abandoned** once the built-in `Iter[T]` construction API became available — adopting it directly is simpler and enables native `for..in`
- [x] Only `IntoMapIter[K, V]` (the consuming iterator returned by `into_iter()`) remains as a custom struct

### 15. Arbitrary trait (QuickCheck support) ✅
- [x] `Arbitrary` trait impl for `IndexMap[K, V]`
- [x] `Arbitrary` trait impl for `IndexSet[K]`
- [x] `moon.pkg` imports `moonbitlang/core/quickcheck`
- [x] 11 QuickCheck property tests in `arbitrary_test.mbt`

---

## Summary

| Priority | Items | Effort | Status |
|----------|-------|--------|--------|
| P0 | VERSION fix, dead code, duplicate alias, get_mut fix | 1 hour | ✅ Done |
| P1 | O(1) remove, O(1) get_index_of, rehash | 1 day | ✅ Done |
| P2 | Publish (rename done), examples, benchmarks | 1 day | ✅ Done |
| P3 | IndexSet traits, property tests, Arbitrary, built-in Iter | 2 days | ✅ Done |
| —  | `git push` + `moon publish` | — | ✅ Done (v0.2.0 tag pushed, v0.2.0 published to mooncakes.io) |
