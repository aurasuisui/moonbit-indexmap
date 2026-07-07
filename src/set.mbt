// Copyright (c) 2024-2026 moonbit-indexmap contributors
// SPDX-License-Identifier: Apache-2.0

// IndexSet: A hash set that preserves insertion order.
//
// IndexSet is built on top of IndexMap, using `Unit` as the value type.
// It provides O(1) lookups and guaranteed insertion-order iteration.

///|
/// A hash set that preserves insertion order.
/// Wraps IndexMap[K, Unit] internally.
struct IndexSet[K] {
  inner : IndexMap[K, Unit]
}

// ---------------------------------------------------------------------------
// Construction
// ---------------------------------------------------------------------------

///|
/// Create a new, empty IndexSet.
pub fn[K : Hash + Eq] IndexSet::new() -> IndexSet[K] {
  { inner: IndexMap::new() }
}

///|
pub impl[K : Hash + Eq] Default for IndexSet[K] with fn default() {
  IndexSet::new()
}

///|
/// Create a new IndexSet with the given initial capacity.
pub fn[K : Hash + Eq] IndexSet::with_capacity(cap : Int) -> IndexSet[K] {
  { inner: IndexMap::with_capacity(cap) }
}

///|
/// Create an IndexSet from an array of elements.
pub fn[K : Hash + Eq] IndexSet::from_array(elements : Array[K]) -> IndexSet[K] {
  let set = IndexSet::with_capacity(elements.length())
  let mut i = 0
  while i < elements.length() {
    set.insert(elements[i]) |> ignore
    i = i + 1
  }
  set
}

// ---------------------------------------------------------------------------
// Size queries
// ---------------------------------------------------------------------------

///|
/// Return the number of elements in the set.
pub fn[K] IndexSet::len(self : IndexSet[K]) -> Int {
  self.inner.len
}

///|
/// Return `true` if the set contains no elements.
pub fn[K] IndexSet::is_empty(self : IndexSet[K]) -> Bool {
  self.inner.is_empty()
}

///|
/// Return the current capacity of the underlying set.
pub fn[K] IndexSet::capacity(self : IndexSet[K]) -> Int {
  self.inner.capacity()
}

// ---------------------------------------------------------------------------
// Core operations
// ---------------------------------------------------------------------------

///|
/// Insert a value into the set.
/// Returns `true` if the value was newly inserted, `false` if it already existed.
pub fn[K : Hash + Eq] IndexSet::insert(self : IndexSet[K], value : K) -> Bool {
  match self.inner.insert(value, ()) {
    Some(_) => false
    None => true
  }
}

///|
/// Return `true` if the set contains `value`.
pub fn[K : Hash + Eq] IndexSet::contains(self : IndexSet[K], value : K) -> Bool {
  self.inner.contains(value)
}

///|
/// Remove a value from the set.
/// Returns `true` if the value was present and removed.
pub fn[K : Hash + Eq] IndexSet::remove(self : IndexSet[K], value : K) -> Bool {
  match self.inner.remove(value) {
    Some(_) => true
    None => false
  }
}

///|
/// Remove all elements from the set.
pub fn[K : Hash + Eq] IndexSet::clear(self : IndexSet[K]) -> Unit {
  self.inner.clear()
}

///|
/// Create a shallow copy of this IndexSet, preserving insertion order.
pub fn[K : Hash + Eq] IndexSet::copy(self : IndexSet[K]) -> IndexSet[K] {
  { inner: self.inner.copy() }
}

///|
/// Consume the set and return its elements as an array in insertion order.
pub fn[K : Hash + Eq] IndexSet::into_array(self : IndexSet[K]) -> Array[K] {
  let pairs = self.inner.drain()
  let result : Array[K] = []
  let mut i = 0
  while i < pairs.length() {
    let (k, _) = pairs[i]
    result.push(k)
    i = i + 1
  }
  result
}

// ---------------------------------------------------------------------------
// Set operations
// ---------------------------------------------------------------------------

///|
/// Returns true if `self` has no elements in common with `other`.
pub fn[K : Hash + Eq] IndexSet::is_disjoint(
  self : IndexSet[K],
  other : IndexSet[K],
) -> Bool {
  let iter = self.inner.keys()
  while true {
    match iter.next() {
      Some(k) => if other.inner.contains(k) { return false }
      None => return true
    }
  }
  true
}

