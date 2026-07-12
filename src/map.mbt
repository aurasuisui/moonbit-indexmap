// Copyright (c) 2024-2026 moonbit-indexmap contributors
// SPDX-License-Identifier: Apache-2.0

// IndexMap: A hash map that preserves insertion order.

///|
/// Minimum capacity of the hash table (power of two).
const MIN_CAPACITY : Int = 16

///|
/// Sentinel indicating no probe distance limit — entry has never been displaced.
const NO_DISTANCE : Int = -1

///|
/// An entry stored in the hash table buckets.
/// Uses `TraitField` pattern — key and hash are immutable to maintain
/// probe-chain integrity, while distance is mutable for Robin Hood insertion.
struct Entry[K, V] {
  key : K
  value : V
  hash : Int
  mut distance : Int
} derive(Debug)

///|
/// The sentinel hash value used for tombstone (deleted) entries.
/// Using -1 as a marker that won't collide with real hash values.
const TOMBSTONE_HASH : Int = -1

///|
/// The main IndexMap type.
struct IndexMap[K, V] {
  mut buckets : Array[Entry[K, V]?]
  mut order : Array[K]
  mut positions : Map[K, Int]
  mut len : Int
  mut mask : Int
  mut tombstone_count : Int
  mut max_probe_distance : Int
}

///|
/// A consuming iterator over (key, value) pairs in insertion order.
struct IntoMapIter[K, V] {
  entries : Array[(K, V)]
  mut pos : Int
}

///|
/// Entry API — a view into a single entry in the map.
pub enum EntryView[K, V] {
  Occupied(OccupiedEntry[K, V])
  Vacant(VacantEntry[K, V])
}

///|
/// A view into an occupied entry.
pub struct OccupiedEntry[K, V] {
  map : IndexMap[K, V]
  key : K
  hash : Int
  bucket_index : Int
}

///|
/// A view into a vacant entry.
pub struct VacantEntry[K, V] {
  map : IndexMap[K, V]
  key : K
  hash : Int
  bucket_index : Int
}

// ---------------------------------------------------------------------------
// Internal: utility functions
// ---------------------------------------------------------------------------

///|
/// Check if the current load exceeds the threshold for resizing.
fn should_resize_impl(len : Int, capacity : Int) -> Bool {
  len * LOAD_FACTOR_DENOMINATOR >= capacity * LOAD_FACTOR_NUMERATOR
}

///|
/// Compute the next power of two greater than or equal to `n`.
fn next_power_of_two_impl(n : Int) -> Int {
  if n <= 1 {
    return 1
  }
  let mut p = 1
  while p < n {
    p = p << 1
  }
  p
}

///|
/// Simple probe to find an existing key.
fn[K : Eq, V] IndexMap::probe_find(
  self : IndexMap[K, V],
  key : K,
  hash : Int,
) -> (Int, Bool) {
  let start = hash & self.mask
  let mut i = start
  while true {
    match self.buckets[i] {
      None => return (i, false)
      Some(entry) =>
        if entry.hash != TOMBSTONE_HASH &&
          entry.hash == hash &&
          entry.key == key {
          return (i, true)
        }
    }
    i = (i + 1) & self.mask
    if i == start {
      return (i, false)
    }
  }
  (0, false)
}

///|
/// Find a bucket using Robin Hood hashing.
fn[K : Eq, V] IndexMap::robin_hood_find(
  self : IndexMap[K, V],
  key : K,
  hash : Int,
) -> (Int, Bool) {
  let start = hash & self.mask
  let mut i = start
  let mut dist = 0
  let mut first_tombstone : Int = -1

  while true {
    match self.buckets[i] {
      None => {
        let insert_at = if first_tombstone >= 0 { first_tombstone } else { i }
        return (insert_at, false)
      }
      Some(entry) => {
        if entry.hash == TOMBSTONE_HASH {
          if first_tombstone < 0 {
            first_tombstone = i
          }
        } else if entry.hash == hash && entry.key == key {
          return (i, true)
        }
        if entry.distance >= 0 && entry.distance < dist {
          let insert_at = if first_tombstone >= 0 { first_tombstone } else { i }
          return (insert_at, false)
        }
      }
    }
    i = (i + 1) & self.mask
    dist = dist + 1
    if i == start {
      return (i, false)
    }
  }
  (0, false)
}

