// Blackbox tests for IndexSet — use @aurasuisui/indexmap to import public API.

///|
test "new set is empty" {
  let set : @aurasuisui/indexmap.IndexSet[String] = @aurasuisui/indexmap.IndexSet::new()
  debug_inspect(set.len(), content="0")
  debug_inspect(set.is_empty(), content="true")
}

///|
test "set insert and contains" {
  let set = @aurasuisui/indexmap.IndexSet::new()
  debug_inspect(set.insert("a"), content="true")
  debug_inspect(set.insert("a"), content="false")
  debug_inspect(set.contains("a"), content="true")
  debug_inspect(set.contains("b"), content="false")
  debug_inspect(set.len(), content="1")
}

///|
test "set remove" {
  let set = @aurasuisui/indexmap.IndexSet::new()
  set.insert("a") |> ignore
  set.insert("b") |> ignore
  debug_inspect(set.remove("a"), content="true")
  debug_inspect(set.remove("a"), content="false")
  debug_inspect(set.len(), content="1")
  debug_inspect(set.contains("a"), content="false")
}

///|
test "set clear" {
  let set = @aurasuisui/indexmap.IndexSet::new()
  set.insert("a") |> ignore
  set.insert("b") |> ignore
  set.clear()
  debug_inspect(set.len(), content="0")
}

///|
test "set disjoint" {
  let a = @aurasuisui/indexmap.IndexSet::new()
  a.insert("x") |> ignore
  a.insert("y") |> ignore
  let b = @aurasuisui/indexmap.IndexSet::new()
  b.insert("z") |> ignore
  b.insert("w") |> ignore
  debug_inspect(a.is_disjoint(b), content="true")
  b.insert("x") |> ignore
  debug_inspect(a.is_disjoint(b), content="false")
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
  debug_inspect(a.is_subset(b), content="true")
  debug_inspect(b.is_subset(a), content="false")
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
  debug_inspect(a.is_superset(b), content="true")
  debug_inspect(b.is_superset(a), content="false")
}

///|
test "set iteration order" {
  let set = @aurasuisui/indexmap.IndexSet::new()
  set.insert("c") |> ignore
  set.insert("a") |> ignore
  set.insert("b") |> ignore
  let iter = set.iter()
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
  debug_inspect(iter.next(), content="None")
}

///|
test "set retain" {
  let set = @aurasuisui/indexmap.IndexSet::new()
  set.insert(1) |> ignore
  set.insert(2) |> ignore
  set.insert(3) |> ignore
  set.insert(4) |> ignore
  set.retain(fn(x) { x % 2 == 0 })
  debug_inspect(set.len(), content="2")
  debug_inspect(set.contains(2), content="true")
  debug_inspect(set.contains(4), content="true")
  debug_inspect(set.contains(1), content="false")
  debug_inspect(set.contains(3), content="false")
}

///|
test "set large insert" {
  let set = @aurasuisui/indexmap.IndexSet::new()
  let mut i = 0
  while i < 500 {
    set.insert(i) |> ignore
    i = i + 1
  }
  debug_inspect(set.len(), content="500")
  let mut j = 0
  while j < 500 {
    debug_inspect(set.contains(j), content="true")
    j = j + 1
  }
}

///|
test "set capacity" {
  let set : @aurasuisui/indexmap.IndexSet[String] = @aurasuisui/indexmap.IndexSet::with_capacity(
    64,
  )
  debug_inspect(set.capacity(), content="64")
  debug_inspect(set.is_empty(), content="true")
}

///|
test "set empty operations" {
  let a : @aurasuisui/indexmap.IndexSet[String] = @aurasuisui/indexmap.IndexSet::new()
  let b = @aurasuisui/indexmap.IndexSet::new()
  debug_inspect(a.is_disjoint(b), content="true")
  debug_inspect(a.is_subset(b), content="true")
  debug_inspect(a.is_superset(b), content="true")
}

///|
test "set disjoint with self" {
  let set = @aurasuisui/indexmap.IndexSet::new()
  set.insert("x") |> ignore
  debug_inspect(set.is_disjoint(set), content="false")
}

///|
test "set subset with self" {
  let set = @aurasuisui/indexmap.IndexSet::new()
  set.insert("x") |> ignore
  debug_inspect(set.is_subset(set), content="true")
}

///|
test "set superset with self" {
  let set = @aurasuisui/indexmap.IndexSet::new()
  set.insert("x") |> ignore
  debug_inspect(set.is_superset(set), content="true")
}

