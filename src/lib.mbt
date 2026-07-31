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
pub const VERSION : String = "0.4.0"

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

///|
/// Deserialize an IndexMap from a JSON object (String keys, order-preserving).
/// See `IndexMap::from_json`.
pub fn[V : FromJson] from_json(
  json : Json,
) -> IndexMap[String, V] raise @json.JsonDecodeError {
  IndexMap::from_json(json)
}

///|
/// Deserialize an IndexMap from a JSON object, parsing each key from `String`.
/// See `IndexMap::from_json_with`.
pub fn[K : Hash + Eq, V : FromJson] from_json_with(
  json : Json,
  parse_key : (String) -> K,
) -> IndexMap[K, V] raise @json.JsonDecodeError {
  IndexMap::from_json_with(json, parse_key)
}