///|
/// Insert an entry at the given bucket index using Robin Hood displacement.
fn[K, V] IndexMap::robin_hood_insert_at(
  self : IndexMap[K, V],
  entry_param : Entry[K, V],
  start_idx : Int,
  hash : Int,
) -> Unit {
  let mut entry = entry_param
  let mut i = start_idx
  let mut dist = if start_idx == (hash & self.mask) {
    0
  } else {
    (start_idx - (hash & self.mask)) & self.mask
  }

  while true {
    match self.buckets[i] {
      None => {
        entry.distance = dist
        self.buckets[i] = Some(entry)
        if dist > self.max_probe_distance {
          self.max_probe_distance = dist
        }
        return
      }
      Some(existing) => {
        if existing.hash == TOMBSTONE_HASH {
          entry.distance = dist
          self.buckets[i] = Some(entry)
          self.tombstone_count = self.tombstone_count - 1
          if dist > self.max_probe_distance {
            self.max_probe_distance = dist
          }
          return
        }
        if existing.distance >= 0 && existing.distance < dist {
          entry.distance = dist
          self.buckets[i] = Some(entry)
          if dist > self.max_probe_distance {
            self.max_probe_distance = dist
          }
          entry = existing
          dist = existing.distance + 1
        } else {
          dist = dist + 1
        }
      }
    }
    i = (i + 1) & self.mask
  }
}

///|
/// Remove a key from the order array, shifting later elements left to
/// preserve insertion order (O(n)). Updates `positions` accordingly.
fn[K : Hash + Eq, V] IndexMap::remove_from_order(
  self : IndexMap[K, V],
  key : K,
) -> Unit {
  match self.positions.get(key) {
    None => ()
    Some(pos) => {
      // Shift elements after `pos` one slot left, fixing their positions.
      let mut i = pos
      let last_idx = self.order.length() - 1
      while i < last_idx {
        let next_key = self.order[i + 1]
        self.order[i] = next_key
        self.positions[next_key] = i
        i = i + 1
      }
      self.order.pop() |> ignore
      self.positions.remove(key) |> ignore
    }
  }
}

///|
/// Resize the hash table to a new capacity and rehash all entries.
fn[K : Hash + Eq, V] IndexMap::resize(
  self : IndexMap[K, V],
  new_cap : Int,
) -> Unit {
  self.rehash(new_cap)
}

///|
/// Rebuild the hash table in-place, clearing all tombstones.
fn[K : Hash + Eq, V] IndexMap::rehash(
  self : IndexMap[K, V],
  new_cap : Int,
) -> Unit {
  let cap = if new_cap > 0 { new_cap } else { self.buckets.length() }
  let new_buckets : Array[Entry[K, V]?] = Array::make(cap, None)
  let new_mask = cap - 1
  let mut new_len = 0
  let mut new_max_probe = 0

  let mut pos = 0
  while pos < self.order.length() {
    let key = self.order[pos]
    let (old_idx, found) = self.probe_find(key, key.hash())
    if found {
      match self.buckets[old_idx] {
        Some(entry) => {
          let mut dist = 0
          let mut i = entry.hash & new_mask
          let mut to_insert = {
            key: entry.key,
            value: entry.value,
            hash: entry.hash,
            distance: 0,
          }
          while true {
            match new_buckets[i] {
              None => {
                to_insert.distance = dist
                new_buckets[i] = Some(to_insert)
                new_len = new_len + 1
                if dist > new_max_probe {
                  new_max_probe = dist
                }
                break
              }
              Some(existing) => {
                let cur = existing
                if cur.distance >= 0 && cur.distance < dist {
                  to_insert.distance = dist
                  new_buckets[i] = Some(to_insert)
                  if dist > new_max_probe {
                    new_max_probe = dist
                  }
                  to_insert = cur
                  dist = cur.distance + 1
                } else {
                  dist = dist + 1
                }
              }
            }
            i = (i + 1) & new_mask
          }
        }
        None => ()
      }
    }
    pos = pos + 1
  }

  self.buckets = new_buckets
  self.mask = new_mask
  self.len = new_len
  self.tombstone_count = 0
  self.max_probe_distance = new_max_probe
}

