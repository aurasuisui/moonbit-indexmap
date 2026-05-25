// Copyright (c) 2024 moonbit-indexmap contributors
// SPDX-License-Identifier: Apache-2.0

/// Hash utilities for internal use in IndexMap.
///
/// Provides helpers for computing and working with hash values
/// within the open-addressing hash table.

///|
/// The initial capacity of a new IndexMap.
pub const INITIAL_CAPACITY : Int = 16

///|
/// The maximum load factor before the hash table resizes.
/// 0.75 is a standard choice balancing memory and performance.
pub const LOAD_FACTOR_NUMERATOR : Int = 3

///|
pub const LOAD_FACTOR_DENOMINATOR : Int = 4

///|
/// Sentinel value indicating an empty bucket slot.
pub const EMPTY_HASH : Int = 0

///|
/// Sentinel value indicating a tombstone (deleted) bucket slot.
/// Using -1 as a marker that won't collide with real hash values.
/// MoonBit's Hash trait is expected to produce non-negative values.
pub const TOMBSTONE_HASH : Int = -1

///|
/// Compute the bucket index for a given hash and mask.
/// `mask` is the table capacity minus one (assuming power-of-two capacity).
pub fn bucket_index(hash : Int, mask : Int) -> Int {
  // Use bitwise AND for fast modulo when capacity is power of two
  hash & mask
}

///|
/// Check if the current load exceeds the threshold for resizing.
pub fn should_resize(len : Int, capacity : Int) -> Bool {
  len * LOAD_FACTOR_DENOMINATOR >= capacity * LOAD_FACTOR_NUMERATOR
}

///|
/// Compute the next power of two greater than or equal to `n`.
/// Used to ensure hash table capacity is always a power of two.
pub fn next_power_of_two(n : Int) -> Int {
  if n <= 1 {
    return 1
  }
  let mut p = 1
  while p < n {
    p = p << 1
  }
  p
}
