# Contributing to moonbit-indexmap

## Getting Started

```bash
# Prerequisites
# Install MoonBit: https://www.moonbitlang.com/download/

git clone https://github.com/aurasuisui/moonbit-indexmap
cd moonbit-indexmap
moon check   # Type check (0 errors)
moon test    # Run 236+ tests
moon fmt     # Format code
```

## Project Layout

```
.
├── src/
│   ├── lib.mbt           # Public API entry points + VERSION constant
│   ├── map.mbt           # IndexMap[K, V] core (all logic lives here)
│   ├── set.mbt           # IndexSet[K] — thin wrapper over IndexMap[K, Unit]
│   ├── hash.mbt          # Shared hash constants (load factor, sentinels)
│   ├── map_test.mbt      # Black-box tests for IndexMap (109 tests)
│   ├── set_test.mbt      # Black-box tests for IndexSet (50 tests)
│   ├── bench_test.mbt    # Correctness-under-load tests (36 tests)
│   ├── property_test.mbt # Invariant/property tests (47 tests)
│   └── moon.pkg.json     # Package config (test-only import)
├── .github/workflows/ci.yml
├── README.md
├── CHANGELOG.md
├── IMPROVEMENT.md        # Current improvement priorities
└── LICENSE
```

## Style Guide

| Rule | Example |
|------|---------|
| Functions | `snake_case`: `robin_hood_find`, `get_index_of` |
| Types | `PascalCase`: `IndexMap`, `OccupiedEntry` |
| Constants | `UPPER_CASE`: `MIN_CAPACITY`, `TOMBSTONE_HASH` |
| Public API docs | `///|` doc comment block |
| Internal docs | `///|` on internal helpers too |
| Section separators | `// ---` with label |
| Tests | `@aurasuisui/indexmap.` prefix for black-box access |

---

## Architecture Deep Dive

### Data Layout

IndexMap uses two parallel arrays:

```
IndexMap[K, V]
├── buckets:   Array[Entry[K, V]?]  ← Robin Hood hash table
├── order:     Array[K]             ← Insertion-order log
└── positions: Map[K, Int]          ← Key → index lookup (O(1) remove)
```

**Buckets** is the hash table. Each slot is `Entry[K, V]?` — `None` means empty, `Some(entry)` means occupied. Deleted entries become **tombstones**: their `hash` is set to `TOMBSTONE_HASH (-1)` but the slot stays `Some`.

**Order** is a flat array of keys in insertion order. Iteration walks this array, looks up each key in the hash table, and skips keys whose bucket entry is a tombstone.

### Key Constants

| Constant | Location | Value | Meaning |
|----------|----------|-------|---------|
| `MIN_CAPACITY` | map.mbt | 16 | Minimum bucket count (power of 2) |
| `NO_DISTANCE` | map.mbt | -1 | Sentinel: entry has never been displaced |
| `TOMBSTONE_HASH` | map.mbt | -1 | Marker for deleted entries |
| `LOAD_FACTOR_NUMERATOR` | hash.mbt | 3 | 3/4 = 0.75 load factor |
| `LOAD_FACTOR_DENOMINATOR` | hash.mbt | 4 | |

### Robin Hood Hashing

Standard open-addressing places each key at `hash(key) % capacity`. If occupied, it probes linearly. This causes **clustering**: some keys probe much farther than others.

Robin Hood improves this: when inserting, if the incoming key has probed **farther** than the key currently in the slot, the incoming key **steals** the slot and the displaced key continues probing. This equalizes probe distances across all entries.

In our implementation:

- `Entry.distance` records how far from its ideal bucket this entry has been displaced
- `robin_hood_find(key, hash)` — searches for a key, returning `(bucket_index, found)`. If not found, returns the insertion point (respecting distance ordering and reusing tombstones)
- `robin_hood_insert_at(entry, start_idx, hash)` — inserts with displacement: if the current slot's entry has shorter distance, steal the slot and continue with the displaced entry