// ---------------------------------------------------------------------------
// Construction
// ---------------------------------------------------------------------------

///|
/// Create a new, empty IndexMap with default capacity (16 buckets).
pub fn[K : Hash + Eq, V] IndexMap::new() -> IndexMap[K, V] {
  IndexMap::with_capacity(MIN_CAPACITY)
}

///|
pub impl[K : Hash + Eq, V] Default for IndexMap[K, V] with fn default() {
  IndexMap::new()
}

///|
/// Create a new IndexMap with the given initial capacity.
pub fn[K : Hash + Eq, V] IndexMap::with_capacity(cap : Int) -> IndexMap[K, V] {
  let real_cap = if cap < MIN_CAPACITY {
    MIN_CAPACITY
  } else {
    next_power_of_two_impl(cap)
  }
  let mask = real_cap - 1
  {
    buckets: Array::make(real_cap, None),
    order: [],
    positions: Map([], capacity=real_cap),
    len: 0,
    mask,
    tombstone_count: 0,
    max_probe_distance: 0,
  }
}

///|
/// Create an IndexMap from an array of (key, value) pairs.
pub fn[K : Hash + Eq, V] IndexMap::from_array(
  entries : Array[(K, V)],
) -> IndexMap[K, V] {
  let map = IndexMap::with_capacity(entries.length())
  let mut i = 0
  while i < entries.length() {
    let (k, v) = entries[i]
    map.insert(k, v) |> ignore
    i = i + 1
  }
  map
}

// ---------------------------------------------------------------------------
// Size queries
// ---------------------------------------------------------------------------

///|
/// Return the number of entries in the map.
pub fn[K, V] IndexMap::len(self : IndexMap[K, V]) -> Int {
  self.len
}

///|
/// Return `true` if the map contains no entries.
pub fn[K, V] IndexMap::is_empty(self : IndexMap[K, V]) -> Bool {
  self.len == 0
}

///|
/// Return the current number of buckets in the underlying hash table.
pub fn[K, V] IndexMap::capacity(self : IndexMap[K, V]) -> Int {
  self.buckets.length()
}

///|
/// Return the current load factor (entries / capacity).
pub fn[K, V] IndexMap::load_factor(self : IndexMap[K, V]) -> Double {
  if self.buckets.length() == 0 {
    0.0
  } else {
    (self.len + self.tombstone_count).to_double() /
    self.buckets.length().to_double()
  }
}

///|
/// Return the maximum probe distance observed.
pub fn[K, V] IndexMap::max_probe(self : IndexMap[K, V]) -> Int {
  self.max_probe_distance
}

// ---------------------------------------------------------------------------
// Core operations: insert, get, remove, contains
// ---------------------------------------------------------------------------

///|
/// Insert a key-value pair into the map.
pub fn[K : Hash + Eq, V] IndexMap::insert(
  self : IndexMap[K, V],
  key : K,
  value : V,
) -> V? {
  let hash = key.hash()
  if should_resize_impl(self.len + self.tombstone_count, self.buckets.length()) {
    self.resize(self.buckets.length() * 2)
  }
  let (bucket_idx, found) = self.robin_hood_find(key, hash)
  if found {
    match self.buckets[bucket_idx] {
      Some(entry) => {
        let old = entry.value
        let new_entry = {
          key: entry.key,
          value,
          hash: entry.hash,
          distance: entry.distance,
        }
        self.buckets[bucket_idx] = Some(new_entry)
        return Some(old)
      }
      None => return None
    }
  } else {
    let new_entry = { key, value, hash, distance: NO_DISTANCE }
    self.robin_hood_insert_at(new_entry, bucket_idx, hash)
    self.order.push(key)
    self.positions[key] = self.order.length() - 1
    self.len = self.len + 1
    return None
  }
}

