// Copyright (c) 2024-2026 moonbit-indexmap contributors
// SPDX-License-Identifier: Apache-2.0

// IndexMap: A hash map that preserves insertion order.

///|
/// Minimum capacity of the hash table (power of two).
const MIN_CAPACITY : Int = 16

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
/// The main IndexMap type.
struct IndexMap[K, V] {
  mut buckets : Array[Entry[K, V]?]
  mut order : Array[K]
  mut positions : Map[K, Int]
  mut len : Int
  mut mask : Int
  mut max_probe_distance : Int
  mut version : Int
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
}

///|
/// A view into a vacant entry.
pub struct VacantEntry[K, V] {
  map : IndexMap[K, V]
  key : K
  hash : Int
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
/// Locate an existing key or the first Robin Hood displacement candidate.
///
/// The probe always continues to an empty bucket before reporting a miss. This
/// makes key existence independent of the probe-distance ordering invariant;
/// the first bucket whose resident has travelled less than the candidate is
/// merely remembered as the insertion starting point.
fn[K : Eq, V] IndexMap::locate(
  self : IndexMap[K, V],
  key : K,
  hash : Int,
) -> (Int, Bool) {
  let start = hash & self.mask
  let mut i = start
  let mut dist = 0
  let mut first_rich_slot : Int = -1
  while true {
    match self.buckets[i] {
      None => {
        let insert_at = if first_rich_slot >= 0 { first_rich_slot } else { i }
        return (insert_at, false)
      }
      Some(entry) => {
        if entry.hash == hash && entry.key == key {
          return (i, true)
        }
        if first_rich_slot < 0 && entry.distance < dist {
          first_rich_slot = i
        }
      }
    }
    i = (i + 1) & self.mask
    dist = dist + 1
    if i == start {
      abort("IndexMap: locate found no free slot (table full)")
    }
  }
  (0, false)
}

///|
/// Insert an entry into `buckets` using Robin Hood displacement and return
/// the updated maximum probe distance. Both regular insertion and rehashing
/// use this one primitive so their bucket layouts cannot diverge.
fn[K, V] robin_hood_insert_into(
  buckets : Array[Entry[K, V]?],
  mask : Int,
  entry_param : Entry[K, V],
  start_idx : Int,
  max_probe : Int,
) -> Int {
  let mut entry = entry_param
  let mut i = start_idx
  let mut dist = if start_idx == (entry.hash & mask) {
    0
  } else {
    (start_idx - (entry.hash & mask)) & mask
  }
  let mut new_max_probe = max_probe
  // The load-factor invariant guarantees an empty slot. The guard turns a
  // future violation into an abort instead of an unbounded loop.
  let cap = buckets.length()
  let mut steps = 0

  while true {
    if steps >= cap {
      abort("IndexMap: robin_hood_insert_into found no free slot (table full)")
    }
    steps = steps + 1
    match buckets[i] {
      None => {
        entry.distance = dist
        buckets[i] = Some(entry)
        if dist > new_max_probe {
          new_max_probe = dist
        }
        return new_max_probe
      }
      Some(existing) =>
        if existing.distance < dist {
          entry.distance = dist
          buckets[i] = Some(entry)
          if dist > new_max_probe {
            new_max_probe = dist
          }
          entry = existing
          dist = existing.distance + 1
        } else {
          dist = dist + 1
        }
    }
    i = (i + 1) & mask
  }
  0
}

///|
/// Insert an entry at the given bucket index using Robin Hood displacement.
fn[K, V] IndexMap::robin_hood_insert_at(
  self : IndexMap[K, V],
  entry : Entry[K, V],
  start_idx : Int,
) -> Unit {
  self.max_probe_distance = robin_hood_insert_into(
    self.buckets,
    self.mask,
    entry,
    start_idx,
    self.max_probe_distance,
  )
}

///|
/// Remove the entry at `removed_idx` without leaving a tombstone.
///
/// Shift following displaced entries back by one bucket until the next bucket
/// is empty or contains an entry at its home bucket. This preserves the
/// contiguous probe path from every entry's home bucket after deletion.
fn[K, V] IndexMap::backshift_remove(
  self : IndexMap[K, V],
  removed_idx : Int,
) -> Unit {
  let mut hole = removed_idx
  let mut next = (hole + 1) & self.mask
  while true {
    match self.buckets[next] {
      None => {
        self.buckets[hole] = None
        return
      }
      Some(entry) => {
        if entry.distance == 0 {
          self.buckets[hole] = None
          return
        }
        let shifted = entry
        shifted.distance = shifted.distance - 1
        self.buckets[hole] = Some(shifted)
        hole = next
        next = (next + 1) & self.mask
      }
    }
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
/// Rebuild the hash table in-place from insertion-order entries.
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
    let (old_idx, found) = self.locate(key, Hash::hash(key))
    if found {
      match self.buckets[old_idx] {
        Some(entry) => {
          new_max_probe = robin_hood_insert_into(
            new_buckets,
            new_mask,
            {
              key: entry.key,
              value: entry.value,
              hash: entry.hash,
              distance: 0,
            },
            entry.hash & new_mask,
            new_max_probe,
          )
          new_len = new_len + 1
        }
        None => abort("IndexMap: rehash order key is missing from buckets")
      }
    } else {
      abort("IndexMap: rehash order key is missing from buckets")
    }
    pos = pos + 1
  }

  self.buckets = new_buckets
  self.mask = new_mask
  self.len = new_len
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
    max_probe_distance: 0,
    version: 0,
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
    self.len.to_double() / self.buckets.length().to_double()
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
  let hash = Hash::hash(key)
  self.version = self.version + 1
  if should_resize_impl(self.len, self.buckets.length()) {
    self.resize(self.buckets.length() * 2)
  }
  let (bucket_idx, found) = self.locate(key, hash)
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
    let new_entry = { key, value, hash, distance: 0 }
    self.robin_hood_insert_at(new_entry, bucket_idx)
    self.order.push(key)
    self.positions[key] = self.order.length() - 1
    self.len = self.len + 1
    return None
  }
}

