// Copyright (c) 2024-2026 moonbit-indexmap contributors
// SPDX-License-Identifier: Apache-2.0

// Model-based / stateful property tests + WHITE-BOX invariant checks
// (RELEASE_TEST_CHECKLIST Tier 1 "model / stateful property testing" and
// Tier 0 "invariant tests").
//
// `_wbtest.mbt` files compile as part of the package, so this file can both
// name the private `IndexMap` type in helper signatures AND read its private
// fields (`buckets`, `order`, `positions`, `mask`, `len`,
// `max_probe_distance`). That lets one driver do two things at once:
//
//   1. Drive the SAME operation sequence through the real `IndexMap` and a
//      naive `Array[(Int, Int)]` oracle, asserting exact content + order +
//      return values agree after EVERY step. This catches "internally
//      consistent but wrong survivor" bugs that pure self-consistency checks
//      cannot see (the force-multiplier the checklist stars).
//   2. Re-assert all eight CLAUDE.md internal invariants after every mutating
//      step, so a drifting counter / leaked bucket / bad mask is caught at the
//      exact op that introduced it.
//
// The oracle models THIS library's documented semantics, not Rust's:
//   - overwrite keeps the key's insertion position;
//   - `swap_remove_index` is an order-preserving SHIFT-remove (Rust swaps);
//   - `get_mut` is authoritative — `Some(v)` upserts, `None` deletes.

// ---------------------------------------------------------------------------
// The naive oracle: an Array[(Int, Int)] in insertion order
// ---------------------------------------------------------------------------

///|
/// Index of the pair whose key is `k`, or None.
fn oracle_index_of(arr : Array[(Int, Int)], k : Int) -> Int? {
  let mut i = 0
  while i < arr.length() {
    let (kk, _) = arr[i]
    if kk == k {
      return Some(i)
    }
    i = i + 1
  }
  None
}

///|
/// Shift-remove the element at index `i` (manual, to avoid depending on any
/// particular Array-removal API).
fn oracle_remove_at(arr : Array[(Int, Int)], i : Int) -> Unit {
  let mut k = i
  let last = arr.length() - 1
  while k < last {
    arr[k] = arr[k + 1]
    k = k + 1
  }
  arr.pop() |> ignore
}

///|
/// Model `insert`: overwrite-in-place (keep position) or append. Returns the
/// previous value, matching `IndexMap::insert`.
fn oracle_insert(arr : Array[(Int, Int)], k : Int, v : Int) -> Int? {
  match oracle_index_of(arr, k) {
    Some(i) => {
      let (_, old) = arr[i]
      arr[i] = (k, v)
      Some(old)
    }
    None => {
      arr.push((k, v))
      None
    }
  }
}

///|
/// Model `remove`: shift-remove, returning the value.
fn oracle_remove(arr : Array[(Int, Int)], k : Int) -> Int? {
  match oracle_index_of(arr, k) {
    Some(i) => {
      let (_, v) = arr[i]
      oracle_remove_at(arr, i)
      Some(v)
    }
    None => None
  }
}

///|
/// Model `get`.
fn oracle_get(arr : Array[(Int, Int)], k : Int) -> Int? {
  match oracle_index_of(arr, k) {
    Some(i) => {
      let (_, v) = arr[i]
      Some(v)
    }
    None => None
  }
}

///|
/// Model `contains`.
fn oracle_contains(arr : Array[(Int, Int)], k : Int) -> Bool {
  oracle_index_of(arr, k) is Some(_)
}

///|
/// Find a distinct Int whose hash maps to `home` for a table with `mask`.
/// Used to make deterministic collision and wraparound bucket tests without
/// relying on a particular concrete hash value.
fn int_key_for_home(start : Int, mask : Int, home : Int) -> Int {
  let mut key = start
  while (Hash::hash(key) & mask) != home {
    key = key + 1
  }
  key
}

///|
/// Model `get_index` (bounds-checked).
fn oracle_get_index(arr : Array[(Int, Int)], i : Int) -> (Int, Int)? {
  if i < 0 || i >= arr.length() {
    None
  } else {
    Some(arr[i])
  }
}

///|
/// Model `get_index_of`.
fn oracle_get_index_of(arr : Array[(Int, Int)], k : Int) -> Int? {
  oracle_index_of(arr, k)
}

