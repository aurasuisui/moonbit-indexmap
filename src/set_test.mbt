// Blackbox tests for IndexSet — use @aurasuisui/indexmap to import public API.

///|
test "new set is empty" {
  let set = @aurasuisui/indexmap.IndexSet::new()
  inspect(set.len(), content="0")
  inspect(set.is_empty(), content="true")
}

///|
test "set insert and contains" {
  let set = @aurasuisui/indexmap.IndexSet::new()
  inspect(set.insert("a"), content="true")
  inspect(set.insert("a"), content="false")
  inspect(set.contains("a"), content="true")
  inspect(set.contains("b"), content="false")
  inspect(set.len(), content="1")
}

///|
test "set remove" {
  let set = @aurasuisui/indexmap.IndexSet::new()
  set.insert("a") |> ignore
  set.insert("b") |> ignore
  inspect(set.remove("a"), content="true")
  inspect(set.remove("a"), content="false")
  inspect(set.len(), content="1")
  inspect(set.contains("a"), content="false")
}

///|
test "set clear" {
  let set = @aurasuisui/indexmap.IndexSet::new()
  set.insert("a") |> ignore
  set.insert("b") |> ignore
  set.clear()
  inspect(set.len(), content="0")
}

///|
test "set disjoint" {
  let a = @aurasuisui/indexmap.IndexSet::new()
  a.insert("x") |> ignore
  a.insert("y") |> ignore
  let b = @aurasuisui/indexmap.IndexSet::new()
  b.insert("z") |> ignore
  b.insert("w") |> ignore
  inspect(a.is_disjoint(b), content="true")
  b.insert("x") |> ignore
  inspect(a.is_disjoint(b), content="false")
}

///|
test "set subset" {
  let a = @aurasuisui/indexmap.IndexSet::new()
  a.insert("x") |> ignore
  a.insert("y") |> ignore
  let b = @aurasuisui/indexmap.IndexSet::new()
  b.insert("x") |> ignore
  b.insert("y") |> ignore
  b.insert("z") |> ignore
  inspect(a.is_subset(b), content="true")
  inspect(b.is_subset(a), content="false")
}

///|
test "set superset" {
  let a = @aurasuisui/indexmap.IndexSet::new()
  a.insert("x") |> ignore
  a.insert("y") |> ignore
  a.insert("z") |> ignore
  let b = @aurasuisui/indexmap.IndexSet::new()
  b.insert("x") |> ignore
  b.insert("y") |> ignore
  inspect(a.is_superset(b), content="true")
  inspect(b.is_superset(a), content="false")
}

///|
test "set iteration order" {
  let set = @aurasuisui/indexmap.IndexSet::new()
  set.insert("c") |> ignore
  set.insert("a") |> ignore
  set.insert("b") |> ignore
  let iter = set.iter()
  match iter.next() {
    Some(k) => inspect(k, content="c")
    None => @test.fail("expected c")
  }
  match iter.next() {
    Some(k) => inspect(k, content="a")
    None => @test.fail("expected a")
  }
  match iter.next() {
    Some(k) => inspect(k, content="b")
    None => @test.fail("expected b")
  }
  inspect(iter.next(), content="None")
}

///|
test "set retain" {
  let set = @aurasuisui/indexmap.IndexSet::new()
  set.insert(1) |> ignore
  set.insert(2) |> ignore
  set.insert(3) |> ignore
  set.insert(4) |> ignore
  set.retain(fn(x) { x % 2 == 0 })
  inspect(set.len(), content="2")
  inspect(set.contains(2), content="true")
  inspect(set.contains(4), content="true")
  inspect(set.contains(1), content="false")
  inspect(set.contains(3), content="false")
}

///|
test "set large insert" {
  let set = @aurasuisui/indexmap.IndexSet::new()
  let mut i = 0
  while i < 500 {
    set.insert(i) |> ignore
    i = i + 1
  }
  inspect(set.len(), content="500")
  let mut j = 0
  while j < 500 {
    inspect(set.contains(j), content="true")
    j = j + 1
  }
}