///|
test "set retain all" {
  let set = @aurasuisui/indexmap.IndexSet::new()
  set.insert(1) |> ignore
  set.insert(2) |> ignore
  set.insert(3) |> ignore
  set.retain(fn(_x) { true })
  debug_inspect(set.len(), content="3")
}

///|
test "set retain none" {
  let set = @aurasuisui/indexmap.IndexSet::new()
  set.insert(1) |> ignore
  set.insert(2) |> ignore
  set.retain(fn(_x) { false })
  debug_inspect(set.is_empty(), content="true")
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
  debug_inspect(set.is_empty(), content="true")
  set.insert("d") |> ignore
  debug_inspect(set.len(), content="1")
  debug_inspect(set.contains("d"), content="true")
  debug_inspect(set.contains("a"), content="false")
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
          #|"b"
        ),
      )
    None => @test.fail("expected b")
  }
  debug_inspect(iter.next(), content="None")
}

///|
test "set clear then reuse" {
  let set = @aurasuisui/indexmap.IndexSet::new()
  set.insert("a") |> ignore
  set.insert("b") |> ignore
  set.clear()
  set.insert("c") |> ignore
  debug_inspect(set.len(), content="1")
  debug_inspect(set.contains("c"), content="true")
  debug_inspect(set.contains("a"), content="false")
}

///|
test "set disjoint one empty" {
  let a = @aurasuisui/indexmap.IndexSet::new()
  a.insert("x") |> ignore
  let b = @aurasuisui/indexmap.IndexSet::new()
  debug_inspect(a.is_disjoint(b), content="true")
  debug_inspect(b.is_disjoint(a), content="true")
}

///|
test "set subset one empty" {
  let a = @aurasuisui/indexmap.IndexSet::new()
  a.insert("x") |> ignore
  let b = @aurasuisui/indexmap.IndexSet::new()
  debug_inspect(b.is_subset(a), content="true")
  debug_inspect(a.is_subset(b), content="false")
}

///|
test "set superset one empty" {
  let a = @aurasuisui/indexmap.IndexSet::new()
  a.insert("x") |> ignore
  let b = @aurasuisui/indexmap.IndexSet::new()
  debug_inspect(a.is_superset(b), content="true")
  debug_inspect(b.is_superset(a), content="false")
}

///|
test "set multiple inserts same element" {
  let set = @aurasuisui/indexmap.IndexSet::new()
  let mut i = 0
  while i < 20 {
    set.insert("same") |> ignore
    i = i + 1
  }
  debug_inspect(set.len(), content="1")
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
  debug_inspect(a.is_disjoint(b), content="true")
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
  debug_inspect(a.is_subset(b), content="true")
  debug_inspect(b.is_subset(a), content="false")
}

///|
test "set with_capacity default" {
  let set : @aurasuisui/indexmap.IndexSet[String] = @aurasuisui/indexmap.IndexSet::new()
  debug_inspect(set.capacity(), content="16")
}

///|
test "set empty retain" {
  let set : @aurasuisui/indexmap.IndexSet[String] = @aurasuisui/indexmap.IndexSet::new()
  set.retain(fn(_x) { true })
  debug_inspect(set.is_empty(), content="true")
}

///|
test "set disjoint same elements" {
  let a = @aurasuisui/indexmap.IndexSet::new()
  a.insert("x") |> ignore
  a.insert("y") |> ignore
  let b = @aurasuisui/indexmap.IndexSet::new()
  b.insert("x") |> ignore
  b.insert("y") |> ignore
  debug_inspect(a.is_disjoint(b), content="false")
  debug_inspect(b.is_disjoint(a), content="false")
}

///|
test "set subset equal sets" {
  let a = @aurasuisui/indexmap.IndexSet::new()
  a.insert("a") |> ignore
  a.insert("b") |> ignore
  let b = @aurasuisui/indexmap.IndexSet::new()
  b.insert("a") |> ignore
  b.insert("b") |> ignore
  debug_inspect(a.is_subset(b), content="true")
  debug_inspect(b.is_subset(a), content="true")
}

///|
test "set superset equal sets" {
  let a = @aurasuisui/indexmap.IndexSet::new()
  a.insert(1) |> ignore
  a.insert(2) |> ignore
  let b = @aurasuisui/indexmap.IndexSet::new()
  b.insert(1) |> ignore
  b.insert(2) |> ignore
  debug_inspect(a.is_superset(b), content="true")
}