///|
/// Model `pop` (remove and return the last entry).
fn oracle_pop(arr : Array[(Int, Int)]) -> (Int, Int)? {
  if arr.length() == 0 {
    None
  } else {
    let p = arr[arr.length() - 1]
    arr.pop() |> ignore
    Some(p)
  }
}

///|
/// Model `swap_remove_index`. This library's version is an order-preserving
/// SHIFT-remove (documented deviation from Rust's swap-with-last), so the
/// oracle shifts, preserving the survivors' relative order.
fn oracle_swap_remove_index(arr : Array[(Int, Int)], i : Int) -> (Int, Int)? {
  if i < 0 || i >= arr.length() {
    None
  } else {
    let p = arr[i]
    oracle_remove_at(arr, i)
    Some(p)
  }
}

///|
/// Model `first`.
fn oracle_first(arr : Array[(Int, Int)]) -> (Int, Int)? {
  if arr.length() == 0 {
    None
  } else {
    Some(arr[0])
  }
}

///|
/// Model `last`.
fn oracle_last(arr : Array[(Int, Int)]) -> (Int, Int)? {
  if arr.length() == 0 {
    None
  } else {
    Some(arr[arr.length() - 1])
  }
}

///|
/// Model `retain(fn(k, _) { k % 2 == 0 })` in place.
fn oracle_retain_even(arr : Array[(Int, Int)]) -> Unit {
  let mut w = 0
  let mut r = 0
  while r < arr.length() {
    let (k, v) = arr[r]
    if k % 2 == 0 {
      arr[w] = (k, v)
      w = w + 1
    }
    r = r + 1
  }
  while arr.length() > w {
    arr.pop() |> ignore
  }
}

///|
/// Model `sort_by_key` (ascending by key).
fn oracle_sort_by_key(arr : Array[(Int, Int)]) -> Unit {
  arr.sort_by(fn(a, b) { a.0.compare(b.0) })
}

// ---------------------------------------------------------------------------
// The shared Op vocabulary + interpreter (reused by the fuzz tests too)
// ---------------------------------------------------------------------------

///|
/// One operation in a model/fuzz stream. Deliberately excludes the global
/// destructive ops (`clear`, `drain`) so random streams reach deep states;
/// those are covered by hand-crafted golden tests below.
enum Op {
  Insert(Int, Int)
  Remove(Int)
  Get(Int)
  Contains(Int)
  GetIndex(Int)
  GetIndexOf(Int)
  Pop
  SwapRemoveIndex(Int)
  First
  Last
  GetMutSet(Int, Int)
  GetMutDelete(Int)
  RetainEven
  SortByKey
}

///|
/// Map a (selector, operand, operand) triple to a weighted `Op`. Insert/remove
/// dominate so the map reaches a non-trivial steady state; index ops use a
/// slightly wider range so out-of-bounds (None) paths are exercised too.
fn gen_op(sel : Int, a : Int, b : Int) -> Op {
  let k = a % 20
  let v = b % 100
  let idx = a % 25
  let s = sel % 100
  if s < 34 {
    Insert(k, v)
  } else if s < 54 {
    Remove(k)
  } else if s < 64 {
    Get(k)
  } else if s < 70 {
    Contains(k)
  } else if s < 76 {
    GetIndex(idx)
  } else if s < 82 {
    GetIndexOf(k)
  } else if s < 88 {
    Pop
  } else if s < 92 {
    SwapRemoveIndex(idx)
  } else if s < 94 {
    First
  } else if s < 96 {
    Last
  } else if s < 98 {
    GetMutSet(k, v)
  } else if s < 99 {
    GetMutDelete(k)
  } else {
    RetainEven
  }
}

///|
/// Assert the real map agrees with the oracle on exact ordered content + len.
/// Uses `iter().collect()` (non-destructive), NOT `into_array()` (which drains).
fn assert_matches_oracle(
  m : IndexMap[Int, Int],
  oracle : Array[(Int, Int)],
) -> Unit raise {
  @test.assert_eq(m.iter().collect(), oracle)
  @test.assert_eq(m.len(), oracle.length())
}

