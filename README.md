# moonbit-indexmap

[![CI](https://github.com/moonbit-indexmap/actions/workflows/ci.yml/badge.svg)](https://github.com/moonbit-indexmap/actions/workflows/ci.yml)
[![License](https://img.shields.io/badge/license-Apache%202.0-blue.svg)](LICENSE)

A hash map that preserves insertion order, implemented in MoonBit — inspired by the popular Rust [`indexmap`](https://crates.io/crates/indexmap) crate.

## Why indexmap?

MoonBit's built-in `Map[K, V]` does not guarantee iteration order. When you need to remember the order in which entries were inserted — for configuration parsing, LRU caches, JSON serialization, or deterministic tests — IndexMap is the solution.

## Features

- **Insertion-order iteration**: entries are yielded in the order they were first inserted
- **O(1) average lookups**: Robin Hood open-addressing hash table
- **Index-based access**: get entries by their insertion-order position
- **Entry API**: in-place manipulation with `OccupiedEntry` / `VacantEntry`
- **IndexSet included**: a hash set with the same ordering guarantees
- **Familiar API**: designed to mirror the Rust `indexmap` crate where practical

## Installation

Add to your `moon.mod.json`:

```json
{
  "dependencies": {
    "indexmap": "0.1.0"
  }
}
```

Or clone directly:

```bash
git clone https://github.com/moonbit-indexmap.git
```

## Quick Start

### IndexMap

```moonbit
let map = @indexmap.new()

// Insert entries
map.insert("b", 2) |> ignore
map.insert("a", 1) |> ignore
map.insert("c", 3) |> ignore

// Lookup
match map.get("a") {
  Some(v) => println("a -> \{v}")
  None => println("not found")
}

// Iteration follows insertion order: b, a, c
let iter = map.iter()
while true {
  match iter.next() {
    Some((k, v)) => println("\{k}: \{v}")
    None => break
  }
}

// Index-based access
match map.get_index(0) {
  Some((k, v)) => println("First: \{k} -> \{v}")
  None => ()
}
```

### Entry API

```moonbit
let map = @indexmap.new()

// Insert or update
match map.entry("key") {
  Occupied(entry) => entry.insert(99) |> ignore
  Vacant(entry) => entry.insert(42) |> ignore
}
```

### IndexSet

```moonbit
let set = @indexmap.IndexSet::new()
set.insert("apple") |> ignore
set.insert("banana") |> ignore

if set.contains("apple") {
  println("found apple")
}

// Set operations
let other = @indexmap.IndexSet::new()
other.insert("apple") |> ignore
other.insert("cherry") |> ignore

println("is subset: \{set.is_subset(other)}")
```

## API Reference

### IndexMap[K, V]

**Construction**
| Method | Description |
|--------|-------------|
| `new() -> IndexMap[K, V]` | Create an empty map with default capacity |
| `with_capacity(n : Int) -> IndexMap[K, V]` | Create with pre-allocated capacity |
| `from_array(entries : Array[(K, V)]) -> IndexMap[K, V]` | Create from an array of pairs |

**Size queries**
| Method | Description |
|--------|-------------|
| `len() -> Int` | Number of entries |
| `is_empty() -> Bool` | Whether map is empty |
| `capacity() -> Int` | Current number of buckets |
| `load_factor() -> Double` | Current load factor |
| `max_probe() -> Int` | Maximum probe distance observed |

**Core operations**
| Method | Description |
|--------|-------------|
| `insert(key : K, value : V) -> V?` | Insert or update, returns old value |
| `get(key : K) -> V?` | Look up value by key |
| `remove(key : K) -> V?` | Remove and return value |
| `contains(key : K) -> Bool` | Check if key exists |
| `clear()` | Remove all entries |

**Entry API**
| Method | Description |
|--------|-------------|
| `entry(key : K) -> EntryView[K, V]` | Get entry for in-place manipulation |

**OccupiedEntry methods**: `get() -> V`, `insert(value : V) -> V`, `remove() -> V`, `key() -> K`

**VacantEntry methods**: `insert(value : V) -> V`, `key() -> K`

**Index-based access**
| Method | Description |
|--------|-------------|
| `get_index(i : Int) -> (K, V)?` | Get entry by insertion-order position |
| `get_full(key : K) -> (K, V)?` | Get key and value as a pair |
| `get_index_of(key : K) -> Int?` | Get insertion-order position of key |
| `first() -> (K, V)?` | Get first (earliest) entry |
| `last() -> (K, V)?` | Get last (most recent) entry |
| `pop() -> (K, V)?` | Remove and return last entry |
| `swap_remove_index(i : Int) -> (K, V)?` | Swap-remove by position |

**Capacity management**
| Method | Description |
|--------|-------------|
| `reserve(additional : Int)` | Reserve space for more entries |
| `shrink_to_fit()` | Shrink capacity to fit current size |

**Iteration**
| Method | Description |
|--------|-------------|
| `iter() -> Iter[K, V]` | Iterate (key, value) pairs in insertion order |
| `keys() -> Keys[K, V]` | Iterate keys in insertion order |
| `values() -> Values[K, V]` | Iterate values in insertion order |
| `for_each(f : (K, V) -> Unit)` | Apply function to each entry |

**Iter methods**: `next() -> (K, V)?`, `collect() -> Array[(K, V)]`, `count_remaining() -> Int`

**Bulk operations**
| Method | Description |
|--------|-------------|
| `retain(f : (K, V) -> Bool)` | Keep entries matching predicate |
| `sort_by_key()` | Sort entries by key (requires Compare) |
| `sort_by(cmp : ((K, V), (K, V)) -> Int)` | Sort entries with custom comparator |
| `drain() -> Array[(K, V)]` | Remove all entries, return as array |
| `extend(entries : Array[(K, V)])` | Insert all entries from array |

### IndexSet[K]

| Method | Description |
|--------|-------------|
| `new() -> IndexSet[K]` | Create empty set |
| `with_capacity(n : Int) -> IndexSet[K]` | Create with pre-allocated capacity |
| `len() -> Int` | Number of elements |
| `is_empty() -> Bool` | Whether set is empty |
| `capacity() -> Int` | Current capacity |
| `insert(value : K) -> Bool` | Insert, returns `true` if new |
| `contains(value : K) -> Bool` | Membership check |
| `remove(value : K) -> Bool` | Remove element |
| `clear()` | Remove all elements |
| `iter() -> Keys[K, Unit]` | Iterate in insertion order |
| `retain(f : (K) -> Bool)` | Keep elements matching predicate |
| `is_disjoint(other : IndexSet[K]) -> Bool` | No common elements |
| `is_subset(other : IndexSet[K]) -> Bool` | All elements in other |
| `is_superset(other : IndexSet[K]) -> Bool` | Contains all of other |

## Design

Internally, IndexMap uses two parallel structures:

1. **Robin Hood open-addressing hash table** for O(1) average lookups with reduced probe variance
2. **Array[K]** tracking insertion order for guaranteed-order iteration

Deletion uses tombstone markers to maintain probe chain integrity, with automatic rehashing when the tombstone ratio exceeds 25%.

## Trade-offs vs. builtin Map

| Property | `@builtin.Map` | `IndexMap` |
|----------|---------------|------------|
| Lookup | O(1) avg | O(1) avg |
| Insert | O(1) avg | O(1) avg |
| Remove | O(1) avg | O(n) worst |
| Iteration order | Undefined | Insertion order |
| Index access | No | Yes |
| Memory | Lower | ~2x (order array) |
| Hash algorithm | Built-in `Hash` trait | Built-in `Hash` trait |

## Development

```bash
# Install MoonBit toolchain
curl -fsSL https://cli.moonbitlang.com/install/unix.sh | bash

# Type check
moon check

# Run tests (157 tests)
moon test
```

## License

Apache 2.0 — see [LICENSE](LICENSE) for details.

## Acknowledgments

This project is inspired by the Rust [`indexmap`](https://github.com/indexmap-rs/indexmap) crate (Apache 2.0 / MIT dual-licensed).

Built as part of the **MoonBit Open Source Ecosystem Competition 2026**.