///|
test "set capacity" {
  let set = @aurasuisui/indexmap.IndexSet::with_capacity(64)
  inspect(set.capacity(), content="64")
  inspect(set.is_empty(), content="true")
}

///|
test "set empty operations" {
  let a = @aurasuisui/indexmap.IndexSet::new()
  let b = @aurasuisui/indexmap.IndexSet::new()
  inspect(a.is_disjoint(b), content="true")
  inspect(a.is_subset(b), content="true")
  inspect(a.is_superset(b), content="true")
}

///|
test "set disjoint with self" {
  let set = @aurasuisui/indexmap.IndexSet::new()
  set.insert("x") |> ignore
  inspect(set.is_disjoint(set), content="false")
}

///|
test "set subset with self" {
  let set = @aurasuisui/indexmap.IndexSet::new()
  set.insert("x") |> ignore
  inspect(set.is_subset(set), content="true")
}

///|
test "set superset with self" {
  let set = @aurasuisui/indexmap.IndexSet::new()
  set.insert("x") |> ignore
  inspect(set.is_superset(set), content="true")
}

///|
test "set retain all" {
  let set = @aurasuisui/indexmap.IndexSet::new()
  set.insert(1) |> ignore
  set.insert(2) |> ignore
  set.insert(3) |> ignore
  set.retain(fn(_x) { true })
  inspect(set.len(), content="3")
}

///|
test "set retain none" {
  let set = @aurasuisui/indexmap.IndexSet::new()
  set.insert(1) |> ignore
  set.insert(2) |> ignore
  set.retain(fn(_x) { false })
  inspect(set.is_empty(), content="true")
}

///|
test "set remove all and reinsert" {
  let set = @aurasuisui/indexmap.IndexSet::new()
  set.insert("a") |> ignore
  set.insert("b") |> ignore
  set.insert("c") |> ignore
  set.remove("a") |> ignore
  set.remove("b") |> ignore
  set.remove("c") |> ignore
  inspect(set.is_empty(), content="true")
  set.insert("d") |> ignore
  inspect(set.len(), content="1")
  inspect(set.contains("d"), content="true")
  inspect(set.contains("a"), content="false")
}

///|
test "set remove preserves order" {
  let set = @aurasuisui/indexmap.IndexSet::new()
  set.insert("c") |> ignore
  set.insert("a") |> ignore
  set.insert("b") |> ignore
  set.remove("a") |> ignore
  let iter = set.iter()
  match iter.next() {
    Some(k) => inspect(k, content="c")
    None => @test.fail("expected c")
  }
  match iter.next() {
    Some(k) => inspect(k, content="b")
    None => @test.fail("expected b")
  }
  inspect(iter.next(), content="None")
}

///|
test "set clear then reuse" {
  let set = @aurasuisui/indexmap.IndexSet::new()
  set.insert("a") |> ignore
  set.insert("b") |> ignore
  set.clear()
  set.insert("c") |> ignore
  inspect(set.len(), content="1")
  inspect(set.contains("c"), content="true")
  inspect(set.contains("a"), content="false")
}

///|
test "set disjoint one empty" {
  let a = @aurasuisui/indexmap.IndexSet::new()
  a.insert("x") |> ignore
  let b = @aurasuisui/indexmap.IndexSet::new()
  inspect(a.is_disjoint(b), content="true")
  inspect(b.is_disjoint(a), content="true")
}

///|
test "set subset one empty" {
  let a = @aurasuisui/indexmap.IndexSet::new()
  a.insert("x") |> ignore
  let b = @aurasuisui/indexmap.IndexSet::new()
  inspect(b.is_subset(a), content="true")
  inspect(a.is_subset(b), content="false")
}

///|
test "set superset one empty" {
  let a = @aurasuisui/indexmap.IndexSet::new()
  a.insert("x") |> ignore
  let b = @aurasuisui/indexmap.IndexSet::new()
  inspect(a.is_superset(b), content="true")
  inspect(b.is_superset(a), content="false")
}