///|
/// Apply one op to BOTH the real map and the oracle, asserting return-value
/// equality for value-returning ops, then full-state equality.
fn apply_op(
  m : IndexMap[Int, Int],
  oracle : Array[(Int, Int)],
  op : Op,
) -> Unit raise {
  match op {
    Insert(k, v) => @test.assert_eq(m.insert(k, v), oracle_insert(oracle, k, v))
    Remove(k) => @test.assert_eq(m.remove(k), oracle_remove(oracle, k))
    Get(k) => @test.assert_eq(m.get(k), oracle_get(oracle, k))
    Contains(k) => @test.assert_eq(m.contains(k), oracle_contains(oracle, k))
    GetIndex(i) => @test.assert_eq(m.get_index(i), oracle_get_index(oracle, i))
    GetIndexOf(k) =>
      @test.assert_eq(m.get_index_of(k), oracle_get_index_of(oracle, k))
    Pop => @test.assert_eq(m.pop(), oracle_pop(oracle))
    SwapRemoveIndex(i) =>
      @test.assert_eq(
        m.swap_remove_index(i),
        oracle_swap_remove_index(oracle, i),
      )
    First => @test.assert_eq(m.first(), oracle_first(oracle))
    Last => @test.assert_eq(m.last(), oracle_last(oracle))
    GetMutSet(k, v) => {
      m.get_mut(k, fn(_) { Some(v) })
      oracle_insert(oracle, k, v) |> ignore
    }
    GetMutDelete(k) => {
      m.get_mut(k, fn(_) { None })
      oracle_remove(oracle, k) |> ignore
    }
    RetainEven => {
      m.retain(fn(k, _) { k % 2 == 0 })
      oracle_retain_even(oracle)
    }
    SortByKey => {
      m.sort_by_key()
      oracle_sort_by_key(oracle)
    }
  }
  assert_matches_oracle(m, oracle)
}

// ---------------------------------------------------------------------------
// White-box internal-invariant check (reads private fields)
// ---------------------------------------------------------------------------

///|
/// Assert every CLAUDE.md internal invariant of `m`:
///   order.length() == len;  positions.length() == len;
///   positions[order[i]] == i;  mask == buckets.length()-1;
///   buckets.length() is a power of two;  live buckets == len;
///   every stored distance equals its physical distance from the home bucket;
///   every probe path from home to entry is contiguous; no duplicate bucket key
///   exists; max_probe_distance >= max live distance; every bucket key is
///   tracked in positions.
fn check_internal_invariants(m : IndexMap[Int, Int]) -> Unit raise {
  // counters agree
  @test.assert_eq(m.order.length(), m.len)
  @test.assert_eq(m.positions.length(), m.len)
  // positions map is consistent with order
  let mut i = 0
  while i < m.order.length() {
    let key = m.order[i]
    @test.assert_eq(m.positions.get(key), Some(i))
    i = i + 1
  }
  // mask + power-of-two bucket layout
  let cap = m.buckets.length()
  @test.assert_eq(m.mask, cap - 1)
  @test.assert_eq(cap & (cap - 1), 0)
  // bucket-level accounting
  let mut b = 0
  let mut live = 0
  let mut max_d = 0
  let seen : Map[Int, Bool] = Map([])
  while b < cap {
    match m.buckets[b] {
      Some(e) => {
        live = live + 1
        @test.assert_eq(e.distance, (b - (e.hash & m.mask)) & m.mask)
        let mut probe = e.hash & m.mask
        let mut steps = 0
        while steps < e.distance {
          if m.buckets[probe] is None {
            @test.fail("live entry has a hole in its probe path")
          }
          probe = (probe + 1) & m.mask
          steps = steps + 1
        }
        if e.distance > max_d {
          max_d = e.distance
        }
        if m.positions.get(e.key) is None {
          @test.fail("live bucket entry key missing from positions")
        }
        if seen.get(e.key) is Some(_) {
          @test.fail("duplicate key appears in multiple buckets")
        }
        seen[e.key] = true
      }
      None => ()
    }
    b = b + 1
  }
  @test.assert_eq(live, m.len)
  @test.assert_eq(seen.length(), m.len)
  if m.max_probe_distance < max_d {
    @test.fail("max_probe_distance is below an actual live entry distance")
  }
}

// ---------------------------------------------------------------------------
// Hand-crafted golden sequences
// ---------------------------------------------------------------------------

///|
test "model: insert / overwrite / remove / lookups match the oracle step by step" {
  let m : IndexMap[Int, Int] = IndexMap::new()
  let oracle : Array[(Int, Int)] = []
  let ops = [
    Insert(1, 10),
    Insert(2, 20),
    Insert(3, 30),
    Insert(2, 99), // overwrite keeps position
    Remove(1),
    Insert(4, 40),
    Get(2),
    Get(1),
    Contains(3),
    Contains(1),
    GetIndex(0),
    GetIndex(99), // out of bounds
    GetIndex(-1), // negative
    GetIndexOf(3),
    GetIndexOf(1), // removed
    First,
    Last,
    Pop,
    SwapRemoveIndex(0),
  ]
  let mut i = 0
  while i < ops.length() {
    apply_op(m, oracle, ops[i])
    check_internal_invariants(m)
    i = i + 1
  }
}

