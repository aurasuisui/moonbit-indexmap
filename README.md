# moonbit-indexmap

[![License](https://img.shields.io/badge/license-Apache%202.0-blue.svg)](LICENSE)

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
- **Standard traits** — `Debug`, `Default`, `Show`, `Hash`, `Eq`, `ToJson`

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
| Traits | `Debug`, `Default`, `Show`, `ToJson` |

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
