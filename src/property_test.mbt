// Property-based tests for IndexMap and IndexSet.
// These tests verify invariants that should hold for arbitrary inputs.

///|
test "property: insert N keys gives len N" {
  let map = @aurasuisui/indexmap.new()
  let mut i = 0
  while i < 50 {
    map.insert(i, i * 10) |> ignore
    i = i + 1
  }
  debug_inspect(map.len(), content="50")
}

///|
test "property: insert twice same key preserves len" {
  let map = @aurasuisui/indexmap.new()
  map.insert("key", 1) |> ignore
  map.insert("key", 2) |> ignore
  debug_inspect(map.len(), content="1")
}

///|
test "property: insert get roundtrip" {
  let map = @aurasuisui/indexmap.new()
  let mut i = 0
  while i < 100 {
    map.insert(i, i * 7) |> ignore
    i = i + 1
  }
  let mut j = 0
  while j < 100 {
    match map.get(j) {
      Some(v) => debug_inspect(v, content="\{j * 7}")
      None => @test.fail("missing key in roundtrip")
    }
    j = j + 1
  }
}

///|
test "property: remove reduces len by 1" {
  let map = @aurasuisui/indexmap.new()
  let mut i = 0
  while i < 100 {
    map.insert(i, i) |> ignore
    i = i + 1
  }
  map.remove(50) |> ignore
  debug_inspect(map.len(), content="99")
}

///|
test "property: removed key not found" {
  let map = @aurasuisui/indexmap.new()
  let mut i = 0
  while i < 50 {
    map.insert(i, i) |> ignore
    i = i + 1
  }
  map.remove(25) |> ignore
  debug_inspect(map.contains(25), content="false")
}

///|
test "property: iteration count equals len" {
  let map = @aurasuisui/indexmap.new()
  let mut i = 0
  while i < 75 {
    map.insert(i, i * 2) |> ignore
    i = i + 1
  }
  let iter = map.iter()
  let mut count = 0
  while true {
    match iter.next() {
      Some(_) => count = count + 1
      None => break
    }
  }
  debug_inspect(count, content="75")
}

///|
test "property: deleted key not in iteration" {
  let map = @aurasuisui/indexmap.new()
  map.insert("a", 1) |> ignore
  map.insert("b", 2) |> ignore
  map.insert("c", 3) |> ignore
  map.remove("b") |> ignore
  let iter = map.iter()
  while true {
    match iter.next() {
      Some((k, _)) => debug_inspect(k == "b", content="false")
      None => break
    }
  }
}

///|
test "property: clear makes len zero" {
  let map = @aurasuisui/indexmap.new()
  let mut i = 0
  while i < 100 {
    map.insert(i, i) |> ignore
    i = i + 1
  }
  map.clear()
  debug_inspect(map.len(), content="0")
  debug_inspect(map.is_empty(), content="true")
}

///|
test "property: contains matches get" {
  let map = @aurasuisui/indexmap.new()
  map.insert("exists", 42) |> ignore
  debug_inspect(map.contains("exists"), content="true")
  debug_inspect(map.contains("missing"), content="false")
  match map.get("exists") {
    Some(_) => ()
    None => @test.fail("contains true but get returned None")
  }
}

///|
test "property: extend N entries yields len N" {
  let map = @aurasuisui/indexmap.new()
  let entries = []
  let mut i = 0
  while i < 30 {
    entries.push((i, i * 3))
    i = i + 1
  }
  map.extend_from_array(entries)
  debug_inspect(map.len(), content="30")
}

///|
test "property: drain empties map" {
  let map = @aurasuisui/indexmap.new()
  let mut i = 0
  while i < 50 {
    map.insert(i, i) |> ignore
    i = i + 1
  }
  let drained = map.drain()
  debug_inspect(drained.length(), content="50")
  debug_inspect(map.is_empty(), content="true")
}

///|
test "property: retain all keeps all" {
  let map = @aurasuisui/indexmap.new()
  let mut i = 0
  while i < 100 {
    map.insert(i, i) |> ignore
    i = i + 1
  }
  map.retain(fn(_k, _v) { true })
  debug_inspect(map.len(), content="100")
}