///|
test "model: swap_remove_index is an order-preserving shift-remove (not a swap)" {
  let m : IndexMap[Int, Int] = IndexMap::new()
  let oracle : Array[(Int, Int)] = []
  apply_op(m, oracle, Insert(1, 10))
  apply_op(m, oracle, Insert(2, 20))
  apply_op(m, oracle, Insert(3, 30))
  apply_op(m, oracle, Insert(4, 40))
  // removing index 0 must leave [2,3,4] in order — a swap would leave [4,2,3].
  apply_op(m, oracle, SwapRemoveIndex(0))
  @test.assert_eq(m.iter().collect(), [(2, 20), (3, 30), (4, 40)])
  check_internal_invariants(m)
}

///|
test "model: get_mut is authoritative (Some upserts, None deletes) vs the oracle" {
  let m : IndexMap[Int, Int] = IndexMap::new()
  let oracle : Array[(Int, Int)] = []
  apply_op(m, oracle, Insert(1, 10))
  apply_op(m, oracle, Insert(2, 20))
  apply_op(m, oracle, GetMutSet(2, 200)) // upsert existing (keeps position)
  apply_op(m, oracle, GetMutSet(3, 30)) // upsert absent (appends)
  apply_op(m, oracle, GetMutDelete(1)) // delete
  apply_op(m, oracle, GetMutDelete(99)) // delete absent (no-op)
  @test.assert_eq(m.iter().collect(), [(2, 200), (3, 30)])
  check_internal_invariants(m)
}

///|
test "model: sort_by_key reorders the map and the oracle identically" {
  let m : IndexMap[Int, Int] = IndexMap::new()
  let oracle : Array[(Int, Int)] = []
  apply_op(m, oracle, Insert(3, 30))
  apply_op(m, oracle, Insert(1, 10))
  apply_op(m, oracle, Insert(2, 20))
  apply_op(m, oracle, SortByKey)
  @test.assert_eq(m.iter().collect(), [(1, 10), (2, 20), (3, 30)])
  // sort must recalc max_probe so the field still reflects the live buckets
  check_internal_invariants(m)
}

///|
test "model: retain keeps matching entries in order, matching the oracle" {
  let m : IndexMap[Int, Int] = IndexMap::new()
  let oracle : Array[(Int, Int)] = []
  let mut i = 0
  while i < 10 {
    apply_op(m, oracle, Insert(i, i * 10))
    i = i + 1
  }
  apply_op(m, oracle, RetainEven)
  @test.assert_eq(m.iter().collect(), [
    (0, 0),
    (2, 20),
    (4, 40),
    (6, 60),
    (8, 80),
  ])
  check_internal_invariants(m)
}

///|
test "model: drain returns insertion-order contents and empties the map" {
  let m : IndexMap[Int, Int] = IndexMap::new()
  m.insert(1, 10) |> ignore
  m.insert(2, 20) |> ignore
  m.insert(3, 30) |> ignore
  m.remove(2) |> ignore
  let drained = m.drain()
  @test.assert_eq(drained, [(1, 10), (3, 30)])
  @test.assert_eq(m.len(), 0)
  check_internal_invariants(m)
}

///|
test "model: entry API (occupied/vacant) agrees with the oracle" {
  let m : IndexMap[Int, Int] = IndexMap::new()
  let oracle : Array[(Int, Int)] = []
  apply_op(m, oracle, Insert(1, 10))
  // vacant insert appends
  match m.entry(2) {
    Occupied(_) => @test.fail("expected a vacant entry for key 2")
    Vacant(e) => e.insert(20) |> ignore
  }
  oracle_insert(oracle, 2, 20) |> ignore
  assert_matches_oracle(m, oracle)
  // occupied insert overwrites in place
  match m.entry(1) {
    Occupied(e) => e.insert(100) |> ignore
    Vacant(_) => @test.fail("expected an occupied entry for key 1")
  }
  oracle_insert(oracle, 1, 100) |> ignore
  assert_matches_oracle(m, oracle)
  // occupied remove shift-removes
  match m.entry(1) {
    Occupied(e) => e.remove() |> ignore
    Vacant(_) => @test.fail("expected an occupied entry for key 1")
  }
  oracle_remove(oracle, 1) |> ignore
  assert_matches_oracle(m, oracle)
  check_internal_invariants(m)
}