///|
test "set iterate empty" {
  let set : @aurasuisui/indexmap.IndexSet[String] = @aurasuisui/indexmap.IndexSet::new()
  debug_inspect(set.iter().next(), content="None")
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
          #|"d"
        ),
      )
    None => @test.fail("expected d")
  }
  debug_inspect(iter.next(), content="None")
  debug_inspect(set.len(), content="2")
}

///|
test "set remove middle element" {
  let set = @aurasuisui/indexmap.IndexSet::new()
  set.insert("a") |> ignore
  set.insert("b") |> ignore
  set.insert("c") |> ignore
  set.remove("b") |> ignore
  debug_inspect(set.len(), content="2")
  let iter = set.iter()
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
  debug_inspect(iter.next(), content="None")
}

///|
test "set first and last via iteration" {
  let set = @aurasuisui/indexmap.IndexSet::new()
  set.insert("first") |> ignore
  set.insert("middle") |> ignore
  set.insert("last") |> ignore
  let iter = set.iter()
  match iter.next() {
    Some(k) =>
      debug_inspect(
        k,
        content=(
          #|"first"
        ),
      )
    None => @test.fail("expected first")
  }
  // Skip middle
  iter.next() |> ignore
  match iter.next() {
    Some(k) =>
      debug_inspect(
        k,
        content=(
          #|"last"
        ),
      )
    None => @test.fail("expected last")
  }
}

///|
test "set with_capacity zero" {
  let set : @aurasuisui/indexmap.IndexSet[String] = @aurasuisui/indexmap.IndexSet::with_capacity(
    0,
  )
  debug_inspect(set.capacity(), content="16")
  debug_inspect(set.is_empty(), content="true")
}

///|
test "set is_empty after all operations" {
  let set = @aurasuisui/indexmap.IndexSet::new()
  set.insert("x") |> ignore
  set.insert("y") |> ignore
  set.remove("x") |> ignore
  set.remove("y") |> ignore
  debug_inspect(set.is_empty(), content="true")
}

///|
test "set from_array" {
  let set = @aurasuisui/indexmap.IndexSet::from_array(["c", "a", "b"])
  debug_inspect(set.len(), content="3")
  debug_inspect(set.contains("a"), content="true")
  debug_inspect(set.contains("b"), content="true")
  debug_inspect(set.contains("c"), content="true")
  debug_inspect(set.contains("d"), content="false")
  let iter = set.iter()
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
  debug_inspect(iter.next(), content="None")
}

///|
test "set drain" {
  let set = @aurasuisui/indexmap.IndexSet::new()
  set.insert("x") |> ignore
  set.insert("y") |> ignore
  set.insert("z") |> ignore
  let drained = set.drain()
  debug_inspect(drained.length(), content="3")
  debug_inspect(
    drained[0],
    content=(
      #|"x"
    ),
  )
  debug_inspect(
    drained[1],
    content=(
      #|"y"
    ),
  )
  debug_inspect(
    drained[2],
    content=(
      #|"z"
    ),
  )
  debug_inspect(set.is_empty(), content="true")
}

///|
test "set drain empty" {
  let set : @aurasuisui/indexmap.IndexSet[String] = @aurasuisui/indexmap.IndexSet::new()
  let drained = set.drain()
  debug_inspect(drained.length(), content="0")
}

///|
test "set extend" {
  let set = @aurasuisui/indexmap.IndexSet::new()
  set.insert("existing") |> ignore
  set.extend_from_array(["a", "b", "c"])
  debug_inspect(set.len(), content="4")
  debug_inspect(set.contains("existing"), content="true")
  debug_inspect(set.contains("a"), content="true")
  debug_inspect(set.contains("b"), content="true")
  debug_inspect(set.contains("c"), content="true")
}

///|
test "IndexSet Default trait" {
  let set : @aurasuisui/indexmap.IndexSet[String] = @aurasuisui/indexmap.IndexSet::default()
  debug_inspect(set.is_empty(), content="true")
  debug_inspect(set.len(), content="0")
}