///|
/// Get a mutable reference to the value associated with `key` via callback.
/// The callback receives `Some(value)` if the key exists, or `None` if not.
/// Changes to the value in the callback are written back to the map.
pub fn[K : Hash + Eq, V] IndexMap::get_mut(
  self : IndexMap[K, V],
  key : K,
  f : (V?) -> V?,
) -> Unit {
  let hash = key.hash()
  let (idx, found) = self.probe_find(key, hash)
  if found {
    match self.buckets[idx] {
      Some(entry) =>
        match f(Some(entry.value)) {
          Some(new_val) => {
            let new_entry = {
              key: entry.key,
              value: new_val,
              hash: entry.hash,
              distance: entry.distance,
            }
            self.buckets[idx] = Some(new_entry)
          }
          None => {
            // Guard: if callback re-inserted the same key, don't tombstone.
            if self.contains(key) {
              return
            }
            self.buckets[idx] = Some({
              key: entry.key,
              value: entry.value,
              hash: TOMBSTONE_HASH,
              distance: NO_DISTANCE,
            })
            self.remove_from_order(key)
            self.tombstone_count = self.tombstone_count + 1
            self.len = self.len - 1
          }
        }
      None => f(None) |> ignore
    }
  } else {
    f(None) |> ignore
  }
}

///|
/// Get a value associated with `key`.
pub fn[K : Hash + Eq, V] IndexMap::get(self : IndexMap[K, V], key : K) -> V? {
  let hash = key.hash()
  let (idx, found) = self.probe_find(key, hash)
  if found {
    match self.buckets[idx] {
      Some(entry) => Some(entry.value)
      None => None
    }
  } else {
    None
  }
}

///|
/// Remove a key from the map, returning the value if it was present.
pub fn[K : Hash + Eq, V] IndexMap::remove(self : IndexMap[K, V], key : K) -> V? {
  let hash = key.hash()
  let (idx, found) = self.probe_find(key, hash)
  if !found {
    return None
  }
  match self.buckets[idx] {
    None => return None
    Some(entry) => {
      let removed_value = entry.value
      self.buckets[idx] = Some({
        key: entry.key,
        value: entry.value,
        hash: TOMBSTONE_HASH,
        distance: NO_DISTANCE,
      })
      self.tombstone_count = self.tombstone_count + 1
      self.len = self.len - 1
      self.remove_from_order(key)
      let total = self.len + self.tombstone_count
      if self.tombstone_count * 4 > self.buckets.length() && total > 0 {
        self.rehash(self.buckets.length())
      }
      return Some(removed_value)
    }
  }
}

///|
/// Return `true` if the map contains `key`.
pub fn[K : Hash + Eq, V] IndexMap::contains(
  self : IndexMap[K, V],
  key : K,
) -> Bool {
  let (_, found) = self.probe_find(key, key.hash())
  found
}

///|
/// Remove all entries from the map.
pub fn[K : Hash + Eq, V] IndexMap::clear(self : IndexMap[K, V]) -> Unit {
  let cap = self.buckets.length()
  self.buckets = Array::make(cap, None)
  self.order = []
  self.positions = Map([])
  self.len = 0
  self.tombstone_count = 0
  self.max_probe_distance = 0
}

///|
/// Create a shallow copy of this IndexMap, preserving insertion order.
pub fn[K : Hash + Eq, V] IndexMap::copy(
  self : IndexMap[K, V],
) -> IndexMap[K, V] {
  let order_copy : Array[K] = []
  let positions_copy : Map[K, Int] = Map([])
  let mut i = 0
  while i < self.order.length() {
    let k = self.order[i]
    order_copy.push(k)
    positions_copy[k] = i
    i = i + 1
  }
  {
    buckets: self.buckets.copy(),
    order: order_copy,
    positions: positions_copy,
    len: self.len,
    mask: self.mask,
    tombstone_count: self.tombstone_count,
    max_probe_distance: self.max_probe_distance,
  }
}

