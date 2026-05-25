// Copyright (c) 2024 moonbit-indexmap contributors
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
pub fn[K] IndexSet::new() -> IndexSet[K] {
  { inner: IndexMap::new() }
}

///|
/// Create a new IndexSet with the given initial capacity.
pub fn[K] IndexSet::with_capacity(cap : Int) -> IndexSet[K] {
  { inner: IndexMap::with_capacity(cap) }
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
pub fn[K] IndexSet::clear(self : IndexSet[K]) -> Unit {
  self.inner.clear()
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
pub fn[K : Hash + Eq] IndexSet::iter(self : IndexSet[K]) -> Keys[K, Unit] {
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

// ---------------------------------------------------------------------------
// Trait implementations
// ---------------------------------------------------------------------------

///|
/// Implement Show for IndexSet for debugging.
impl[K : Show + Hash + Eq] Show for IndexSet[K] with fn output(self, logger) {
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