///|
test "IndexSet copy preserves elements and order" {
  let set = @aurasuisui/indexmap.IndexSet::new()
  set.insert("b") |> ignore
  set.insert("a") |> ignore
  set.insert("c") |> ignore
  let copy = set.copy()
  debug_inspect(copy.len(), content="3")
  debug_inspect(copy.contains("a"), content="true")
  debug_inspect(copy.contains("b"), content="true")
  debug_inspect(copy.contains("c"), content="true")
  let iter = copy.iter()
  debug_inspect(
    iter.next(),
    content=(
      #|Some("b")
    ),
  )
  debug_inspect(
    iter.next(),
    content=(
      #|Some("a")
    ),
  )
  debug_inspect(
    iter.next(),
    content=(
      #|Some("c")
    ),
  )
  debug_inspect(iter.next(), content="None")
}

///|
test "IndexSet into_array consumes all elements" {
  let set = @aurasuisui/indexmap.IndexSet::new()
  set.insert(1) |> ignore
  set.insert(2) |> ignore
  set.insert(3) |> ignore
  let arr = set.into_array()
  debug_inspect(arr.length(), content="3")
  debug_inspect(arr[0], content="1")
  debug_inspect(arr[1], content="2")
  debug_inspect(arr[2], content="3")
}

///|
test "IndexSet Eq equal sets" {
  let a = @aurasuisui/indexmap.IndexSet::new()
  a.insert("x") |> ignore
  a.insert("y") |> ignore
  a.insert("z") |> ignore
  let b = @aurasuisui/indexmap.IndexSet::new()
  b.insert("x") |> ignore
  b.insert("y") |> ignore
  b.insert("z") |> ignore
  debug_inspect(a == b, content="true")
}

///|
test "IndexSet Eq different order not equal" {
  let a = @aurasuisui/indexmap.IndexSet::new()
  a.insert("a") |> ignore
  a.insert("b") |> ignore
  let b = @aurasuisui/indexmap.IndexSet::new()
  b.insert("b") |> ignore
  b.insert("a") |> ignore
  debug_inspect(a == b, content="false")
}

///|
test "IndexSet Eq different length not equal" {
  let a = @aurasuisui/indexmap.IndexSet::new()
  a.insert("a") |> ignore
  let b = @aurasuisui/indexmap.IndexSet::new()
  b.insert("a") |> ignore
  b.insert("b") |> ignore
  debug_inspect(a == b, content="false")
}

///|
test "IndexSet Eq empty sets equal" {
  let a : @aurasuisui/indexmap.IndexSet[String] = @aurasuisui/indexmap.IndexSet::new()
  let b = @aurasuisui/indexmap.IndexSet::new()
  debug_inspect(a == b, content="true")
}

///|
test "IndexSet Hash same set same hash" {
  let a = @aurasuisui/indexmap.IndexSet::new()
  a.insert(1) |> ignore
  a.insert(2) |> ignore
  let b = @aurasuisui/indexmap.IndexSet::new()
  b.insert(1) |> ignore
  b.insert(2) |> ignore
  debug_inspect(a.hash() == b.hash(), content="true")
}

///|
test "IndexSet Hash different order different hash" {
  let a = @aurasuisui/indexmap.IndexSet::new()
  a.insert(1) |> ignore
  a.insert(2) |> ignore
  let b = @aurasuisui/indexmap.IndexSet::new()
  b.insert(2) |> ignore
  b.insert(1) |> ignore
  debug_inspect(a.hash() != b.hash(), content="true")
}

///|
test "IndexSet to_json preserves insertion order as a JSON array" {
  let set = @aurasuisui/indexmap.IndexSet::new()
  set.insert("hashmap") |> ignore
  set.insert("indexmap") |> ignore
  set.insert("ordered") |> ignore
  match set.to_json() {
    Array(arr) => {
      debug_inspect(arr.length(), content="3")
      // Extract the raw string from each element to verify order is preserved.
      let got : Array[String] = []
      let mut i = 0
      while i < arr.length() {
        match arr[i] {
          String(s) => got.push(s)
          _ => @test.fail("expected string elements")
        }
        i = i + 1
      }
      debug_inspect(
        got,
        content=(
          #|["hashmap", "indexmap", "ordered"]
        ),
      )
    }
    _ => @test.fail("expected a JSON array")
  }
}

///|
test "IndexSet from_array with duplicates keeps first-occurrence order" {
  let set = @aurasuisui/indexmap.IndexSet::from_array(["a", "b", "a", "c", "b"])
  debug_inspect(set.len(), content="3")
  debug_inspect(
    set.iter().collect(),
    content=(
      #|["a", "b", "c"]
    ),
  )
}
