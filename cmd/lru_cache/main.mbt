// Example: Simple LRU (Least Recently Used) cache built on IndexMap.
//
// IndexMap preserves insertion order and supports O(1) remove.
// This makes it a natural fit for an LRU cache: the least recently
// used item is always first in the iteration order.
//
// Usage (in your project's moon.mod.json):
//   { "dependencies": { "aurasuisui/indexmap": "0.3.3" } }

///|
/// A fixed-size LRU cache backed by IndexMap.
/// When capacity is exceeded, the least recently used entry is evicted.
struct LRUCache[V] {
  map : @indexmap.IndexMap[String, V]
  capacity : Int
}

///|
/// Create a new LRU cache with the given capacity.
fn[V] LRUCache::new(capacity? : Int = 100) -> LRUCache[V] {
  { map: @indexmap.with_capacity(capacity), capacity }
}

///|
/// Get a value from the cache. Returns `None` if not present.
/// On a cache hit, the entry is moved to the end (most recently used).
fn[V] LRUCache::get(self : LRUCache[V], key : String) -> V? {
  match self.map.get(key) {
    Some(v) => {
      // Move to end: remove and re-insert
      self.map.remove(key) |> ignore
      self.map.insert(key, v) |> ignore
      Some(v)
    }
    None => None
  }
}

///|
/// Insert a value into the cache.
/// If the cache is full, evicts the least recently used entry (first in order).
fn[V] LRUCache::put(self : LRUCache[V], key : String, value : V) -> Unit {
  // If key exists, remove it first (will be re-inserted at end)
  if self.map.contains(key) {
    self.map.remove(key) |> ignore
  } else if self.map.len() >= self.capacity {
    // Evict least recently used (first entry)
    match self.map.first() {
      Some((oldest_key, _)) => self.map.remove(oldest_key) |> ignore
      None => ()
    }
  }
  self.map.insert(key, value) |> ignore
}

///|
/// Return the current number of entries in the cache.
fn[V] LRUCache::len(self : LRUCache[V]) -> Int {
  self.map.len()
}

///|
/// Return true if the cache contains the key.
fn[V] LRUCache::contains(self : LRUCache[V], key : String) -> Bool {
  self.map.contains(key)
}

///|
fn main {
  // Create a cache that holds up to 3 items
  let cache : LRUCache[String] = LRUCache::new(capacity=3)

  cache.put("a", "alpha")
  cache.put("b", "beta")
  cache.put("c", "gamma")
  println("Cache size: \{cache.len()}") // 3

  // Access "a" — moves it to the end (most recently used)
  cache.get("a") |> ignore

  // Insert "d" — evicts "b" (now the least recently used, at position 0)
  cache.put("d", "delta")

  println("Contains a: \{cache.contains("a")}") // true
  println("Contains b: \{cache.contains("b")}") // false (evicted)
  println("Contains c: \{cache.contains("c")}") // true
  println("Contains d: \{cache.contains("d")}") // true

  // Iterate in LRU order (least → most recently used)
  println("=== Cache contents (LRU order) ===")
  let iter = cache.map.iter()
  while true {
    match iter.next() {
      Some((k, v)) => println("\{k} => \{v}")
      None => break
    }
  }
  // Output: c => gamma, a => alpha, d => delta
}