///|
test "property: retain none removes all" {
  let map = @aurasuisui/indexmap.new()
  let mut i = 0
  while i < 100 {
    map.insert(i, i) |> ignore
    i = i + 1
  }
  map.retain(fn(_k, _v) { false })
  debug_inspect(map.is_empty(), content="true")
}

///|
test "property: keys iterator count equals len" {
  let map = @aurasuisui/indexmap.new()
  map.insert("a", 1) |> ignore
  map.insert("b", 2) |> ignore
  map.insert("c", 3) |> ignore
  let iter = map.keys()
  let mut count = 0
  while true {
    match iter.next() {
      Some(_) => count = count + 1
      None => break
    }
  }
  debug_inspect(count, content="3")
}

///|
test "property: values iterator count equals len" {
  let map = @aurasuisui/indexmap.new()
  map.insert("a", 1) |> ignore
  map.insert("b", 2) |> ignore
  map.insert("c", 3) |> ignore
  let iter = map.values()
  let mut count = 0
  while true {
    match iter.next() {
      Some(_) => count = count + 1
      None => break
    }
  }
  debug_inspect(count, content="3")
}

///|
test "property: insert preserves existing entries" {
  let map = @aurasuisui/indexmap.new()
  let mut i = 0
  while i < 50 {
    map.insert(i, i * 10) |> ignore
    i = i + 1
  }
  map.insert(25, 999) |> ignore
  debug_inspect(map.len(), content="50")
  debug_inspect(map.get(25), content="Some(999)")
  debug_inspect(map.get(0), content="Some(0)")
  debug_inspect(map.get(49), content="Some(490)")
}

///|
test "property: shrink_to_fit preserves data" {
  let map = @aurasuisui/indexmap.with_capacity(512)
  let mut i = 0
  while i < 20 {
    map.insert(i, i * 5) |> ignore
    i = i + 1
  }
  map.shrink_to_fit()
  let mut j = 0
  while j < 20 {
    debug_inspect(map.contains(j), content="true")
    j = j + 1
  }
}

///|
test "property: insert order equals iteration order" {
  let map = @aurasuisui/indexmap.new()
  let keys = ["z", "y", "x", "w", "v"]
  let mut i = 0
  while i < keys.length() {
    map.insert(keys[i], i) |> ignore
    i = i + 1
  }
  let iter = map.iter()
  let mut j = 0
  while true {
    match iter.next() {
      Some((k, v)) => {
        if k != keys[j] {
          @test.fail("key mismatch: expected " + keys[j] + " got " + k)
        }
        if v != j {
          @test.fail("value mismatch at " + j.to_string())
        }
        j = j + 1
      }
      None => break
    }
  }
  debug_inspect(j, content="5")
}

///|
test "property: swap_remove maintains len minus 1" {
  let map = @aurasuisui/indexmap.new()
  let mut i = 0
  while i < 100 {
    map.insert(i, i) |> ignore
    i = i + 1
  }
  map.swap_remove_index(50) |> ignore
  debug_inspect(map.len(), content="99")
}

///|
test "property: overwrite does not change len" {
  let map = @aurasuisui/indexmap.new()
  map.insert("a", 1) |> ignore
  map.insert("b", 2) |> ignore
  map.insert("c", 3) |> ignore
  let old = map.insert("b", 20)
  debug_inspect(old, content="Some(2)")
  debug_inspect(map.len(), content="3")
}

///|
test "property: pop on non-empty reduces len" {
  let map = @aurasuisui/indexmap.new()
  map.insert("a", 1) |> ignore
  map.insert("b", 2) |> ignore
  map.pop() |> ignore
  debug_inspect(map.len(), content="1")
}

///|
test "property: pop returns most recent" {
  let map = @aurasuisui/indexmap.new()
  map.insert("first", 1) |> ignore
  map.insert("second", 2) |> ignore
  let popped = map.pop()
  debug_inspect(
    popped,
    content=(
      #|Some(("second", 2))
    ),
  )
}

///|
test "property: from_array preserves input order" {
  let entries = [("c", 3), ("b", 2), ("a", 1)]
  let map = @aurasuisui/indexmap.IndexMap::from_array(entries)
  let collected = map.iter().collect()
  debug_inspect(
    collected[0],
    content=(
      #|("c", 3)
    ),
  )
  debug_inspect(
    collected[1],
    content=(
      #|("b", 2)
    ),
  )
  debug_inspect(
    collected[2],
    content=(
      #|("a", 1)
    ),
  )
}

