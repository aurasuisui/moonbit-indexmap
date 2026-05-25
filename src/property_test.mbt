// Property-based tests for IndexMap and IndexSet.
// These tests verify invariants that should hold for arbitrary inputs.

///|
test "property: insert N keys gives len N" {
  let map = @indexmap.new()
  let mut i = 0
  while i < 50 {
    map.insert(i, i * 10) |> ignore
    i = i + 1
  }
  inspect(map.len(), content="50")
}

///|
test "property: insert twice same key preserves len" {
  let map = @indexmap.new()
  map.insert("key", 1) |> ignore
  map.insert("key", 2) |> ignore
  inspect(map.len(), content="1")
}

///|
test "property: insert get roundtrip" {
  let map = @indexmap.new()
  let mut i = 0
  while i < 100 {
    map.insert(i, i * 7) |> ignore
    i = i + 1
  }
  let mut j = 0
  while j < 100 {
    match map.get(j) {
      Some(v) => inspect(v, content="\{j * 7}")
      None => @test.fail("missing key in roundtrip")
    }
    j = j + 1
  }
}

///|
test "property: remove reduces len by 1" {
  let map = @indexmap.new()
  let mut i = 0
  while i < 100 {
    map.insert(i, i) |> ignore
    i = i + 1
  }
  let before = map.len()
  map.remove(50) |> ignore
  inspect(map.len(), content="99")
}

///|
test "property: removed key not found" {
  let map = @indexmap.new()
  let mut i = 0
  while i < 50 {
    map.insert(i, i) |> ignore
    i = i + 1
  }
  map.remove(25) |> ignore
  inspect(map.contains(25), content="false")
}

///|
test "property: iteration count equals len" {
  let map = @indexmap.new()
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
  inspect(count, content="75")
}

///|
test "property: deleted key not in iteration" {
  let map = @indexmap.new()
  map.insert("a", 1) |> ignore
  map.insert("b", 2) |> ignore
  map.insert("c", 3) |> ignore
  map.remove("b") |> ignore
  let iter = map.iter()
  while true {
    match iter.next() {
      Some((k, _)) => inspect(k == "b", content="false")
      None => break
    }
  }
}

///|
test "property: clear makes len zero" {
  let map = @indexmap.new()
  let mut i = 0
  while i < 100 {
    map.insert(i, i) |> ignore
    i = i + 1
  }
  map.clear()
  inspect(map.len(), content="0")
  inspect(map.is_empty(), content="true")
}

///|
test "property: contains matches get" {
  let map = @indexmap.new()
  map.insert("exists", 42) |> ignore
  inspect(map.contains("exists"), content="true")
  inspect(map.contains("missing"), content="false")
  match map.get("exists") {
    Some(_) => ()
    None => @test.fail("contains true but get returned None")
  }
}

///|
test "property: extend N entries yields len N" {
  let map = @indexmap.new()
  let entries = []
  let mut i = 0
  while i < 30 {
    entries.push((i, i * 3))
    i = i + 1
  }
  map.extend(entries)
  inspect(map.len(), content="30")
}

///|
test "property: drain empties map" {
  let map = @indexmap.new()
  let mut i = 0
  while i < 50 {
    map.insert(i, i) |> ignore
    i = i + 1
  }
  let drained = map.drain()
  inspect(drained.length(), content="50")
  inspect(map.is_empty(), content="true")
}

///|
test "property: retain all keeps all" {
  let map = @indexmap.new()
  let mut i = 0
  while i < 100 {
    map.insert(i, i) |> ignore
    i = i + 1
  }
  map.retain(fn(_k, _v) { true })
  inspect(map.len(), content="100")
}

///|
test "property: retain none removes all" {
  let map = @indexmap.new()
  let mut i = 0
  while i < 100 {
    map.insert(i, i) |> ignore
    i = i + 1
  }
  map.retain(fn(_k, _v) { false })
  inspect(map.is_empty(), content="true")
}