///|
test "set multiple inserts same element" {
  let set = @aurasuisui/indexmap.IndexSet::new()
  let mut i = 0
  while i < 20 {
    set.insert("same") |> ignore
    i = i + 1
  }
  inspect(set.len(), content="1")
}

///|
test "set large disjoint check" {
  let a = @aurasuisui/indexmap.IndexSet::with_capacity(1024)
  let mut i = 0
  while i < 500 {
    a.insert(i) |> ignore
    i = i + 1
  }
  let b = @aurasuisui/indexmap.IndexSet::with_capacity(1024)
  let mut j = 500
  while j < 1000 {
    b.insert(j) |> ignore
    j = j + 1
  }
  inspect(a.is_disjoint(b), content="true")
}

///|
test "set large subset check" {
  let a = @aurasuisui/indexmap.IndexSet::new()
  let mut i = 0
  while i < 100 {
    a.insert(i) |> ignore
    i = i + 1
  }
  let b = @aurasuisui/indexmap.IndexSet::new()
  let mut j = 0
  while j < 200 {
    b.insert(j) |> ignore
    j = j + 1
  }
  inspect(a.is_subset(b), content="true")
  inspect(b.is_subset(a), content="false")
}

///|
test "set with_capacity default" {
  let set = @aurasuisui/indexmap.IndexSet::new()
  inspect(set.capacity(), content="16")
}

///|
test "set empty retain" {
  let set = @aurasuisui/indexmap.IndexSet::new()
  set.retain(fn(_x) { true })
  inspect(set.is_empty(), content="true")
}

///|
test "set disjoint same elements" {
  let a = @aurasuisui/indexmap.IndexSet::new()
  a.insert("x") |> ignore
  a.insert("y") |> ignore
  let b = @aurasuisui/indexmap.IndexSet::new()
  b.insert("x") |> ignore
  b.insert("y") |> ignore
  inspect(a.is_disjoint(b), content="false")
  inspect(b.is_disjoint(a), content="false")
}

///|
test "set subset equal sets" {
  let a = @aurasuisui/indexmap.IndexSet::new()
  a.insert("a") |> ignore
  a.insert("b") |> ignore
  let b = @aurasuisui/indexmap.IndexSet::new()
  b.insert("a") |> ignore
  b.insert("b") |> ignore
  inspect(a.is_subset(b), content="true")
  inspect(b.is_subset(a), content="true")
}

///|
test "set superset equal sets" {
  let a = @aurasuisui/indexmap.IndexSet::new()
  a.insert(1) |> ignore
  a.insert(2) |> ignore
  let b = @aurasuisui/indexmap.IndexSet::new()
  b.insert(1) |> ignore
  b.insert(2) |> ignore
  inspect(a.is_superset(b), content="true")
}

///|
test "set iterate empty" {
  let set = @aurasuisui/indexmap.IndexSet::new()
  inspect(set.iter().next(), content="None")
}

///|
test "set chained operations" {
  let set = @aurasuisui/indexmap.IndexSet::new()
  set.insert("a") |> ignore
  set.insert("b") |> ignore
  set.insert("c") |> ignore
  set.remove("b") |> ignore
  set.insert("d") |> ignore
  set.remove("a") |> ignore
  let iter = set.iter()
  match iter.next() {
    Some(k) => inspect(k, content="c")
    None => @test.fail("expected c")
  }
  match iter.next() {
    Some(k) => inspect(k, content="d")
    None => @test.fail("expected d")
  }
  inspect(iter.next(), content="None")
  inspect(set.len(), content="2")
}

///|
test "set remove middle element" {
  let set = @aurasuisui/indexmap.IndexSet::new()
  set.insert("a") |> ignore
  set.insert("b") |> ignore
  set.insert("c") |> ignore
  set.remove("b") |> ignore
  inspect(set.len(), content="2")
  let iter = set.iter()
  match iter.next() {
    Some(k) => inspect(k, content="a")
    None => @test.fail("expected a")
  }
  match iter.next() {
    Some(k) => inspect(k, content="c")
    None => @test.fail("expected c")
  }
  inspect(iter.next(), content="None")
}

