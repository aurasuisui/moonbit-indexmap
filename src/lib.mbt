// Copyright (c) 2024-2026 moonbit-indexmap contributors
// SPDX-License-Identifier: Apache-2.0

// moonbit-indexmap: A hash map that preserves insertion order.
//
// This package provides two main types:
//
// - `IndexMap[K, V]`: a hash map preserving key insertion order
// - `IndexSet[K]`: a hash set preserving element insertion order
//
// Both types offer O(1) average lookup performance with guaranteed
// insertion-order iteration, making them ideal for use cases where
// order matters (config parsing, LRU caches, deterministic tests, etc.).
//
// # Quick Start
//
// ```
// let map = @aurasuisui/indexmap.new()
// map.insert("b", 2)
// map.insert("a", 1)
// map.insert("c", 3)
//
// // Iteration follows insertion order: b, a, c
// let mut iter = map.iter()
// while true {
//   match iter.next() {
//     Some((k, v)) => println("\{k}: \{v}")
//     None => break
//   }
// }
// ```

///|
/// Library version string.
pub const VERSION : String = "0.2.1"

///|
/// Create a new, empty IndexMap.
pub fn[K : Hash + Eq, V] new() -> IndexMap[K, V] {
  IndexMap::new()
}

///|
/// Create a new IndexMap with the given initial capacity.
pub fn[K : Hash + Eq, V] with_capacity(cap : Int) -> IndexMap[K, V] {
  IndexMap::with_capacity(cap)
}