///|
/// Returns true if `self` is a subset of `other`.
pub fn[K : Hash + Eq] IndexSet::is_subset(
  self : IndexSet[K],
  other : IndexSet[K],
) -> Bool {
  let iter = self.inner.keys()
  while true {
    match iter.next() {
      Some(k) => if !other.inner.contains(k) { return false }
      None => return true
    }
  }
  true
}

///|
/// Returns true if `self` is a superset of `other`.
pub fn[K : Hash + Eq] IndexSet::is_superset(
  self : IndexSet[K],
  other : IndexSet[K],
) -> Bool {
  other.is_subset(self)
}

// ---------------------------------------------------------------------------
// Iteration
// ---------------------------------------------------------------------------

///|
/// Return an iterator over elements in insertion order.
/// Supports `for elem in set { ... }` syntax.
pub fn[K : Hash + Eq] IndexSet::iter(self : IndexSet[K]) -> Iter[K] {
  self.inner.keys()
}

// ---------------------------------------------------------------------------
// Bulk operations
// ---------------------------------------------------------------------------

///|
/// Retain only the elements for which the predicate returns `true`.
pub fn[K : Hash + Eq] IndexSet::retain(
  self : IndexSet[K],
  f : (K) -> Bool,
) -> Unit {
  self.inner.retain(fn(k, _) { f(k) })
}

///|
/// Drain all elements from the set, returning them in insertion order.
pub fn[K : Hash + Eq] IndexSet::drain(self : IndexSet[K]) -> Array[K] {
  let result = []
  let iter = self.iter()
  while true {
    match iter.next() {
      Some(k) => result.push(k)
      None => break
    }
  }
  self.clear()
  result
}

///|
/// Extend the set with elements from an array.
pub fn[K : Hash + Eq] IndexSet::extend_from_array(
  self : IndexSet[K],
  elements : Array[K],
) -> Unit {
  let mut i = 0
  while i < elements.length() {
    self.insert(elements[i]) |> ignore
    i = i + 1
  }
}

// ---------------------------------------------------------------------------
// Trait implementations
// ---------------------------------------------------------------------------

///|
/// Implement Show for IndexSet for debugging.
pub impl[K : Show + Hash + Eq] Show for IndexSet[K] with fn output(self, logger) {
  logger.write_string("IndexSet{")
  let mut first = true
  let iter = self.iter()
  while true {
    match iter.next() {
      Some(k) => {
        if !first {
          logger.write_string(", ")
        }
        k.output(logger)
        first = false
      }
      None => break
    }
  }
  logger.write_string("}")
}

///|
/// Debug implementation for IndexSet (insertion order).
pub impl[K : Debug + Hash + Eq] Debug for IndexSet[K] with fn to_repr(self) {
  let elements : Array[Repr] = []
  let iter = self.iter()
  while true {
    match iter.next() {
      Some(k) => elements.push(to_repr(k))
      None => break
    }
  }
  Repr::opaque_("IndexSet", Repr::array(elements))
}

///|
/// Serialize an IndexSet to JSON, preserving insertion order.
pub impl[K : ToJson + Hash + Eq] ToJson for IndexSet[K] with fn to_json(self) {
  let arr : Array[Json] = []
  let iter = self.iter()
  while true {
    match iter.next() {
      Some(k) => arr.push(k.to_json())
      None => break
    }
  }
  Json::array(arr)
}

///|
/// Equality comparison for IndexSet (elements in same order).
pub impl[K : Hash + Eq] Eq for IndexSet[K] with fn equal(self, other) {
  if self.len() != other.len() {
    return false
  }
  let a_iter = self.iter()
  let b_iter = other.iter()
  while true {
    match (a_iter.next(), b_iter.next()) {
      (Some(ak), Some(bk)) => if ak != bk { return false }
      (None, None) => return true
      _ => return false
    }
  }
  false
}

///|
/// Hash implementation for IndexSet (hashes elements in insertion order).
pub impl[K : Hash + Eq] Hash for IndexSet[K] with fn hash_combine(self, hasher) {
  let iter = self.iter()
  while true {
    match iter.next() {
      Some(k) => k.hash_combine(hasher)
      None => break
    }
  }
}

// ---------------------------------------------------------------------------
// QuickCheck Arbitrary support
// ---------------------------------------------------------------------------

///|
/// Generate random IndexSet values for property-based testing.
pub impl[K : @quickcheck.Arbitrary + Hash + Eq] @quickcheck.Arbitrary for IndexSet[
  K,
] with fn arbitrary(size, r0) {
  let elements : Array[K] = @quickcheck.Arbitrary::arbitrary(size, r0)
  IndexSet::from_array(elements)
}