///|
/// Reserve capacity for at least `additional` more entries.
pub fn[K : Hash + Eq, V] IndexMap::reserve(
  self : IndexMap[K, V],
  additional : Int,
) -> Unit {
  let needed = self.len + additional
  let cap = self.buckets.length()
  if needed > cap || needed * 4 > cap * 3 {
    let new_cap = next_power_of_two_impl(needed * 2)
    self.resize(if new_cap < MIN_CAPACITY { MIN_CAPACITY } else { new_cap })
  }
}

///|
/// Shrink the capacity to fit the current number of entries.
pub fn[K : Hash + Eq, V] IndexMap::shrink_to_fit(self : IndexMap[K, V]) -> Unit {
  let new_cap = next_power_of_two_impl(self.len)
  let real_cap = if new_cap < MIN_CAPACITY { MIN_CAPACITY } else { new_cap }
  if real_cap < self.buckets.length() {
    self.rehash(real_cap)
  }
}

// ---------------------------------------------------------------------------
// Entry API
// ---------------------------------------------------------------------------

///|
/// Get the entry for `key` in the map for in-place manipulation.
pub fn[K : Hash + Eq, V] IndexMap::entry(
  self : IndexMap[K, V],
  key : K,
) -> EntryView[K, V] {
  let hash = key.hash()
  let (idx, found) = self.robin_hood_find(key, hash)
  if found {
    Occupied({ map: self, key, hash, bucket_index: idx })
  } else {
    Vacant({ map: self, key, hash, bucket_index: idx })
  }
}

///|
/// Get the value stored in this occupied entry.
pub fn[K, V] OccupiedEntry::get(self : OccupiedEntry[K, V]) -> V {
  match self.map.buckets[self.bucket_index] {
    Some(entry) => entry.value
    None => abort("OccupiedEntry: bucket unexpectedly empty")
  }
}

///|
/// Replace the value in this occupied entry, returning the old value.
pub fn[K, V] OccupiedEntry::insert(self : OccupiedEntry[K, V], value : V) -> V {
  match self.map.buckets[self.bucket_index] {
    Some(entry) => {
      let old = entry.value
      let new_entry = {
        key: entry.key,
        value,
        hash: entry.hash,
        distance: entry.distance,
      }
      self.map.buckets[self.bucket_index] = Some(new_entry)
      old
    }
    None => abort("OccupiedEntry: bucket unexpectedly empty")
  }
}

///|
/// Remove this entry from the map, returning the value.
pub fn[K : Hash + Eq, V] OccupiedEntry::remove(self : OccupiedEntry[K, V]) -> V {
  match self.map.remove(self.key) {
    Some(v) => v
    None => abort("OccupiedEntry::remove: key not found")
  }
}

///|
/// Get the key for this occupied entry.
pub fn[K, V] OccupiedEntry::key(self : OccupiedEntry[K, V]) -> K {
  self.key
}

///|
/// Insert a value into this vacant entry, returning the value inserted.
pub fn[K : Hash + Eq, V] VacantEntry::insert(
  self : VacantEntry[K, V],
  value : V,
) -> V {
  let entry = { key: self.key, value, hash: self.hash, distance: NO_DISTANCE }
  self.map.robin_hood_insert_at(entry, self.bucket_index, self.hash)
  self.map.order.push(self.key)
  self.map.positions[self.key] = self.map.order.length() - 1
  self.map.len = self.map.len + 1
  value
}

///|
/// Get the key for this vacant entry.
pub fn[K, V] VacantEntry::key(self : VacantEntry[K, V]) -> K {
  self.key
}

// ---------------------------------------------------------------------------
// Index-based access
// ---------------------------------------------------------------------------