///|
test "property: empty map has capacity 16" {
  let map : @aurasuisui/indexmap.IndexMap[String, Int] = @aurasuisui/indexmap.new()
  debug_inspect(map.capacity(), content="16")
  debug_inspect(map.len(), content="0")
  let lf = map.load_factor()
  debug_inspect(lf >= 0.0, content="true")
  debug_inspect(lf < 1.0, content="true")
}

///|
test "property: first equals get_index 0" {
  let map = @aurasuisui/indexmap.new()
  map.insert("x", 10) |> ignore
  map.insert("y", 20) |> ignore
  let f = map.first()
  let g = map.get_index(0)
  match (f, g) {
    (Some((fk, fv)), Some((gk, gv))) => {
      ignore(gk)
      debug_inspect(
        fk,
        content=(
          #|"x"
        ),
      )
      debug_inspect(fv, content="\{gv}")
    }
    _ => @test.fail("first and get_index(0) should match")
  }
}

///|
test "property: sort_by_key stable for sorted input" {
  let map = @aurasuisui/indexmap.new()
  let mut i = 0
  while i < 50 {
    map.insert(i, i) |> ignore
    i = i + 1
  }
  map.sort_by_key()
  let entries = map.iter().collect()
  let mut j = 0
  while j < 50 {
    debug_inspect(entries[j].0, content="\{j}")
    j = j + 1
  }
}

///|
test "property: IndexSet insert returns false on duplicate" {
  let set = @aurasuisui/indexmap.IndexSet::new()
  debug_inspect(set.insert("x"), content="true")
  debug_inspect(set.insert("x"), content="false")
}

///|
test "property: IndexSet len matches unique inserts" {
  let set = @aurasuisui/indexmap.IndexSet::new()
  set.insert("a") |> ignore
  set.insert("b") |> ignore
  set.insert("c") |> ignore
  set.insert("a") |> ignore
  set.insert("b") |> ignore
  debug_inspect(set.len(), content="3")
}

///|
test "property: IndexSet disjoint is symmetric" {
  let a = @aurasuisui/indexmap.IndexSet::new()
  a.insert(1) |> ignore
  a.insert(2) |> ignore
  let b = @aurasuisui/indexmap.IndexSet::new()
  b.insert(3) |> ignore
  b.insert(4) |> ignore
  debug_inspect(a.is_disjoint(b), content="true")
  debug_inspect(b.is_disjoint(a), content="true")
}

///|
test "property: IndexSet subset implies superset" {
  let a = @aurasuisui/indexmap.IndexSet::new()
  a.insert(1) |> ignore
  a.insert(2) |> ignore
  let b = @aurasuisui/indexmap.IndexSet::new()
  b.insert(1) |> ignore
  b.insert(2) |> ignore
  b.insert(3) |> ignore
  debug_inspect(a.is_subset(b), content="true")
  debug_inspect(b.is_superset(a), content="true")
}

///|
test "property: IndexSet empty is always subset" {
  let empty = @aurasuisui/indexmap.IndexSet::new()
  let set = @aurasuisui/indexmap.IndexSet::new()
  set.insert("x") |> ignore
  set.insert("y") |> ignore
  debug_inspect(empty.is_subset(set), content="true")
}

///|
test "property: IndexSet empty is always superset of empty" {
  let empty : @aurasuisui/indexmap.IndexSet[String] = @aurasuisui/indexmap.IndexSet::new()
  debug_inspect(empty.is_superset(empty), content="true")
}

///|
test "property: IndexSet iteration order matches insert" {
  let set = @aurasuisui/indexmap.IndexSet::new()
  set.insert("b") |> ignore
  set.insert("c") |> ignore
  set.insert("a") |> ignore
  let iter = set.iter()
  match iter.next() {
    Some(k) =>
      debug_inspect(
        k,
        content=(
          #|"b"
        ),
      )
    None => @test.fail("expected b")
  }
  match iter.next() {
    Some(k) =>
      debug_inspect(
        k,
        content=(
          #|"c"
        ),
      )
    None => @test.fail("expected c")
  }
  match iter.next() {
    Some(k) =>
      debug_inspect(
        k,
        content=(
          #|"a"
        ),
      )
    None => @test.fail("expected a")
  }
  debug_inspect(iter.next(), content="None")
}