///|
test "property: keys iterator count equals len" {
  let map = @indexmap.new()
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
  inspect(count, content="3")
}

///|
test "property: values iterator count equals len" {
  let map = @indexmap.new()
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
  inspect(count, content="3")
}

///|
test "property: insert preserves existing entries" {
  let map = @indexmap.new()
  let mut i = 0
  while i < 50 {
    map.insert(i, i * 10) |> ignore
    i = i + 1
  }
  map.insert(25, 999) |> ignore
  inspect(map.len(), content="50")
  inspect(map.get(25), content="Some(999)")
  inspect(map.get(0), content="Some(0)")
  inspect(map.get(49), content="Some(490)")
}

///|
test "property: shrink_to_fit preserves data" {
  let map = @indexmap.with_capacity(512)
  let mut i = 0
  while i < 20 {
    map.insert(i, i * 5) |> ignore
    i = i + 1
  }
  map.shrink_to_fit()
  let mut j = 0
  while j < 20 {
    inspect(map.contains(j), content="true")
    j = j + 1
  }
}

///|
test "property: insert order equals iteration order" {
  let map = @indexmap.new()
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
        inspect(k, content=keys[j])
        inspect(v, content="\{j}")
        j = j + 1
      }
      None => break
    }
  }
  inspect(j, content="5")
}

///|
test "property: swap_remove maintains len minus 1" {
  let map = @indexmap.new()
  let mut i = 0
  while i < 100 {
    map.insert(i, i) |> ignore
    i = i + 1
  }
  let before = map.len()
  map.swap_remove_index(50) |> ignore
  inspect(map.len(), content="99")
}

///|
test "property: overwrite does not change len" {
  let map = @indexmap.new()
  map.insert("a", 1) |> ignore
  map.insert("b", 2) |> ignore
  map.insert("c", 3) |> ignore
  let old = map.insert("b", 20)
  inspect(old, content="Some(2)")
  inspect(map.len(), content="3")
}

///|
test "property: pop on non-empty reduces len" {
  let map = @indexmap.new()
  map.insert("a", 1) |> ignore
  map.insert("b", 2) |> ignore
  map.pop() |> ignore
  inspect(map.len(), content="1")
}

///|
test "property: pop returns most recent" {
  let map = @indexmap.new()
  map.insert("first", 1) |> ignore
  map.insert("second", 2) |> ignore
  let popped = map.pop()
  inspect(popped, content="Some((second, 2))")
}

///|
test "property: from_array preserves input order" {
  let entries = [("c", 3), ("b", 2), ("a", 1)]
  let map = @indexmap.IndexMap::from_array(entries)
  let collected = map.iter().collect()
  inspect(collected[0], content="(c, 3)")
  inspect(collected[1], content="(b, 2)")
  inspect(collected[2], content="(a, 1)")
}

///|
test "property: empty map has capacity 16" {
  let map = @indexmap.new()
  inspect(map.capacity(), content="16")
  inspect(map.len(), content="0")
  let lf = map.load_factor()
  inspect(lf >= 0.0, content="true")
  inspect(lf < 1.0, content="true")
}

///|
test "property: first equals get_index 0" {
  let map = @indexmap.new()
  map.insert("x", 10) |> ignore
  map.insert("y", 20) |> ignore
  let f = map.first()
  let g = map.get_index(0)
  match (f, g) {
    (Some((fk, fv)), Some((gk, gv))) => {
      inspect(fk, content=gk)
      inspect(fv, content="\{gv}")
    }
    _ => @test.fail("first and get_index(0) should match")
  }
}

///|
test "property: sort_by_key stable for sorted input" {
  let map = @indexmap.new()
  let mut i = 0
  while i < 50 {
    map.insert(i, i) |> ignore
    i = i + 1
  }
  map.sort_by_key()
  let entries = map.iter().collect()
  let mut j = 0
  while j < 50 {
    inspect(entries[j].0, content="\{j}")
    j = j + 1
  }
}

