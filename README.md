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

Add to `moon.mod`:

```json
{ "dependencies": { "aurasuisui/indexmap": "0.3.2" } }
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
| Bulk | `retain(f)`, `sort_by_key()`, `sort_by(cmp)`, `drain()`, `extend_from_array(entries)` |
| Traits | `Debug`, `Default`, `Show`, `Hash`, `Eq`, `ToJson` |

### IndexSet[K]

| Category | Methods |
|----------|---------|
| Construct | `new()`, `with_capacity(n)`, `from_array(elements)`, `default()`, `copy()` |
| Core | `insert(v) -> Bool`, `contains(v) -> Bool`, `remove(v) -> Bool`, `clear()` |
| Set ops | `is_disjoint(other)`, `is_subset(other)`, `is_superset(other)` |
| Bulk | `retain(f)`, `drain()`, `extend_from_array(elements)`, `into_array()` |
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

1. **`get_mut` callback re-inserting the same key (fixed in v0.3.2).**
   Previously, a callback that called `map.insert(same_key, ...)` and then returned
   `None` would have its just-inserted value clobbered by the tombstone. A
   `contains(key)` guard now detects this re-insertion and skips the tombstone,
   so the value is preserved. To update a value in place, `Some(new_val)` is
   still the recommended (and now the only safe-against-footguns) path.

2. **`Eq` and `Hash` are insertion-order-sensitive.** Two maps with identical
   key-value pairs but different insertion orders are *not* equal and produce
   different hashes. Avoid using an `IndexMap` or `IndexSet` as a key in another
   hash container unless you can guarantee consistent insertion order.

3. **`swap_remove_index` is actually O(n) shift-remove.** Despite the name
   (kept for Rust indexmap API compatibility), it calls the order-preserving
   `remove` path — elements after the target are shifted one slot left. It does
   *not* swap with the last element in O(1). If you need actual O(1)
   order-breaking removal, you would need a dedicated method that directly
   swaps with the last element before popping — `swap_remove_index` does not
   do this.

4. **`max_probe()` is refreshed after `sort_by` / `sort_by_key` (fixed in v0.3.2).**
   Sorting rebuilds `order[]` and `positions[]`; as of v0.3.2 the internal
   `max_probe_distance` is also recalculated after sorting, so `max_probe()`
   reports the current (post-sort) probe distribution. (Sorting does not move
   buckets, so previously the value happened to remain correct — it is now
   maintained explicitly.)

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

The example packages live in [`cmd/`](cmd/):

- `cmd/lru_cache` — LRU eviction demo
- `cmd/config_parse` — order-preserving config parser
- `cmd/json_order` — `ToJson` key ordering

> **Note (v0.3.2):** the `cmd/*` example packages are currently **excluded from the
> workspace** (`moon.work` lists only `.`) so that the library's CI pipeline
> (`moon fmt --check` / `moon check` / `moon test` / `moon info`) runs on the canonically
> pinned toolchain without being tripped up by example-package main declaration syntax.
> To run an example, temporarily re-add the relevant `cmd/<name>` to `members` in
> `moon.work` (or use a separately-configured build toolchain) and resolve the
> `aurasuisui/indexmap` dependency, then `moon run cmd/<name>`. Source remains in `cmd/`
> for reference.

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