///|
test "property: reserve on filled map preserves data" {
  let map = @aurasuisui/indexmap.new()
  let mut i = 0
  while i < 30 {
    map.insert(i, i * 2) |> ignore
    i = i + 1
  }
  let cap_before = map.capacity()
  map.reserve(2000)
  debug_inspect(map.capacity() > cap_before, content="true")
  let mut j = 0
  while j < 30 {
    debug_inspect(map.contains(j), content="true")
    j = j + 1
  }
}

///|
test "property: delete and reinsert same key" {
  let map = @aurasuisui/indexmap.new()
  map.insert("key", 1) |> ignore
  map.remove("key") |> ignore
  map.insert("key", 2) |> ignore
  debug_inspect(map.len(), content="1")
  debug_inspect(map.get("key"), content="Some(2)")
  // Should be at the end now
  map.insert("other", 3) |> ignore
  let entries = map.iter().collect()
  debug_inspect(
    entries[0],
    content=(
      #|("key", 2)
    ),
  )
  debug_inspect(
    entries[1],
    content=(
      #|("other", 3)
    ),
  )
}

///|
test "property: iter next reduces len by one each call" {
  let map = @aurasuisui/indexmap.new()
  map.insert("a", 1) |> ignore
  map.insert("b", 2) |> ignore
  map.insert("c", 3) |> ignore
  let iter = map.iter()
  let mut count = 0
  while true {
    match iter.next() {
      Some(_) => count = count + 1
      None => break
    }
  }
  debug_inspect(count, content="3")
}

///|
test "property: is_empty consistent with len" {
  let map = @aurasuisui/indexmap.new()
  debug_inspect(map.is_empty() == (map.len() == 0), content="true")
  map.insert("x", 1) |> ignore
  debug_inspect(map.is_empty() == (map.len() == 0), content="true")
}

// ---------------------------------------------------------------------------
// Property tests: O(1) swap-remove invariants (v0.2.0)
// ---------------------------------------------------------------------------

///|
test "property: get_index_of matches order array position" {
  let map = @aurasuisui/indexmap.new()
  let keys = ["z", "y", "x", "w", "v", "u"]
  let mut i = 0
  while i < keys.length() {
    map.insert(keys[i], i) |> ignore
    i = i + 1
  }
  // Verify every key's index matches its insertion-order position
  let mut j = 0
  while j < keys.length() {
    match map.get_index_of(keys[j]) {
      Some(pos) => debug_inspect(pos, content="\{j}")
      None => @test.fail("key should have a position")
    }
    j = j + 1
  }
}

///|
test "property: remove from front preserves remaining order" {
  let map = @aurasuisui/indexmap.new()
  let mut i = 0
  while i < 10 {
    map.insert(i, i * 10) |> ignore
    i = i + 1
  }
  // Remove first 5 elements
  let mut j = 0
  while j < 5 {
    map.remove(j) |> ignore
    j = j + 1
  }
  debug_inspect(map.len(), content="5")
  // Remaining should be 5,6,7,8,9 in order
  let entries = map.iter().collect()
  let mut k = 0
  while k < 5 {
    debug_inspect(entries[k].0, content="\{k + 5}")
    k = k + 1
  }
}

///|
test "property: remove from back preserves front order" {
  let map = @aurasuisui/indexmap.new()
  let mut i = 0
  while i < 10 {
    map.insert(i, i * 10) |> ignore
    i = i + 1
  }
  // Remove last 5 elements
  let mut j = 9
  while j >= 5 {
    map.remove(j) |> ignore
    j = j - 1
  }
  debug_inspect(map.len(), content="5")
  let entries = map.iter().collect()
  let mut k = 0
  while k < 5 {
    debug_inspect(entries[k].0, content="\{k}")
    k = k + 1
  }
}

