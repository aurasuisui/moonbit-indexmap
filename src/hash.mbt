// Copyright (c) 2024 moonbit-indexmap contributors
// SPDX-License-Identifier: Apache-2.0

// Hash utilities for internal use in IndexMap.
//
// Provides shared constants for the open-addressing hash table.

///|
/// The maximum load factor before the hash table resizes.
/// 0.75 is a standard choice balancing memory and performance.
pub const LOAD_FACTOR_NUMERATOR : Int = 3

///|
pub const LOAD_FACTOR_DENOMINATOR : Int = 4