///|
/// Get the entry at the given insertion-order index.
pub fn[K : Hash + Eq, V] IndexMap::get_index(
  self : IndexMap[K, V],
  index : Int,
) -> (K, V)? {
  if index < 0 || index >= self.order.length() {
    return None
  }
  let key = self.order[index]
  match self.get(key) {
    Some(v) => Some((key, v))
    None => None
  }
}

///|
/// Get the full entry (key and value) for the given key.
pub fn[K : Hash + Eq, V] IndexMap::get_full(
  self : IndexMap[K, V],
  key : K,
) -> (K, V)? {
  match self.get(key) {
    Some(v) => Some((key, v))
    None => None
  }
}

///|
/// Get the insertion-order index of the given key.
pub fn[K : Hash + Eq, V] IndexMap::get_index_of(
  self : IndexMap[K, V],
  key : K,
) -> Int? {
  self.positions.get(key)
}

///|
/// Get the first entry (earliest inserted).
pub fn[K : Hash + Eq, V] IndexMap::first(self : IndexMap[K, V]) -> (K, V)? {
  self.get_index(0)
}

///|
/// Get the last entry (most recently inserted).
pub fn[K : Hash + Eq, V] IndexMap::last(self : IndexMap[K, V]) -> (K, V)? {
  if self.order.length() == 0 {
    return None
  }
  let key = self.order[self.order.length() - 1]
  match self.get(key) {
    Some(v) => Some((key, v))
    None => None
  }
}

///|
/// Swap-remove the entry at the given position.
pub fn[K : Hash + Eq, V] IndexMap::swap_remove_index(
  self : IndexMap[K, V],
  index : Int,
) -> (K, V)? {
  if index < 0 || index >= self.order.length() {
    return None
  }
  let key = self.order[index]
  match self.remove(key) {
    Some(v) => Some((key, v))
    None => None
  }
}

///|
/// Remove and return the last entry (most recently inserted).
pub fn[K : Hash + Eq, V] IndexMap::pop(self : IndexMap[K, V]) -> (K, V)? {
  if self.order.length() == 0 {
    return None
  }
  let key = self.order[self.order.length() - 1]
  match self.get(key) {
    Some(v) => {
      self.remove(key) |> ignore
      Some((key, v))
    }
    None => None
  }
}

// ---------------------------------------------------------------------------
// Iteration
// ---------------------------------------------------------------------------

///|
/// Return a lazy iterator over (key, value) pairs in insertion order.
/// Supports `for (k, v) in map { ... }` syntax.
pub fn[K : Hash + Eq, V] IndexMap::iter(self : IndexMap[K, V]) -> Iter[(K, V)] {
  let mut pos = 0
  let len = self.order.length()
  Iter::new(
    fn() -> (K, V)? {
      while pos < len {
        let key = self.order[pos]
        pos = pos + 1
        match self.get(key) {
          Some(v) => return Some((key, v))
          None => continue
        }
      }
      None
    },
    size_hint=len,
  )
}

///|
/// Return a lazy iterator over keys in insertion order.
pub fn[K : Hash + Eq, V] IndexMap::keys(self : IndexMap[K, V]) -> Iter[K] {
  let mut pos = 0
  let len = self.order.length()
  Iter::new(
    fn() -> K? {
      while pos < len {
        let key = self.order[pos]
        pos = pos + 1
        if self.contains(key) {
          return Some(key)
        }
      }
      None
    },
    size_hint=len,
  )
}

///|
/// Return a lazy iterator over values in insertion order.
pub fn[K : Hash + Eq, V] IndexMap::values(self : IndexMap[K, V]) -> Iter[V] {
  let mut pos = 0
  let len = self.order.length()
  Iter::new(
    fn() -> V? {
      while pos < len {
        let key = self.order[pos]
        pos = pos + 1
        match self.get(key) {
          Some(v) => return Some(v)
          None => continue
        }
      }
      None
    },
    size_hint=len,
  )
}

///|
/// Advance the consuming iterator.
pub fn[K, V] IntoMapIter::next(self : IntoMapIter[K, V]) -> (K, V)? {
  if self.pos >= self.entries.length() {
    return None
  }
  let entry = self.entries[self.pos]
  self.pos = self.pos + 1
  Some(entry)
}