### Internal Function Map

```
                    ┌──────────────────┐
                    │   Public API     │
                    └──────┬───────────┘
           ┌───────────────┼───────────────┐
           │               │               │
    ┌──────▼──────┐ ┌─────▼─────┐ ┌───────▼──────┐
    │ probe_find  │ │robin_hood │ │robin_hood    │
    │ (get/remove │ │ _find     │ │_insert_at    │
    │  /contains) │ │ (insert/  │ │ (insertion)  │
    └─────────────┘ │  entry)   │ └──────────────┘
                    └───────────┘
```

**`probe_find(key, hash) -> (index, found)`**
Simple linear probe. Used by: `get`, `remove`, `contains`, `get_mut`, `rehash`.
Does NOT skip tombstones for lookup — only checks `entry.hash != TOMBSTONE_HASH`.

**`robin_hood_find(key, hash) -> (index, found)`**
Robin Hood probe with tombstone reuse. Used by: `insert`, `entry`.
When not found, prefers tombstone slots over empty slots for the insertion point.

**`robin_hood_insert_at(entry, start_idx, hash) -> Unit`**
Insert with displacement. If `existing.distance < dist`, the new entry steals the slot.

**`remove_from_order(key) -> Unit`**
O(1) swap-remove using `positions: Map[K, Int]`. Swaps the target with the last element, updates both positions, then pops. Called by: `remove`, `get_mut`, `retain`.

**`rehash(new_cap) -> Unit`**
Rebuild buckets from scratch using entries in insertion order. Clears all tombstones.
Note: duplicates Robin Hood insertion logic — could reuse `robin_hood_insert_at`.

**`should_resize_impl(len, capacity) -> Bool`**
Returns true when `(len + tombstones) / capacity >= 0.75`.

### Deletion: Single Coherent Path

All deletion goes through `remove(key)` (or directly creates tombstones):

- `remove(key)`: creates tombstone, calls `remove_from_order`
- `get_mut` with `None` callback: creates tombstone, calls `remove_from_order` (same pattern as `remove`)
- `OccupiedEntry::remove()`: delegates to `self.map.remove(self.key)`

The tombstone pattern (setting `entry.hash = TOMBSTONE_HASH` while keeping `Some(...)`) preserves probe chain integrity, and auto-rehash triggers when tombstone ratio > 25%.

### Iteration: How Order Is Preserved

```
Iter::next():
  for each key in self.map.order[pos..]:
    let val = self.map.get(key)   // lookup in hash table
    if val is Some → return (key, val)   // key still exists
    else → skip                           // key was deleted, skip silently
```

`Keys::next()` and `Values::next()` do direct bucket inspection (checking `TOMBSTONE_HASH`) instead of calling `get()` — an optimization that avoids trait bounds.

### Memory Layout Invariants

These must ALWAYS hold true. Breaking any of them will cause bugs:

| Invariant | Enforced By |
|-----------|-------------|
| `self.len == count of non-tombstone entries in buckets` | All insert/remove paths |
| `self.order.length() == self.len` | remove_from_order (swap-remove), sort rebuilds |
| `self.positions.size() == self.len` | All insert/remove paths that touch order |
| `self.positions[key] == index` for each `order[index] == key` | insert, remove_from_order, sort rebuilds |
| `self.mask == self.buckets.length() - 1` | Constructor, resize |
| `self.buckets.length()` is a power of 2 | `next_power_of_two_impl` |
| `self.tombstone_count == count of entries with hash == -1` | remove, rehash |
| `self.max_probe_distance >= max(entry.distance for all entries)` | insert, rehash |

---

## Adding a New Feature

### Pattern: Adding a new method to IndexMap

1. Add the implementation in `map.mbt` under the appropriate section
2. Add `///|` doc comment explaining params and return value
3. Add black-box tests in `map_test.mbt` using `@aurasuisui/indexmap.` prefix
4. Add a property test in `property_test.mbt` if there's an invariant to verify
5. Update the API table in `README.md`
6. Add a CHANGELOG entry