// ---------------------------------------------------------------------------
// Randomized differential streams (step-by-step agreement + invariants)
// ---------------------------------------------------------------------------

///|
test "model: 8000 deterministic mixed ops agree with the oracle and keep all invariants" {
  let m : IndexMap[Int, Int] = IndexMap::new()
  let oracle : Array[(Int, Int)] = []
  let mut state = 0x1234_5678
  let mut i = 0
  while i < 8000 {
    // LCG for reproducibility; tiny keyspace (mod 20) forces constant
    // overwrites / removals / index churn.
    state = (state * 1103515245 + 12345) & 0x7FFF_FFFF
    let op = gen_op(state, state >> 6, state >> 14)
    apply_op(m, oracle, op)
    check_internal_invariants(m)
    i = i + 1
  }
}

///|
test "model: insert-heavy large-keyspace stream crosses resizes with invariants intact" {
  let m : IndexMap[Int, Int] = IndexMap::new()
  let oracle : Array[(Int, Int)] = []
  let mut state = 0x5678_1234
  let mut i = 0
  while i < 5000 {
    state = (state * 1103515245 + 12345) & 0x7FFF_FFFF
    let k = (state >> 6) % 500
    let v = (state >> 14) % 1000
    let r = state % 10
    let op = if r < 7 {
      Insert(k, v)
    } else if r < 9 {
      Remove(k)
    } else {
      Get(k)
    }
    apply_op(m, oracle, op)
    if i % 50 == 0 {
      check_internal_invariants(m)
    }
    i = i + 1
  }
  check_internal_invariants(m)
  if m.capacity() <= 16 {
    @test.fail("expected the insert-heavy stream to resize past 16 buckets")
  }
}

///|
test "model/qc: random op sequences agree with the oracle and keep invariants" {
  let cases : Array[Array[(Int, Int)]] = @quickcheck.samples(80)
  let mut c = 0
  while c < cases.length() {
    let pairs = cases[c]
    let m : IndexMap[Int, Int] = IndexMap::new()
    let oracle : Array[(Int, Int)] = []
    let mut i = 0
    while i < pairs.length() {
      let (a, b) = pairs[i]
      let op = gen_op(a, a >> 3, b)
      apply_op(m, oracle, op)
      i = i + 1
    }
    check_internal_invariants(m)
    c = c + 1
  }
}

// ---------------------------------------------------------------------------
// Targeted white-box invariant tests (each invariant in isolation)
// ---------------------------------------------------------------------------

///|
test "wb: invariants hold on an empty map" {
  let m : IndexMap[String, Int] = IndexMap::new()
  @test.assert_eq(m.order.length(), 0)
  @test.assert_eq(m.positions.length(), 0)
  @test.assert_eq(m.buckets.length(), 16)
  @test.assert_eq(m.mask, 15)
  @test.assert_eq(m.max_probe_distance, 0)
}

///|
test "wb: removal compacts clusters and preserves every invariant" {
  let m : IndexMap[Int, Int] = IndexMap::new()
  let mut i = 0
  while i < 20 {
    m.insert(i, i + 100) |> ignore
    i = i + 1
  }
  check_internal_invariants(m)
  // Remove half while validating that no vacant bucket is left in a cluster.
  let mut j = 0
  while j < 20 {
    if j % 2 == 0 {
      m.remove(j) |> ignore
    }
    check_internal_invariants(m)
    j = j + 1
  }
  @test.assert_eq(m.len, 10)
}

///|
test "wb: repeated delete and refill keeps capacity stable without cleanup rehash" {
  let m : IndexMap[Int, Int] = IndexMap::new()
  let mut i = 0
  while i < 50 {
    m.insert(i, i) |> ignore
    i = i + 1
  }
  let cap_before = m.capacity()
  let mut j = 0
  while j < 40 {
    m.remove(j) |> ignore
    check_internal_invariants(m)
    j = j + 1
  }
  @test.assert_eq(m.len, 10)
  let mut k = 50
  while k < 90 {
    m.insert(k, k) |> ignore
    check_internal_invariants(m)
    k = k + 1
  }
  @test.assert_eq(m.capacity(), cap_before)
  @test.assert_eq(m.len, 50)
}