///|
test "set first and last via iteration" {
  let set = @aurasuisui/indexmap.IndexSet::new()
  set.insert("first") |> ignore
  set.insert("middle") |> ignore
  set.insert("last") |> ignore
  let iter = set.iter()
  match iter.next() {
    Some(k) => inspect(k, content="first")
    None => @test.fail("expected first")
  }
  // Skip middle
  iter.next() |> ignore
  match iter.next() {
    Some(k) => inspect(k, content="last")
    None => @test.fail("expected last")
  }
}

///|
test "set with_capacity zero" {
  let set = @aurasuisui/indexmap.IndexSet::with_capacity(0)
  inspect(set.capacity(), content="16")
  inspect(set.is_empty(), content="true")
}

///|
test "set is_empty after all operations" {
  let set = @aurasuisui/indexmap.IndexSet::new()
  set.insert("x") |> ignore
  set.insert("y") |> ignore
  set.remove("x") |> ignore
  set.remove("y") |> ignore
  inspect(set.is_empty(), content="true")
}

///|
test "set from_array" {
  let set = @aurasuisui/indexmap.IndexSet::from_array(["c", "a", "b"])
  inspect(set.len(), content="3")
  inspect(set.contains("a"), content="true")
  inspect(set.contains("b"), content="true")
  inspect(set.contains("c"), content="true")
  inspect(set.contains("d"), content="false")
  let iter = set.iter()
  match iter.next() {
    Some(k) => inspect(k, content="c")
    None => @test.fail("expected c")
  }
  match iter.next() {
    Some(k) => inspect(k, content="a")
    None => @test.fail("expected a")
  }
  match iter.next() {
    Some(k) => inspect(k, content="b")
    None => @test.fail("expected b")
  }
  inspect(iter.next(), content="None")
}

///|
test "set drain" {
  let set = @aurasuisui/indexmap.IndexSet::new()
  set.insert("x") |> ignore
  set.insert("y") |> ignore
  set.insert("z") |> ignore
  let drained = set.drain()
  inspect(drained.length(), content="3")
  inspect(drained[0], content="x")
  inspect(drained[1], content="y")
  inspect(drained[2], content="z")
  inspect(set.is_empty(), content="true")
}

///|
test "set drain empty" {
  let set = @aurasuisui/indexmap.IndexSet::new()
  let drained = set.drain()
  inspect(drained.length(), content="0")
}

///|
test "set extend" {
  let set = @aurasuisui/indexmap.IndexSet::new()
  set.insert("existing") |> ignore
  set.extend(["a", "b", "c"])
  inspect(set.len(), content="4")
  inspect(set.contains("existing"), content="true")
  inspect(set.contains("a"), content="true")
  inspect(set.contains("b"), content="true")
  inspect(set.contains("c"), content="true")
}

///|
test "IndexSet Default trait" {
  let set : @aurasuisui/indexmap.IndexSet[String] = @aurasuisui/indexmap.IndexSet::default()
  inspect(set.is_empty(), content="true")
  inspect(set.len(), content="0")
}

///|
test "IndexSet copy preserves elements and order" {
  let set = @aurasuisui/indexmap.IndexSet::new()
  set.insert("b") |> ignore
  set.insert("a") |> ignore
  set.insert("c") |> ignore
  let copy = set.copy()
  inspect(copy.len(), content="3")
  inspect(copy.contains("a"), content="true")
  inspect(copy.contains("b"), content="true")
  inspect(copy.contains("c"), content="true")
  let iter = copy.iter()
  inspect(iter.next(), content="Some(b)")
  inspect(iter.next(), content="Some(a)")
  inspect(iter.next(), content="Some(c)")
  inspect(iter.next(), content="None")
}

///|
test "IndexSet into_array consumes all elements" {
  let set = @aurasuisui/indexmap.IndexSet::new()
  set.insert(1) |> ignore
  set.insert(2) |> ignore
  set.insert(3) |> ignore
  let arr = set.into_array()
  inspect(arr.length(), content="3")
  inspect(arr[0], content="1")
  inspect(arr[1], content="2")
  inspect(arr[2], content="3")
}