///|
/// Collect all remaining entries from the consuming iterator.
pub fn[K, V] IntoMapIter::collect(self : IntoMapIter[K, V]) -> Array[(K, V)] {
  let result = []
  let mut i = self.pos
  while i < self.entries.length() {
    result.push(self.entries[i])
    i = i + 1
  }
  result
}

///|
/// Return the number of entries remaining in the consuming iterator.
pub fn[K, V] IntoMapIter::count_remaining(self : IntoMapIter[K, V]) -> Int {
  self.entries.length() - self.pos
}

///|
/// Apply a function to each (key, value) pair in insertion order.
pub fn[K : Hash + Eq, V] IndexMap::for_each(
  self : IndexMap[K, V],
  f : (K, V) -> Unit,
) -> Unit {
  let iter = self.iter()
  while true {
    match iter.next() {
      Some((k, v)) => f(k, v)
      None => break
    }
  }
}

// ---------------------------------------------------------------------------
// Bulk operations
// ---------------------------------------------------------------------------

///|
/// Retain only the entries for which the predicate returns `true`.
pub fn[K : Hash + Eq, V] IndexMap::retain(
  self : IndexMap[K, V],
  f : (K, V) -> Bool,
) -> Unit {
  let to_remove : Array[K] = []
  let iter = self.iter()
  while true {
    match iter.next() {
      Some((k, v)) => if !f(k, v) { to_remove.push(k) }
      None => break
    }
  }
  let mut i = 0
  while i < to_remove.length() {
    self.remove(to_remove[i]) |> ignore
    i = i + 1
  }
}

///|
/// Recalculate `max_probe_distance` by scanning all buckets.
/// Called after operations that rebuild `order`/`positions` but leave buckets intact
/// (e.g., `sort_by_key`, `sort_by`) to keep the reported value consistent.
fn[K, V] IndexMap::recalc_max_probe(self : IndexMap[K, V]) -> Unit {
  let mut max_d = 0
  let mut bi = 0
  while bi < self.buckets.length() {
    match self.buckets[bi] {
      Some(e) =>
        if e.distance > max_d && e.hash != TOMBSTONE_HASH {
          max_d = e.distance
        }
      None => ()
    }
    bi = bi + 1
  }
  self.max_probe_distance = max_d
}

///|
/// Sort the map's entries by key using MoonBit's built-in sort (O(n log n)).
pub fn[K : Hash + Eq + Compare, V] IndexMap::sort_by_key(
  self : IndexMap[K, V],
) -> Unit {
  let entries = self.iter().collect()
  entries.sort_by(fn(a, b) { a.0.compare(b.0) })
  self.order = []
  self.positions = Map([])
  let mut i = 0
  while i < entries.length() {
    let (k, _) = entries[i]
    self.order.push(k)
    self.positions[k] = i
    i = i + 1
  }
  self.recalc_max_probe()
}

///|
/// Consume the map and return an iterator over (key, value) pairs.
pub fn[K : Hash + Eq, V] IndexMap::into_iter(
  self : IndexMap[K, V],
) -> IntoMapIter[K, V] {
  { entries: self.drain(), pos: 0 }
}

///|
/// Consume the map and return its entries as an array in insertion order.
pub fn[K : Hash + Eq, V] IndexMap::into_array(
  self : IndexMap[K, V],
) -> Array[(K, V)] {
  self.drain()
}

///|
/// Sort the map's entries using a custom comparison function (O(n log n)).
pub fn[K : Hash + Eq, V] IndexMap::sort_by(
  self : IndexMap[K, V],
  cmp : ((K, V), (K, V)) -> Int,
) -> Unit {
  let entries = self.iter().collect()
  entries.sort_by(cmp)
  self.order = []
  self.positions = Map([])
  let mut i = 0
  while i < entries.length() {
    let (k, _) = entries[i]
    self.order.push(k)
    self.positions[k] = i
    i = i + 1
  }
  self.recalc_max_probe()
}