///|
test "wb: deletion backshifts a cluster across the mask boundary" {
  let m : IndexMap[Int, Int] = IndexMap::with_capacity(16)
  let a = int_key_for_home(0, 15, 14)
  let b = int_key_for_home(a + 1, 15, 14)
  let c = int_key_for_home(b + 1, 15, 14)
  m.insert(a, 10) |> ignore
  m.insert(b, 20) |> ignore
  m.insert(c, 30) |> ignore
  match m.buckets[0] {
    Some(e) => {
      @test.assert_eq(e.key, c)
      @test.assert_eq(e.distance, 2)
    }
    None => @test.fail("expected the collision cluster to wrap at bucket zero")
  }
  @test.assert_eq(m.remove(b), Some(20))
  match m.buckets[15] {
    Some(e) => {
      @test.assert_eq(e.key, c)
      @test.assert_eq(e.distance, 1)
    }
    None =>
      @test.fail("expected the displaced entry to backshift into bucket 15")
  }
  match m.buckets[0] {
    None => ()
    Some(_) =>
      @test.fail("bucket zero should be empty after backshift compaction")
  }
  check_internal_invariants(m)
}

///|
test "wb: locate updates an existing key beyond a malformed distance drop" {
  // This intentionally constructs the historical 1 -> 0 -> 2 distance shape.
  // Normal operations can no longer create it, but `locate` must still scan to
  // the empty bucket so a future invariant regression cannot duplicate `b`.
  let m : IndexMap[Int, Int] = IndexMap::with_capacity(16)
  let anchor = int_key_for_home(0, 15, 3)
  let a = int_key_for_home(anchor + 1, 15, 3)
  let c = int_key_for_home(a + 1, 15, 5)
  let b = int_key_for_home(c + 1, 15, 4)
  m.buckets = Array::make(16, None)
  m.order = [anchor, a, c, b]
  m.positions = Map([])
  m.positions[anchor] = 0
  m.positions[a] = 1
  m.positions[c] = 2
  m.positions[b] = 3
  m.len = 4
  m.mask = 15
  m.max_probe_distance = 2
  m.buckets[3] = Some({
    key: anchor,
    value: 5,
    hash: Hash::hash(anchor),
    distance: 0,
  })
  m.buckets[4] = Some({ key: a, value: 10, hash: Hash::hash(a), distance: 1 })
  m.buckets[5] = Some({ key: c, value: 20, hash: Hash::hash(c), distance: 0 })
  m.buckets[6] = Some({ key: b, value: 30, hash: Hash::hash(b), distance: 2 })
  @test.assert_eq(m.insert(b, 99), Some(30))
  @test.assert_eq(m.len(), 4)
  @test.assert_eq(m.get(b), Some(99))
  @test.assert_eq(m.iter().collect(), [(anchor, 5), (a, 10), (c, 20), (b, 99)])
}

///|
test "wb: max_probe_distance exactly reflects the buckets right after a rehash" {
  let m : IndexMap[Int, Int] = IndexMap::new()
  let mut i = 0
  while i < 100 {
    m.insert(i, i * 3) |> ignore
    i = i + 1
  }
  // A resize just recomputed max_probe exactly; recompute it independently and
  // require equality here (stronger than the >= invariant that holds in general).
  let mut max_d = 0
  let mut b = 0
  while b < m.buckets.length() {
    match m.buckets[b] {
      Some(e) => if e.distance > max_d { max_d = e.distance }
      None => ()
    }
    b = b + 1
  }
  @test.assert_eq(m.max_probe_distance, max_d)
}

///|
test "wb: capacity grows through the 16->32->64... cascade under insert load" {
  let m : IndexMap[Int, Int] = IndexMap::new()
  @test.assert_eq(m.buckets.length(), 16)
  let mut i = 0
  let mut prev_cap = 16
  while i < 1000 {
    m.insert(i, i) |> ignore
    let cap = m.buckets.length()
    // capacity only ever doubles (power-of-two cascade), never shrinks on insert
    if cap != prev_cap {
      @test.assert_eq(cap, prev_cap * 2)
      prev_cap = cap
    }
    check_internal_invariants(m)
    i = i + 1
  }
  if m.buckets.length() <= 16 {
    @test.fail("expected growth past 16 buckets")
  }
}