///|
test "property: remove from middle preserves edge order" {
  let map = @aurasuisui/indexmap.new()
  map.insert("a", 1) |> ignore
  map.insert("b", 2) |> ignore
  map.insert("c", 3) |> ignore
  map.insert("d", 4) |> ignore
  map.insert("e", 5) |> ignore
  map.remove("c") |> ignore
  // Order should be a, b, d, e
  let entries = map.iter().collect()
  debug_inspect(
    entries[0],
    content=(
      #|("a", 1)
    ),
  )
  debug_inspect(
    entries[1],
    content=(
      #|("b", 2)
    ),
  )
  debug_inspect(
    entries[2],
    content=(
      #|("d", 4)
    ),
  )
  debug_inspect(
    entries[3],
    content=(
      #|("e", 5)
    ),
  )
}

///|
test "property: remove all in random order leaves empty" {
  let map = @aurasuisui/indexmap.new()
  let mut i = 0
  while i < 100 {
    map.insert(i, i) |> ignore
    i = i + 1
  }
  // Remove in reverse order
  let mut j = 99
  while j >= 0 {
    map.remove(j) |> ignore
    j = j - 1
  }
  debug_inspect(map.is_empty(), content="true")
  debug_inspect(map.len(), content="0")
}

///|
test "property: swap_remove_index is order-preserving shift-remove" {
  let map = @aurasuisui/indexmap.new()
  map.insert("a", 1) |> ignore
  map.insert("b", 2) |> ignore
  map.insert("c", 3) |> ignore
  map.insert("d", 4) |> ignore
  // Remove index 1 ("b"). This is a shift-remove: survivors keep their relative
  // order (a, c, d); a true swap-with-last would yield (a, d, c).
  map.swap_remove_index(1) |> ignore
  debug_inspect(map.len(), content="3")
  debug_inspect(
    map.keys().collect(),
    content=(
      #|["a", "c", "d"]
    ),
  )
}

///|
test "property: reinsert removed key goes to end" {
  let map = @aurasuisui/indexmap.new()
  map.insert("a", 1) |> ignore
  map.insert("b", 2) |> ignore
  map.insert("c", 3) |> ignore
  map.remove("a") |> ignore
  map.insert("a", 10) |> ignore
  // "a" should now be at the end
  let entries = map.iter().collect()
  debug_inspect(
    entries[0],
    content=(
      #|("b", 2)
    ),
  )
  debug_inspect(
    entries[1],
    content=(
      #|("c", 3)
    ),
  )
  debug_inspect(
    entries[2],
    content=(
      #|("a", 10)
    ),
  )
}

///|
test "property: get_index_of returns none for removed key" {
  let map = @aurasuisui/indexmap.new()
  map.insert("x", 1) |> ignore
  map.insert("y", 2) |> ignore
  map.remove("x") |> ignore
  debug_inspect(map.get_index_of("x"), content="None")
  debug_inspect(map.get_index_of("y"), content="Some(0)")
}

///|
test "property: mixed insert remove sequence" {
  let map = @aurasuisui/indexmap.new()
  // Insert 50
  let mut i = 0
  while i < 50 {
    map.insert(i, i) |> ignore
    i = i + 1
  }
  // Remove evens
  let mut j = 0
  while j < 50 {
    if j % 2 == 0 {
      map.remove(j) |> ignore
    }
    j = j + 1
  }
  debug_inspect(map.len(), content="25")
  // Re-insert some evens
  map.insert(0, 999) |> ignore
  map.insert(10, 999) |> ignore
  debug_inspect(map.len(), content="27")
  // Verify re-inserted keys are at end
  let entries = map.iter().collect()
  let last_two = (entries[25].0, entries[26].0)
  debug_inspect(last_two, content="(0, 10)")
}

///|
test "property: retain with swap-remove consistency" {
  let map = @aurasuisui/indexmap.new()
  let mut i = 0
  while i < 50 {
    map.insert(i, i) |> ignore
    i = i + 1
  }
  // Retain multiples of 5
  map.retain(fn(_k, v) { v % 5 == 0 })
  debug_inspect(map.len(), content="10")
  // Verify all remaining are multiples of 5
  let iter = map.iter()
  while true {
    match iter.next() {
      Some((_, v)) => debug_inspect(v % 5 == 0, content="true")
      None => break
    }
  }
  // Verify order: they should appear in original insertion order
  let entries = map.iter().collect()
  let mut prev = -1
  let mut j = 0
  while j < entries.length() {
    debug_inspect(entries[j].0 > prev, content="true")
    prev = entries[j].0
    j = j + 1
  }
}