///|
/// Drain all entries from the map, returning them in insertion order.
pub fn[K : Hash + Eq, V] IndexMap::drain(
  self : IndexMap[K, V],
) -> Array[(K, V)] {
  let result = self.iter().collect()
  self.clear()
  result
}

///|
/// Extend the map with entries from an array of (key, value) pairs.
pub fn[K : Hash + Eq, V] IndexMap::extend_from_array(
  self : IndexMap[K, V],
  entries : Array[(K, V)],
) -> Unit {
  let mut i = 0
  while i < entries.length() {
    let (k, v) = entries[i]
    self.insert(k, v) |> ignore
    i = i + 1
  }
}

// ---------------------------------------------------------------------------
// Trait implementations
// ---------------------------------------------------------------------------

///|
/// Show implementation for debugging IndexMap contents.
/// **Example:**
/// ```
/// let map = IndexMap::new()
/// map.insert("a", 1)
/// map.insert("b", 2)
/// map.to_string() |> ignore
/// ```
pub impl[K : Show + Hash + Eq, V : Show] Show for IndexMap[K, V] with fn output(
  self,
  logger,
) {
  logger.write_string("IndexMap{")
  let mut first = true
  let iter = self.iter()
  while true {
    match iter.next() {
      Some((k, v)) => {
        if !first {
          logger.write_string(", ")
        }
        k.output(logger)
        logger.write_string(": ")
        v.output(logger)
        first = false
      }
      None => break
    }
  }
  logger.write_string("}")
}

///|
/// Debug implementation for IndexMap (insertion order).
pub impl[K : Debug + Hash + Eq, V : Debug] Debug for IndexMap[K, V] with fn to_repr(
  self,
) {
  let entries : Array[(Repr, Repr)] = []
  let iter = self.iter()
  while true {
    match iter.next() {
      Some((k, v)) => entries.push((to_repr(k), to_repr(v)))
      None => break
    }
  }
  Repr::opaque_("IndexMap", Repr::map(entries))
}

///|
/// Hash implementation for IndexMap (hashes entries in insertion order).
pub impl[K : Hash + Eq, V : Hash] Hash for IndexMap[K, V] with fn hash_combine(
  self,
  hasher,
) {
  let iter = self.iter()
  while true {
    match iter.next() {
      Some((k, v)) => {
        k.hash_combine(hasher)
        v.hash_combine(hasher)
      }
      None => break
    }
  }
}

///|
/// Equality comparison for IndexMap.
pub impl[K : Hash + Eq, V : Eq] Eq for IndexMap[K, V] with fn equal(self, other) {
  if self.len != other.len() {
    return false
  }
  let a_iter = self.iter()
  let b_iter = other.iter()
  while true {
    match (a_iter.next(), b_iter.next()) {
      (Some((ak, av)), Some((bk, bv))) =>
        if ak != bk || av != bv {
          return false
        }
      (None, None) => return true
      _ => return false
    }
  }
  false
}

///|
/// Serialize an IndexMap to JSON, preserving insertion order.
pub impl[K : ToJson + Hash + Eq, V : ToJson] ToJson for IndexMap[K, V] with fn to_json(
  self,
) {
  let obj : Map[String, Json] = Map([])
  let iter = self.iter()
  while true {
    match iter.next() {
      Some((k, v)) => obj[@debug.to_string(k.to_json())] = v.to_json()
      None => break
    }
  }
  Json::object(obj)
}

// ---------------------------------------------------------------------------
// QuickCheck Arbitrary support
// ---------------------------------------------------------------------------

///|
/// Generate random IndexMap values for property-based testing.
pub impl[K : @quickcheck.Arbitrary + Hash + Eq, V : @quickcheck.Arbitrary] @quickcheck.Arbitrary for IndexMap[
  K,
  V,
] with fn arbitrary(size, r0) {
  let entries : Array[(K, V)] = @quickcheck.Arbitrary::arbitrary(size, r0)
  IndexMap::from_array(entries)
}