///|
test "property: IndexSet insert returns false on duplicate" {
  let set = @indexmap.IndexSet::new()
  inspect(set.insert("x"), content="true")
  inspect(set.insert("x"), content="false")
}

///|
test "property: IndexSet len matches unique inserts" {
  let set = @indexmap.IndexSet::new()
  set.insert("a") |> ignore
  set.insert("b") |> ignore
  set.insert("c") |> ignore
  set.insert("a") |> ignore
  set.insert("b") |> ignore
  inspect(set.len(), content="3")
}

///|
test "property: IndexSet disjoint is symmetric" {
  let a = @indexmap.IndexSet::new()
  a.insert(1) |> ignore
  a.insert(2) |> ignore
  let b = @indexmap.IndexSet::new()
  b.insert(3) |> ignore
  b.insert(4) |> ignore
  inspect(a.is_disjoint(b), content="true")
  inspect(b.is_disjoint(a), content="true")
}

///|
test "property: IndexSet subset implies superset" {
  let a = @indexmap.IndexSet::new()
  a.insert(1) |> ignore
  a.insert(2) |> ignore
  let b = @indexmap.IndexSet::new()
  b.insert(1) |> ignore
  b.insert(2) |> ignore
  b.insert(3) |> ignore
  inspect(a.is_subset(b), content="true")
  inspect(b.is_superset(a), content="true")
}

///|
test "property: IndexSet empty is always subset" {
  let empty = @indexmap.IndexSet::new()
  let set = @indexmap.IndexSet::new()
  set.insert("x") |> ignore
  set.insert("y") |> ignore
  inspect(empty.is_subset(set), content="true")
}

///|
test "property: IndexSet empty is always superset of empty" {
  let empty = @indexmap.IndexSet::new()
  inspect(empty.is_superset(empty), content="true")
}

///|
test "property: IndexSet iteration order matches insert" {
  let set = @indexmap.IndexSet::new()
  set.insert("b") |> ignore
  set.insert("c") |> ignore
  set.insert("a") |> ignore
  let iter = set.iter()
  match iter.next() {
    Some(k) => inspect(k, content="b")
    None => @test.fail("expected b")
  }
  match iter.next() {
    Some(k) => inspect(k, content="c")
    None => @test.fail("expected c")
  }
  match iter.next() {
    Some(k) => inspect(k, content="a")
    None => @test.fail("expected a")
  }
  inspect(iter.next(), content="None")
}

///|
test "property: reserve on filled map preserves data" {
  let map = @indexmap.new()
  let mut i = 0
  while i < 30 {
    map.insert(i, i * 2) |> ignore
    i = i + 1
  }
  let cap_before = map.capacity()
  map.reserve(2000)
  inspect(map.capacity() > cap_before, content="true")
  let mut j = 0
  while j < 30 {
    inspect(map.contains(j), content="true")
    j = j + 1
  }
}

///|
test "property: delete and reinsert same key" {
  let map = @indexmap.new()
  map.insert("key", 1) |> ignore
  map.remove("key") |> ignore
  map.insert("key", 2) |> ignore
  inspect(map.len(), content="1")
  inspect(map.get("key"), content="Some(2)")
  // Should be at the end now
  map.insert("other", 3) |> ignore
  let entries = map.iter().collect()
  inspect(entries[0], content="(key, 2)")
  inspect(entries[1], content="(other, 3)")
}

///|
test "property: count_remaining decreases after next" {
  let map = @indexmap.new()
  map.insert("a", 1) |> ignore
  map.insert("b", 2) |> ignore
  let iter = map.iter()
  let before = iter.count_remaining()
  iter.next() |> ignore
  let after = iter.count_remaining()
  inspect(after, content="\{before - 1}")
}

///|
test "property: is_empty consistent with len" {
  let map = @indexmap.new()
  inspect(map.is_empty() == (map.len() == 0), content="true")
  map.insert("x", 1) |> ignore
  inspect(map.is_empty() == (map.len() == 0), content="true")
}