### Pattern: Adding a new trait implementation

Example from the codebase (adding `Debug`):
```moonbit
impl[K : Debug + Hash + Eq, V : Debug] Debug for IndexMap[K, V] with to_repr(self) {
  // collect entries → Repr array
  // return Repr::opaque_("IndexMap", Repr::map(entries))
}
```

Trait bounds must include `Hash + Eq` when the implementation iterates (which requires looking up keys).

---

## Testing Guide

### Test Categories

| File | Type | Count | What It Tests |
|------|------|-------|---------------|
| `map_test.mbt` | Unit | 109 | Per-method correctness, edge cases, order |
| `set_test.mbt` | Unit | 44 | IndexSet methods, set operations |
| `property_test.mbt` | Invariant | 37 | Properties that hold across operations |
| `bench_test.mbt` | Load | 30 | Correctness under scale (5k-10k entries) |

### Test Convention

```moonbit
test "descriptive name in english" {
  let map = @aurasuisui/indexmap.new()
  // Arrange
  map.insert("key", 42) |> ignore
  // Act & Assert
  inspect(map.get("key"), content="Some(42)")
}
```

All tests use `@aurasuisui/indexmap.` prefix (black-box testing). The `moon.pkg.json` imports `moonbitlang/core/test` for the `inspect` and `@test.fail` functions.

### Running Tests

```bash
moon test                    # All 220 tests
moon test --test-filter "bench"   # Only bench tests
moon test --test-filter "property" # Only property tests
```

---

## Known Issues & Gotchas

### 1. ~~VERSION mismatch~~ ✅ Fixed
`lib.mbt`, `moon.mod.json`, and test now all read "0.2.0".

### 2. ~~Dead code in hash.mbt~~ ✅ Fixed
Unused constants and functions removed. Only `LOAD_FACTOR_NUMERATOR` and `LOAD_FACTOR_DENOMINATOR` remain (used by `map.mbt`).

### 3. ~~Duplicate function alias~~ ✅ Fixed
`robin_hood_find_or_insertion_point` removed; `entry()` now calls `robin_hood_find` directly.

### 4. ~~get_mut deletion path was inconsistent~~ ✅ Fixed
Now uses proper tombstone pattern (was setting bucket to `None`, breaking probe chains).

### 5. ~~O(n) remove_from_order~~ ✅ Fixed
Replaced with O(1) swap-remove using a `positions: Map[K, Int]` for key→index lookup.

### 6. ~~sort_entries / sort_entries_by were unused~~ ✅ Fixed
Removed. Sorting is done inline in `sort_by_key` and `sort_by`.

### 7. rehash duplicates robin_hood_insert_at
The rehash function has its own copy of the Robin Hood insertion loop instead of calling `robin_hood_insert_at`. Low priority — the logic is correct, just duplicated.

---

## Roadmap

### v0.1.0 — Core Data Structures ✅
- IndexMap, IndexSet, Entry API, iterators, bulk ops, `Show`/`Hash`/`Eq`

### v0.2.0 — Standard Library Integration ✅
- `Debug`, `Default`, `ToJson`, `copy()`, `get_mut()`, `into_iter()`, `into_array()`, native sort

### v0.3.0 — Performance & Polish (current)
See [IMPROVEMENT.md](IMPROVEMENT.md) for the detailed plan.

- [x] O(1) `remove` via swap-remove + position map
- [x] Fix VERSION to 0.2.0
- [x] Remove dead code (hash.mbt unused functions, alias, sort wrappers)
- [x] Fix `get_mut` deletion to use tombstone pattern
- [ ] Publish to mooncakes.io
- [x] `Eq` and `Hash` trait for IndexSet
- [x] Add `examples/` directory (config_parse, lru_cache, json_order)
- [ ] `for .. in` loop support
- [ ] `Arbitrary` trait for QuickCheck testing

## License

Apache 2.0 — see [LICENSE](LICENSE).