///|
/// Update the value associated with `key` via a callback (an in-place upsert).
/// The callback receives `Some(value)` if the key exists, or `None` if it does
/// not. Its return value is authoritative:
/// - `Some(v)` stores `v` under `key`, inserting the key if it was absent.
/// - `None` removes `key` from the map.
///
/// The callback may mutate the map through its closure; the result is always
/// re-applied via `insert`/`remove` (which re-probe and handle resizing), so
/// resizing or removing `key` inside the callback is safe. Returning `None`
/// removes `key` even if the callback re-inserted it — return `Some(v)` to keep
/// a value.
pub fn[K : Hash + Eq, V] IndexMap::get_mut(
  self : IndexMap[K, V],
  key : K,
  f : (V?) -> V?,
) -> Unit {
  let hash = Hash::hash(key)
  let (idx, found) = self.locate(key, hash)
  // Snapshot the current value BEFORE the callback runs; the callback may mutate
  // the map, so `idx` must not be reused afterwards.
  let current : V? = if found {
    match self.buckets[idx] {
      Some(entry) => Some(entry.value)
      None => None
    }
  } else {
    None
  }
  match f(current) {
    Some(new_val) => self.insert(key, new_val) |> ignore
    None => self.remove(key) |> ignore
  }
}

///|
/// Get a value associated with `key`.
pub fn[K : Hash + Eq, V] IndexMap::get(self : IndexMap[K, V], key : K) -> V? {
  let hash = Hash::hash(key)
  let (idx, found) = self.locate(key, hash)
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
  let hash = Hash::hash(key)
  let (idx, found) = self.locate(key, hash)
  if !found {
    return None
  }
  match self.buckets[idx] {
    None => return None
    Some(entry) => {
      let removed_value = entry.value
      self.version = self.version + 1
      self.backshift_remove(idx)
      self.len = self.len - 1
      self.remove_from_order(key)
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
  let (_, found) = self.locate(key, Hash::hash(key))
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
  self.max_probe_distance = 0
  self.version = self.version + 1
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
    max_probe_distance: self.max_probe_distance,
    version: 0,
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
    self.version = self.version + 1
  }
}

///|
/// Shrink the capacity to fit the current number of entries.
pub fn[K : Hash + Eq, V] IndexMap::shrink_to_fit(self : IndexMap[K, V]) -> Unit {
  let new_cap = next_power_of_two_impl(self.len)
  let real_cap = if new_cap < MIN_CAPACITY { MIN_CAPACITY } else { new_cap }
  if real_cap < self.buckets.length() {
    self.rehash(real_cap)
    self.version = self.version + 1
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
  let hash = Hash::hash(key)
  let (_, found) = self.locate(key, hash)
  if found {
    Occupied({ map: self, key, hash })
  } else {
    Vacant({ map: self, key, hash })
  }
}

///|
/// Get the value stored in this occupied entry.
/// Re-probes by key, so a stale handle (the map mutated after `entry()` was
/// called) cannot return another key's value.
pub fn[K : Eq, V] OccupiedEntry::get(self : OccupiedEntry[K, V]) -> V {
  let (idx, found) = self.map.locate(self.key, self.hash)
  if !found {
    abort("OccupiedEntry: key is no longer present in the map")
  }
  match self.map.buckets[idx] {
    Some(entry) => entry.value
    None => abort("OccupiedEntry: key is no longer present in the map")
  }
}

///|
/// Replace the value in this occupied entry, returning the old value.
/// Re-probes by key, so a stale handle (the map mutated after `entry()` was
/// called) cannot overwrite another key's value.
pub fn[K : Eq, V] OccupiedEntry::insert(
  self : OccupiedEntry[K, V],
  value : V,
) -> V {
  let (idx, found) = self.map.locate(self.key, self.hash)
  if !found {
    abort("OccupiedEntry: key is no longer present in the map")
  }
  match self.map.buckets[idx] {
    Some(entry) => {
      let old = entry.value
      let new_entry = {
        key: entry.key,
        value,
        hash: entry.hash,
        distance: entry.distance,
      }
      self.map.buckets[idx] = Some(new_entry)
      self.map.version = self.map.version + 1
      old
    }
    None => abort("OccupiedEntry: key is no longer present in the map")
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
/// Delegates to `IndexMap::insert`, which runs the resize gate and a fresh
/// probe. Filling the map via the Entry API can therefore no longer skip
/// expansion (which previously could drive insertion into an infinite loop),
/// and a stale handle cannot corrupt the table.
pub fn[K : Hash + Eq, V] VacantEntry::insert(
  self : VacantEntry[K, V],
  value : V,
) -> V {
  self.map.insert(self.key, value) |> ignore
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
  let version = self.version
  Iter::new(
    fn() -> (K, V)? {
      if self.version != version {
        abort("IndexMap: map mutated during iteration")
      }
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
  let version = self.version
  Iter::new(
    fn() -> K? {
      if self.version != version {
        abort("IndexMap: map mutated during iteration")
      }
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
  let version = self.version
  Iter::new(
    fn() -> V? {
      if self.version != version {
        abort("IndexMap: map mutated during iteration")
      }
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
/// Recalculate `max_probe_distance` from the current bucket layout.
/// Used after operations that rebuild `order`/`positions` in place (e.g.
/// `sort_by_key` / `sort_by`) to make the invariant "this field always
/// reflects the live buckets" explicit rather than relying on the fact
/// that such operations do not move entries between buckets.
fn[K, V] IndexMap::recalc_max_probe(self : IndexMap[K, V]) -> Unit {
  let mut max_d = 0
  let mut bi = 0
  while bi < self.buckets.length() {
    match self.buckets[bi] {
      Some(e) => if e.distance > max_d { max_d = e.distance }
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
  entries.sort_by(fn(a, b) { Compare::compare(a.0, b.0) })
  self.version = self.version + 1
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
  self.version = self.version + 1
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
        Show::output(k, logger)
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
      Some((k, v)) => entries.push((Repr(k), Repr(v)))
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
        Hash::hash_combine(k, hasher)
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
/// Serialize an IndexMap to a JSON object, preserving insertion order.
/// Object keys are the keys' `Show` rendering (`to_string`), matching
/// `moonbitlang/core`'s own `Map` ToJson convention: a `String` key becomes the
/// raw string (canonical JSON), an `Int` key becomes its decimal text, etc.
pub impl[K : Show + Hash + Eq, V : ToJson] ToJson for IndexMap[K, V] with fn to_json(
  self,
) {
  let obj : Map[String, Json] = Map([])
  let iter = self.iter()
  while true {
    match iter.next() {
      Some((k, v)) => obj[Show::to_string(k)] = v.to_json()
      None => break
    }
  }
  Json::object(obj)
}

// ---------------------------------------------------------------------------
// Deserialization (from_json)
// ---------------------------------------------------------------------------

///|
/// Deserialize an `IndexMap` from a JSON object. Object keys become `String`
/// keys; **insertion order is preserved** (core JSON objects are ordered), so
/// for a `String`-keyed map `from_json(m.to_json()) == m` holds exactly — the
/// strongest round-trip guarantee, since `Eq` is order-sensitive.
///
/// Non-`String` keys are rendered by `to_json` via `Show` and are not generally
/// parseable back; use `from_json_with` to supply a key parser for those.
/// Duplicate JSON keys follow core `Map` semantics (last wins).
pub fn[V : FromJson] IndexMap::from_json(
  json : Json,
) -> IndexMap[String, V] raise @json.JsonDecodeError {
  let obj : Map[String, V] = @json.from_json(json)
  let result : IndexMap[String, V] = IndexMap::new()
  for k, v in obj {
    result.insert(k, v) |> ignore
  }
  result
}

///|
/// Like `from_json`, but parse each JSON object key from `String` into `K`
/// (e.g. integer keys). Insertion order is preserved.
pub fn[K : Hash + Eq, V : FromJson] IndexMap::from_json_with(
  json : Json,
  parse_key : (String) -> K,
) -> IndexMap[K, V] raise @json.JsonDecodeError {
  let obj : Map[String, V] = @json.from_json(json)
  let result : IndexMap[K, V] = IndexMap::new()
  for k, v in obj {
    result.insert(parse_key(k), v) |> ignore
  }
  result
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
