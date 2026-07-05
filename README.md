# moonbit-indexmap

[![License](https://img.shields.io/badge/license-Apache%202.0-blue.svg)](LICENSE)
[![CI](https://github.com/aurasuisui/moonbit-indexmap/actions/workflows/ci.yml/badge.svg)](https://github.com/aurasuisui/moonbit-indexmap/actions/workflows/ci.yml)

A hash map that preserves insertion order — MoonBit port of Rust's [`indexmap`](https://github.com/indexmap-rs/indexmap) crate.

MoonBit's built-in `Map[K, V]` does not guarantee iteration order. IndexMap remembers the order keys were inserted, making it ideal for configuration parsing, JSON serialization, LRU caches, and deterministic tests.

```moonbit
let map = @aurasuisui/indexmap.new()
map.insert("b", 2) |> ignore
map.insert("a", 1) |> ignore
map.insert("c", 3) |> ignore

// Iteration follows insertion order: b, a, c
let iter = map.iter()
while true {
  match iter.next() {
    Some((k, v)) => println("\{k}: \{v}")
    None => break
  }
}
```

## Features

- **Insertion-order iteration** — entries yield in the order they were first inserted
- **O(1) average lookups** — Robin Hood open-addressing hash table
- **Index-based access** — `get_index(i)`, `first()`, `last()`, `pop()`
- **Entry API** — `OccupiedEntry` / `VacantEntry` for in-place manipulation
- **IndexSet** — ordered hash set with `is_disjoint`, `is_subset`, `is_superset`
- **JSON support** — `ToJson` trait preserves key order
- **Standard traits** — `Debug`, `Default`, `Show`, `Hash`, `Eq`, `ToJson` for both IndexMap and IndexSet
- **QuickCheck support** — `Arbitrary` trait for property-based testing

## Installation

Add to `moon.mod.json`:

```json
{ "dependencies": { "aurasuisui/indexmap": "0.2.0" } }
```

Or clone directly:

```bash
git clone https://github.com/aurasuisui/moonbit-indexmap
```

## API Overview

### IndexMap[K, V]

| Category | Methods |
|----------|---------|
| Construct | `new()`, `with_capacity(n)`, `from_array(entries)`, `default()`, `copy()` |
| Query | `len()`, `is_empty()`, `capacity()`, `load_factor()`, `max_probe()` |
| Core | `insert(k, v) -> V?`, `get(k) -> V?`, `remove(k) -> V?`, `contains(k) -> Bool`, `clear()`, `get_mut(k, f)` |
| Entry | `entry(k) -> EntryView` (Occupied: `get`/`insert`/`remove`/`key`, Vacant: `insert`/`key`) |
| Index | `get_index(i)`, `get_full(k)`, `get_index_of(k)`, `first()`, `last()`, `pop()`, `swap_remove_index(i)` |
| Capacity | `reserve(n)`, `shrink_to_fit()` |
| Iterate | `iter()`, `keys()`, `values()`, `for_each(f)`, `into_iter()`, `into_array()` |
| Bulk | `retain(f)`, `sort_by_key()`, `sort_by(cmp)`, `drain()`, `extend(entries)` |
| Traits | `Debug`, `Default`, `Show`, `Hash`, `Eq`, `ToJson` |

### IndexSet[K]

| Category | Methods |
|----------|---------|
| Construct | `new()`, `with_capacity(n)`, `from_array(elements)`, `default()`, `copy()` |
| Core | `insert(v) -> Bool`, `contains(v) -> Bool`, `remove(v) -> Bool`, `clear()` |
| Set ops | `is_disjoint(other)`, `is_subset(other)`, `is_superset(other)` |
| Bulk | `retain(f)`, `drain()`, `extend(elements)`, `into_array()` |
| Traits | `Debug`, `Default`, `Show`, `Hash`, `Eq`, `ToJson` |

## Design

Two parallel structures:

1. **Robin Hood hash table** (`Array[Entry[K, V]?]`) — O(1) average lookup, reduced probe variance
2. **Order array** (`Array[K]`) — tracks insertion order for deterministic iteration

Deletion uses tombstone markers to preserve probe chains, with automatic rehash when the tombstone ratio exceeds 25%.

### Compared to built-in Map

| Property | `Map[K, V]` | `IndexMap[K, V]` |
|----------|-------------|-------------------|
| Lookup | O(1) avg | O(1) avg |
| Iteration order | Undefined | Insertion order |
| Index access | No | Yes |
| Memory | Lower | ~2× (order array) |
| `Eq` / `Hash` semantics | Independent of insertion order | Dependent on insertion order |

## Gotchas

Known design choices and limitations — see the
[independent test report](https://github.com/aurasuisui/indexmap-test-suite/blob/main/TEST_REPORT.md)
for reproduction details.

1. **`get_mut` callback: don't delete and re-insert the same key.** If the callback
   calls `map.insert(same_key, ...)` and then returns `None`, the tombstone written
   by `get_mut` clobbers the just-inserted value. Use `Some(new_val)` to update in
   place instead.

2. **`Eq` and `Hash` are insertion-order-sensitive.** Two maps with identical
   key-value pairs but different insertion orders are *not* equal and produce
   different hashes. Avoid using an `IndexMap` or `IndexSet` as a key in another
   hash container unless you can guarantee consistent insertion order.

3. **`swap_remove_index` is actually O(n) shift-remove.** Despite the name
   (kept for Rust indexmap API compatibility), it calls the order-preserving
   `remove` path — elements after the target are shifted one slot left. It does
   *not* swap with the last element in O(1). If you need O(1) order-breaking
   removal, use `swap_remove_index` (it *is* order-breaking by name, but the
   implementation currently preserves order).

4. **`sort_by` / `sort_by_key` does not refresh `max_probe()`.** Sorting rebuilds
   `order[]` and `positions[]` but leaves the underlying hash-table buckets
   untouched. The value returned by `max_probe()` reflects the pre-sort probe
   distribution — it will be stale after sorting.

5. **Don't mutate the map while an iterator is active.** Iterators hold a cursor
   into the order array; `insert` or `remove` during iteration causes an
   out-of-bounds crash (fail-fast). Finish all mutations first, then create a
   fresh iterator.

## Independent Test Report

An independent black-box test suite ([`indexmap-test-suite`](https://github.com/aurasuisui/indexmap-test-suite))
verified this library with **485 tests** (253 library self-tests + 232 external
tests covering every public API, stress up to 100k entries, property-based
invariants, and edge-case traps).

Conclusion: **production-ready for single-threaded use.** Known caveats are
documented in the [Gotchas](#gotchas) section above.

## Examples

See [`examples/`](examples/) for copy-paste snippets demonstrating common patterns:

- [`lru_cache.mbt`](examples/lru_cache.mbt) — fixed-capacity LRU cache built on IndexMap
- [`config_parse.mbt`](examples/config_parse.mbt) — order-preserving `key=value` config parser using the Entry API
- [`json_order.mbt`](examples/json_order.mbt) — JSON serialization that preserves key order via `ToJson`

Usage: copy a snippet into your project, add `import { "aurasuisui/indexmap" }`
to your `moon.pkg`, and run. See [`examples/README.md`](examples/README.md) for
details.

## Development

```bash
moon check   # Type check
moon test    # Run all tests
moon fmt     # Format code
```

See [CONTRIBUTING.md](CONTRIBUTING.md) for project layout, roadmap, and contribution guidelines.

## License

Apache 2.0 — see [LICENSE](LICENSE).

Built for the **MoonBit Open Source Ecosystem Competition 2026**.
