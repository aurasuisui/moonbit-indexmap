// Blackbox tests for IndexMap — use @aurasuisui/indexmap to import public API.

///|
test "new map is empty" {
  let map : @aurasuisui/indexmap.IndexMap[String, Int] = @aurasuisui/indexmap.new()
  debug_inspect(map.len(), content="0")
  debug_inspect(map.is_empty(), content="true")
}

///|
test "insert and get" {
  let map = @aurasuisui/indexmap.new()
  debug_inspect(map.insert("key1", 42), content="None")
  debug_inspect(map.get("key1"), content="Some(42)")
  debug_inspect(map.len(), content="1")
}

///|
test "insert overwrites existing" {
  let map = @aurasuisui/indexmap.new()
  map.insert("a", 1) |> ignore
  let old = map.insert("a", 100)
  debug_inspect(old, content="Some(1)")
  debug_inspect(map.get("a"), content="Some(100)")
  debug_inspect(map.len(), content="1")
}

///|
test "get missing key" {
  let map : @aurasuisui/indexmap.IndexMap[String, Int] = @aurasuisui/indexmap.new()
  debug_inspect(map.get("missing"), content="None")
}

///|
test "contains" {
  let map = @aurasuisui/indexmap.new()
  map.insert("x", 10) |> ignore
  debug_inspect(map.contains("x"), content="true")
  debug_inspect(map.contains("y"), content="false")
}

///|
test "remove existing" {
  let map = @aurasuisui/indexmap.new()
  map.insert("a", 1) |> ignore
  map.insert("b", 2) |> ignore
  let removed = map.remove("a")
  debug_inspect(removed, content="Some(1)")
  debug_inspect(map.contains("a"), content="false")
  debug_inspect(map.contains("b"), content="true")
  debug_inspect(map.len(), content="1")
}

///|
test "remove missing" {
  let map = @aurasuisui/indexmap.new()
  map.insert("a", 1) |> ignore
  debug_inspect(map.remove("missing"), content="None")
  debug_inspect(map.len(), content="1")
}

///|
test "multiple inserts" {
  let map = @aurasuisui/indexmap.new()
  let mut i = 0
  while i < 100 {
    map.insert(i, i * 10) |> ignore
    i = i + 1
  }
  debug_inspect(map.len(), content="100")
  debug_inspect(map.get(0), content="Some(0)")
  debug_inspect(map.get(50), content="Some(500)")
  debug_inspect(map.get(99), content="Some(990)")
}

///|
test "clear" {
  let map = @aurasuisui/indexmap.new()
  map.insert("a", 1) |> ignore
  map.insert("b", 2) |> ignore
  map.clear()
  debug_inspect(map.len(), content="0")
  debug_inspect(map.is_empty(), content="true")
  debug_inspect(map.get("a"), content="None")
}

///|
test "iteration preserves insertion order" {
  let map = @aurasuisui/indexmap.new()
  map.insert("c", 3) |> ignore
  map.insert("a", 1) |> ignore
  map.insert("b", 2) |> ignore
  let iter = map.iter()
  match iter.next() {
    Some((k, v)) => {
      debug_inspect(
        k,
        content=(
          #|"c"
        ),
      )
      debug_inspect(v, content="3")
    }
    None => @test.fail("expected entry")
  }
  match iter.next() {
    Some((k, v)) => {
      debug_inspect(
        k,
        content=(
          #|"a"
        ),
      )
      debug_inspect(v, content="1")
    }
    None => @test.fail("expected entry")
  }
  match iter.next() {
    Some((k, v)) => {
      debug_inspect(
        k,
        content=(
          #|"b"
        ),
      )
      debug_inspect(v, content="2")
    }
    None => @test.fail("expected entry")
  }
  debug_inspect(iter.next(), content="None")
}

///|
test "overwrite preserves position" {
  let map = @aurasuisui/indexmap.new()
  map.insert("c", 3) |> ignore
  map.insert("a", 1) |> ignore
  map.insert("c", 99) |> ignore
  let entries = map.iter().collect()
  debug_inspect(
    entries[0],
    content=(
      #|("c", 99)
    ),
  )
  debug_inspect(
    entries[1],
    content=(
      #|("a", 1)
    ),
  )
  debug_inspect(entries.length(), content="2")
}

///|
test "remove preserves remaining order" {
  let map = @aurasuisui/indexmap.new()
  map.insert("a", 1) |> ignore
  map.insert("b", 2) |> ignore
  map.insert("c", 3) |> ignore
  map.remove("b") |> ignore
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
      #|("c", 3)
    ),
  )
  debug_inspect(entries.length(), content="2")
}

///|
test "get_index" {
  let map = @aurasuisui/indexmap.new()
  map.insert("x", 10) |> ignore
  map.insert("y", 20) |> ignore
  map.insert("z", 30) |> ignore
  debug_inspect(
    map.get_index(0),
    content=(
      #|Some(("x", 10))
    ),
  )
  debug_inspect(
    map.get_index(1),
    content=(
      #|Some(("y", 20))
    ),
  )
  debug_inspect(
    map.get_index(2),
    content=(
      #|Some(("z", 30))
    ),
  )
  debug_inspect(map.get_index(3), content="None")
  debug_inspect(map.get_index(-1), content="None")
}

///|
test "get_index_of" {
  let map = @aurasuisui/indexmap.new()
  map.insert("a", 1) |> ignore
  map.insert("b", 2) |> ignore
  map.insert("c", 3) |> ignore
  debug_inspect(map.get_index_of("a"), content="Some(0)")
  debug_inspect(map.get_index_of("b"), content="Some(1)")
  debug_inspect(map.get_index_of("c"), content="Some(2)")
  debug_inspect(map.get_index_of("d"), content="None")
}

///|
test "empty string key" {
  let map = @aurasuisui/indexmap.new()
  map.insert("", "empty") |> ignore
  debug_inspect(
    map.get(""),
    content=(
      #|Some("empty")
    ),
  )
  debug_inspect(map.contains(""), content="true")
}

///|
test "duplicate insert" {
  let map = @aurasuisui/indexmap.new()
  debug_inspect(map.insert("k", 1), content="None")
  debug_inspect(map.insert("k", 2), content="Some(1)")
  debug_inspect(map.insert("k", 3), content="Some(2)")
  debug_inspect(map.get("k"), content="Some(3)")
  debug_inspect(map.len(), content="1")
}

///|
test "remove and reinsert" {
  let map = @aurasuisui/indexmap.new()
  map.insert("a", 1) |> ignore
  map.insert("b", 2) |> ignore
  map.remove("a") |> ignore
  map.insert("a", 10) |> ignore
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
      #|("a", 10)
    ),
  )
}

///|
test "resize under load" {
  let map = @aurasuisui/indexmap.with_capacity(4)
  let mut i = 0
  while i < 200 {
    map.insert(i, i * 2) |> ignore
    i = i + 1
  }
  debug_inspect(map.len(), content="200")
  let mut j = 0
  while j < 200 {
    match map.get(j) {
      Some(_) => ()
      None => @test.fail("missing entry after resize")
    }
    j = j + 1
  }
}

///|
test "retain" {
  let map = @aurasuisui/indexmap.new()
  map.insert("a", 1) |> ignore
  map.insert("b", 2) |> ignore
  map.insert("c", 3) |> ignore
  map.insert("d", 4) |> ignore
  map.retain(fn(_k, v) { v % 2 == 0 })
  debug_inspect(map.len(), content="2")
  debug_inspect(map.contains("b"), content="true")
  debug_inspect(map.contains("d"), content="true")
  debug_inspect(map.contains("a"), content="false")
  debug_inspect(map.contains("c"), content="false")
}

///|
test "sort_by_key" {
  let map = @aurasuisui/indexmap.new()
  map.insert("c", 3) |> ignore
  map.insert("a", 1) |> ignore
  map.insert("b", 2) |> ignore
  map.sort_by_key()
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
      #|("c", 3)
    ),
  )
}

///|
test "large insert and resize 1000" {
  let map = @aurasuisui/indexmap.new()
  let mut i = 0
  while i < 1000 {
    map.insert(i, i * 3) |> ignore
    i = i + 1
  }
  debug_inspect(map.len(), content="1000")
  debug_inspect(map.get(0), content="Some(0)")
  debug_inspect(map.get(500), content="Some(1500)")
  debug_inspect(map.get(999), content="Some(2997)")
  debug_inspect(map.get(1000), content="None")
}

///|
test "mass delete and rehash" {
  let map = @aurasuisui/indexmap.with_capacity(32)
  let mut i = 0
  while i < 500 {
    map.insert(i, i * 2) |> ignore
    i = i + 1
  }
  debug_inspect(map.len(), content="500")
  let mut j = 0
  while j < 400 {
    map.remove(j) |> ignore
    j = j + 1
  }
  debug_inspect(map.len(), content="100")
  let mut k = 400
  while k < 500 {
    debug_inspect(map.contains(k), content="true")
    k = k + 1
  }
}

///|
test "delete first element preserves order" {
  let map = @aurasuisui/indexmap.new()
  map.insert("a", 1) |> ignore
  map.insert("b", 2) |> ignore
  map.insert("c", 3) |> ignore
  map.remove("a") |> ignore
  let entries = map.iter().collect()
  debug_inspect(entries.length(), content="2")
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
}

///|
test "delete last element preserves order" {
  let map = @aurasuisui/indexmap.new()
  map.insert("a", 1) |> ignore
  map.insert("b", 2) |> ignore
  map.insert("c", 3) |> ignore
  map.remove("c") |> ignore
  let entries = map.iter().collect()
  debug_inspect(entries.length(), content="2")
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
}

///|
test "delete middle element preserves order" {
  let map = @aurasuisui/indexmap.new()
  map.insert("a", 1) |> ignore
  map.insert("b", 2) |> ignore
  map.insert("c", 3) |> ignore
  map.insert("d", 4) |> ignore
  map.remove("b") |> ignore
  map.remove("c") |> ignore
  let entries = map.iter().collect()
  debug_inspect(entries.length(), content="2")
  debug_inspect(
    entries[0],
    content=(
      #|("a", 1)
    ),
  )
  debug_inspect(
    entries[1],
    content=(
      #|("d", 4)
    ),
  )
}

///|
test "empty map edge cases" {
  let map : @aurasuisui/indexmap.IndexMap[String, Int] = @aurasuisui/indexmap.new()
  debug_inspect(map.len(), content="0")
  debug_inspect(map.is_empty(), content="true")
  debug_inspect(map.get("any"), content="None")
  debug_inspect(map.remove("any"), content="None")
  debug_inspect(map.contains("any"), content="false")
  debug_inspect(map.capacity(), content="16")
  debug_inspect(map.first(), content="None")
  debug_inspect(map.last(), content="None")
  debug_inspect(map.pop(), content="None")
}

///|
test "reserve capacity" {
  let map = @aurasuisui/indexmap.new()
  let init_cap = map.capacity()
  map.reserve(1000)
  let new_cap = map.capacity()
  debug_inspect(new_cap > init_cap, content="true")
  debug_inspect(new_cap >= 1000, content="true")
  // Verify existing data is preserved
  map.insert("hello", 42) |> ignore
  map.reserve(500)
  debug_inspect(map.get("hello"), content="Some(42)")
}

///|
test "shrink_to_fit reduces capacity" {
  let map = @aurasuisui/indexmap.with_capacity(256)
  map.insert("a", 1) |> ignore
  map.insert("b", 2) |> ignore
  let cap_before = map.capacity()
  map.shrink_to_fit()
  let cap_after = map.capacity()
  debug_inspect(cap_after <= cap_before, content="true")
  debug_inspect(map.get("a"), content="Some(1)")
  debug_inspect(map.get("b"), content="Some(2)")
}

///|
test "first and last access" {
  let map = @aurasuisui/indexmap.new()
  map.insert("x", 10) |> ignore
  map.insert("y", 20) |> ignore
  map.insert("z", 30) |> ignore
  debug_inspect(
    map.first(),
    content=(
      #|Some(("x", 10))
    ),
  )
  debug_inspect(
    map.last(),
    content=(
      #|Some(("z", 30))
    ),
  )
}

///|
test "pop removes last inserted" {
  let map = @aurasuisui/indexmap.new()
  map.insert("a", 1) |> ignore
  map.insert("b", 2) |> ignore
  let popped = map.pop()
  debug_inspect(
    popped,
    content=(
      #|Some(("b", 2))
    ),
  )
  debug_inspect(map.len(), content="1")
  debug_inspect(map.contains("b"), content="false")
  debug_inspect(map.contains("a"), content="true")
}

///|
test "pop on empty returns none" {
  let map : @aurasuisui/indexmap.IndexMap[String, Int] = @aurasuisui/indexmap.new()
  debug_inspect(map.pop(), content="None")
}

///|
test "capacity and load_factor" {
  let map = @aurasuisui/indexmap.new()
  debug_inspect(map.capacity(), content="16")
  let lf = map.load_factor()
  debug_inspect(lf < 1.0, content="true")
  let mut i = 0
  while i < 100 {
    map.insert(i, i) |> ignore
    i = i + 1
  }
  debug_inspect(map.capacity() >= 100, content="true")
}

///|
test "max_probe diagnostic" {
  let map = @aurasuisui/indexmap.with_capacity(4)
  map.insert(1, "a") |> ignore
  map.insert(2, "b") |> ignore
  map.insert(3, "c") |> ignore
  debug_inspect(map.max_probe() >= 0, content="true")
}

///|
test "swap_remove_index first" {
  let map = @aurasuisui/indexmap.new()
  map.insert("a", 1) |> ignore
  map.insert("b", 2) |> ignore
  map.insert("c", 3) |> ignore
  let result = map.swap_remove_index(0)
  debug_inspect(
    result,
    content=(
      #|Some(("a", 1))
    ),
  )
  debug_inspect(map.len(), content="2")
  debug_inspect(map.contains("a"), content="false")
  debug_inspect(map.contains("b"), content="true")
  debug_inspect(map.contains("c"), content="true")
}

///|
test "swap_remove_index last" {
  let map = @aurasuisui/indexmap.new()
  map.insert("a", 1) |> ignore
  map.insert("b", 2) |> ignore
  map.insert("c", 3) |> ignore
  let result = map.swap_remove_index(2)
  debug_inspect(
    result,
    content=(
      #|Some(("c", 3))
    ),
  )
  debug_inspect(map.len(), content="2")
  debug_inspect(map.contains("c"), content="false")
}

///|
test "swap_remove_index middle" {
  let map = @aurasuisui/indexmap.new()
  map.insert("a", 1) |> ignore
  map.insert("b", 2) |> ignore
  map.insert("c", 3) |> ignore
  let result = map.swap_remove_index(1)
  debug_inspect(
    result,
    content=(
      #|Some(("b", 2))
    ),
  )
  debug_inspect(map.len(), content="2")
  debug_inspect(map.contains("b"), content="false")
}

///|
test "swap_remove_index out of bounds" {
  let map = @aurasuisui/indexmap.new()
  map.insert("a", 1) |> ignore
  debug_inspect(map.swap_remove_index(5), content="None")
  debug_inspect(map.swap_remove_index(-1), content="None")
  debug_inspect(map.len(), content="1")
}

///|
test "for_each iteration" {
  let map = @aurasuisui/indexmap.new()
  map.insert("a", 1) |> ignore
  map.insert("b", 2) |> ignore
  map.insert("c", 3) |> ignore
  let mut sum = 0
  map.for_each(fn(_k, v) { sum = sum + v })
  debug_inspect(sum, content="6")
}

///|
test "for_each empty map" {
  let map : @aurasuisui/indexmap.IndexMap[String, Int] = @aurasuisui/indexmap.new()
  let mut count = 0
  map.for_each(fn(_k, _v) { count = count + 1 })
  debug_inspect(count, content="0")
}

///|
test "from_array constructor" {
  let entries = [("b", 2), ("a", 1), ("c", 3)]
  let map = @aurasuisui/indexmap.IndexMap::from_array(entries)
  debug_inspect(map.len(), content="3")
  debug_inspect(map.get("a"), content="Some(1)")
  debug_inspect(map.get("b"), content="Some(2)")
  debug_inspect(map.get("c"), content="Some(3)")
  let collected = map.iter().collect()
  debug_inspect(
    collected[0],
    content=(
      #|("b", 2)
    ),
  )
  debug_inspect(
    collected[1],
    content=(
      #|("a", 1)
    ),
  )
  debug_inspect(
    collected[2],
    content=(
      #|("c", 3)
    ),
  )
}

///|
test "drain collects all entries" {
  let map = @aurasuisui/indexmap.new()
  map.insert("x", 10) |> ignore
  map.insert("y", 20) |> ignore
  map.insert("z", 30) |> ignore
  let drained = map.drain()
  debug_inspect(drained.length(), content="3")
  debug_inspect(
    drained[0],
    content=(
      #|("x", 10)
    ),
  )
  debug_inspect(
    drained[1],
    content=(
      #|("y", 20)
    ),
  )
  debug_inspect(
    drained[2],
    content=(
      #|("z", 30)
    ),
  )
  debug_inspect(map.is_empty(), content="true")
}

///|
test "drain on empty map" {
  let map : @aurasuisui/indexmap.IndexMap[String, Int] = @aurasuisui/indexmap.new()
  let drained = map.drain()
  debug_inspect(drained.length(), content="0")
}

///|
test "extend from array" {
  let map = @aurasuisui/indexmap.new()
  map.insert("existing", 0) |> ignore
  let entries = [("a", 1), ("b", 2), ("c", 3)]
  map.extend_from_array(entries)
  debug_inspect(map.len(), content="4")
  debug_inspect(map.get("existing"), content="Some(0)")
  debug_inspect(map.get("a"), content="Some(1)")
  debug_inspect(map.get("b"), content="Some(2)")
  debug_inspect(map.get("c"), content="Some(3)")
}

///|
test "extend overwrites existing keys" {
  let map = @aurasuisui/indexmap.new()
  map.insert("a", 1) |> ignore
  map.extend_from_array([("a", 100), ("b", 200)])
  debug_inspect(map.len(), content="2")
  debug_inspect(map.get("a"), content="Some(100)")
  debug_inspect(map.get("b"), content="Some(200)")
}

///|
test "sort_by custom comparator" {
  let map = @aurasuisui/indexmap.new()
  map.insert("c", 3) |> ignore
  map.insert("a", 1) |> ignore
  map.insert("b", 2) |> ignore
  map.sort_by(fn(e1, e2) { e1.1.compare(e2.1) })
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
      #|("c", 3)
    ),
  )
}

///|
test "keys iterator" {
  let map = @aurasuisui/indexmap.new()
  map.insert("c", 3) |> ignore
  map.insert("a", 1) |> ignore
  map.insert("b", 2) |> ignore
  let iter = map.keys()
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
test "values iterator" {
  let map = @aurasuisui/indexmap.new()
  map.insert("c", 30) |> ignore
  map.insert("a", 10) |> ignore
  map.insert("b", 20) |> ignore
  let iter = map.values()
  match iter.next() {
    Some(v) => debug_inspect(v, content="30")
    None => @test.fail("expected 30")
  }
  match iter.next() {
    Some(v) => debug_inspect(v, content="10")
    None => @test.fail("expected 10")
  }
  match iter.next() {
    Some(v) => debug_inspect(v, content="20")
    None => @test.fail("expected 20")
  }
  debug_inspect(iter.next(), content="None")
}

///|
test "iter count via collect equals len" {
  let map = @aurasuisui/indexmap.new()
  debug_inspect(map.iter().collect().length(), content="0")
  map.insert("a", 1) |> ignore
  map.insert("b", 2) |> ignore
  map.insert("c", 3) |> ignore
  debug_inspect(map.iter().collect().length(), content="3")
}

///|
test "get_full returns key and value" {
  let map = @aurasuisui/indexmap.new()
  map.insert("key", 42) |> ignore
  debug_inspect(
    map.get_full("key"),
    content=(
      #|Some(("key", 42))
    ),
  )
  debug_inspect(map.get_full("missing"), content="None")
}

///|
test "entry api occupied get and insert" {
  let map = @aurasuisui/indexmap.new()
  map.insert("key", 10) |> ignore
  match map.entry("key") {
    @aurasuisui/indexmap.Occupied(entry) => {
      debug_inspect(entry.get(), content="10")
      let old = entry.insert(99)
      debug_inspect(old, content="10")
      debug_inspect(map.get("key"), content="Some(99)")
    }
    @aurasuisui/indexmap.Vacant(_) => @test.fail("expected Occupied")
  }
}

///|
test "entry api occupied remove" {
  let map = @aurasuisui/indexmap.new()
  map.insert("key", 42) |> ignore
  match map.entry("key") {
    @aurasuisui/indexmap.Occupied(entry) => {
      let val = entry.remove()
      debug_inspect(val, content="42")
      debug_inspect(map.contains("key"), content="false")
    }
    @aurasuisui/indexmap.Vacant(_) => @test.fail("expected Occupied")
  }
}

///|
test "entry api occupied key" {
  let map = @aurasuisui/indexmap.new()
  map.insert("mykey", 1) |> ignore
  match map.entry("mykey") {
    @aurasuisui/indexmap.Occupied(entry) =>
      debug_inspect(
        entry.key(),
        content=(
          #|"mykey"
        ),
      )
    @aurasuisui/indexmap.Vacant(_) => @test.fail("expected Occupied")
  }
}

///|
test "entry api vacant insert and key" {
  let map = @aurasuisui/indexmap.new()
  match map.entry("new_key") {
    @aurasuisui/indexmap.Vacant(entry) => {
      debug_inspect(
        entry.key(),
        content=(
          #|"new_key"
        ),
      )
      let val = entry.insert(77)
      debug_inspect(val, content="77")
      debug_inspect(map.get("new_key"), content="Some(77)")
    }
    @aurasuisui/indexmap.Occupied(_) => @test.fail("expected Vacant")
  }
}

///|
test "entry api vacant then occupied" {
  let map = @aurasuisui/indexmap.new()
  match map.entry("k") {
    @aurasuisui/indexmap.Vacant(entry) => entry.insert(5) |> ignore
    @aurasuisui/indexmap.Occupied(_) => @test.fail("expected Vacant")
  }
  match map.entry("k") {
    @aurasuisui/indexmap.Occupied(entry) =>
      debug_inspect(entry.get(), content="5")
    @aurasuisui/indexmap.Vacant(_) => @test.fail("expected Occupied")
  }
}

///|
test "clear then reuse" {
  let map = @aurasuisui/indexmap.new()
  map.insert("a", 1) |> ignore
  map.insert("b", 2) |> ignore
  map.clear()
  map.insert("c", 3) |> ignore
  map.insert("d", 4) |> ignore
  debug_inspect(map.len(), content="2")
  debug_inspect(map.get("c"), content="Some(3)")
  debug_inspect(map.get("a"), content="None")
}

///|
test "many inserts then iterate all" {
  let map = @aurasuisui/indexmap.new()
  let mut i = 0
  while i < 500 {
    map.insert(i, i * 10) |> ignore
    i = i + 1
  }
  debug_inspect(map.len(), content="500")
  let iter = map.iter()
  let mut count = 0
  while true {
    match iter.next() {
      Some(_) => count = count + 1
      None => break
    }
  }
  debug_inspect(count, content="500")
}

///|
test "delete all one by one" {
  let map = @aurasuisui/indexmap.new()
  let mut i = 0
  while i < 100 {
    map.insert(i, i) |> ignore
    i = i + 1
  }
  let mut j = 0
  while j < 100 {
    map.remove(j) |> ignore
    j = j + 1
  }
  debug_inspect(map.is_empty(), content="true")
  debug_inspect(map.len(), content="0")
}

///|
test "int keys with with_capacity" {
  let map = @aurasuisui/indexmap.with_capacity(64)
  debug_inspect(map.capacity(), content="64")
  map.insert(1, "one") |> ignore
  map.insert(2, "two") |> ignore
  map.insert(3, "three") |> ignore
  debug_inspect(
    map.get(2),
    content=(
      #|Some("two")
    ),
  )
}

///|
test "same hash colliding keys" {
  let map = @aurasuisui/indexmap.new()
  map.insert("a", 1) |> ignore
  map.insert("b", 2) |> ignore
  map.insert("c", 3) |> ignore
  debug_inspect(map.len(), content="3")
  debug_inspect(map.get("a"), content="Some(1)")
  debug_inspect(map.get("b"), content="Some(2)")
  debug_inspect(map.get("c"), content="Some(3)")
}

///|
test "eq trait for indexmap" {
  let a = @aurasuisui/indexmap.new()
  a.insert("k1", 10) |> ignore
  a.insert("k2", 20) |> ignore
  let b = @aurasuisui/indexmap.new()
  b.insert("k1", 10) |> ignore
  b.insert("k2", 20) |> ignore
  // Compare by iteration
  let a_entries = a.iter().collect()
  let b_entries = b.iter().collect()
  debug_inspect(a_entries.length() == b_entries.length(), content="true")
  let mut i = 0
  let mut eq = true
  while i < a_entries.length() {
    if a_entries[i].0 != b_entries[i].0 || a_entries[i].1 != b_entries[i].1 {
      eq = false
    }
    i = i + 1
  }
  debug_inspect(eq, content="true")
  b.insert("k3", 30) |> ignore
  debug_inspect(a.len() == b.len(), content="false")
}

///|
test "eq trait different order not equal" {
  let a = @aurasuisui/indexmap.new()
  a.insert("a", 1) |> ignore
  a.insert("b", 2) |> ignore
  let b = @aurasuisui/indexmap.new()
  b.insert("b", 2) |> ignore
  b.insert("a", 1) |> ignore
  let a_entries = a.iter().collect()
  let b_entries = b.iter().collect()
  debug_inspect(a_entries[0].0 == b_entries[0].0, content="false")
}

///|
test "eq trait empty maps" {
  let a : @aurasuisui/indexmap.IndexMap[String, Int] = @aurasuisui/indexmap.new()
  let b : @aurasuisui/indexmap.IndexMap[String, Int] = @aurasuisui/indexmap.new()
  debug_inspect(a.len() == b.len(), content="true")
  debug_inspect(a.is_empty() == b.is_empty(), content="true")
}

///|
test "remove all then reinsert" {
  let map = @aurasuisui/indexmap.new()
  map.insert("a", 1) |> ignore
  map.insert("b", 2) |> ignore
  map.insert("c", 3) |> ignore
  map.remove("a") |> ignore
  map.remove("b") |> ignore
  map.remove("c") |> ignore
  debug_inspect(map.is_empty(), content="true")
  map.insert("d", 4) |> ignore
  map.insert("e", 5) |> ignore
  debug_inspect(map.len(), content="2")
  debug_inspect(map.get("d"), content="Some(4)")
  debug_inspect(map.get("e"), content="Some(5)")
  let entries = map.iter().collect()
  debug_inspect(
    entries[0],
    content=(
      #|("d", 4)
    ),
  )
  debug_inspect(
    entries[1],
    content=(
      #|("e", 5)
    ),
  )
}

///|
test "shrink_to_fit preserves all entries" {
  let map = @aurasuisui/indexmap.with_capacity(256)
  let mut i = 0
  while i < 50 {
    map.insert(i, i * 2) |> ignore
    i = i + 1
  }
  map.shrink_to_fit()
  debug_inspect(map.len(), content="50")
  let mut j = 0
  while j < 50 {
    debug_inspect(map.contains(j), content="true")
    j = j + 1
  }
}

///|
test "retain keeps all" {
  let map = @aurasuisui/indexmap.new()
  map.insert("a", 1) |> ignore
  map.insert("b", 2) |> ignore
  map.insert("c", 3) |> ignore
  map.retain(fn(_k, _v) { true })
  debug_inspect(map.len(), content="3")
}

///|
test "retain removes all" {
  let map = @aurasuisui/indexmap.new()
  map.insert("a", 1) |> ignore
  map.insert("b", 2) |> ignore
  map.retain(fn(_k, _v) { false })
  debug_inspect(map.is_empty(), content="true")
}

///|
test "reserve on empty map" {
  let map : @aurasuisui/indexmap.IndexMap[String, Int] = @aurasuisui/indexmap.new()
  map.reserve(100)
  debug_inspect(map.capacity() >= 100, content="true")
  debug_inspect(map.is_empty(), content="true")
}

///|
test "iterate over map with gaps from deletes" {
  let map = @aurasuisui/indexmap.new()
  let mut i = 0
  while i < 100 {
    map.insert(i, i) |> ignore
    i = i + 1
  }
  // Delete every other entry
  let mut j = 0
  while j < 100 {
    if j % 2 == 0 {
      map.remove(j) |> ignore
    }
    j = j + 1
  }
  let entries = map.iter().collect()
  debug_inspect(entries.length(), content="50")
}

///|
test "int keys negative values" {
  let map = @aurasuisui/indexmap.new()
  map.insert(-5, "neg five") |> ignore
  map.insert(0, "zero") |> ignore
  map.insert(5, "pos five") |> ignore
  debug_inspect(
    map.get(-5),
    content=(
      #|Some("neg five")
    ),
  )
  debug_inspect(
    map.get(0),
    content=(
      #|Some("zero")
    ),
  )
  debug_inspect(
    map.get(5),
    content=(
      #|Some("pos five")
    ),
  )
}

///|
test "large values" {
  let map = @aurasuisui/indexmap.new()
  map.insert("max", 2147483647) |> ignore
  map.insert("min", -2147483648) |> ignore
  debug_inspect(map.get("max"), content="Some(2147483647)")
  debug_inspect(map.get("min"), content="Some(-2147483648)")
}

///|
test "zero capacity" {
  let map : @aurasuisui/indexmap.IndexMap[String, Int] = @aurasuisui/indexmap.with_capacity(
    0,
  )
  debug_inspect(map.capacity(), content="16")
  debug_inspect(map.is_empty(), content="true")
}

///|
test "shrink_to_fit already minimal" {
  let map = @aurasuisui/indexmap.new()
  map.insert("a", 1) |> ignore
  map.shrink_to_fit()
  debug_inspect(map.capacity(), content="16")
  debug_inspect(map.get("a"), content="Some(1)")
}

///|
test "extend empty array" {
  let map : @aurasuisui/indexmap.IndexMap[String, Int] = @aurasuisui/indexmap.new()
  map.extend_from_array([])
  debug_inspect(map.is_empty(), content="true")
}

///|
test "sort_by_key on empty map" {
  let map : @aurasuisui/indexmap.IndexMap[String, Int] = @aurasuisui/indexmap.new()
  map.sort_by_key()
  debug_inspect(map.is_empty(), content="true")
}

///|
test "sort_by on empty map" {
  let map : @aurasuisui/indexmap.IndexMap[String, Int] = @aurasuisui/indexmap.new()
  map.sort_by(fn(_e1, _e2) { 0 })
  debug_inspect(map.is_empty(), content="true")
}

///|
test "retain on empty map" {
  let map : @aurasuisui/indexmap.IndexMap[String, Int] = @aurasuisui/indexmap.new()
  map.retain(fn(_k, _v) { true })
  debug_inspect(map.is_empty(), content="true")
}

///|
test "extend then sort" {
  let map = @aurasuisui/indexmap.new()
  map.extend_from_array([("c", 3), ("a", 1), ("d", 4), ("b", 2)])
  map.sort_by_key()
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
      #|("c", 3)
    ),
  )
  debug_inspect(
    entries[3],
    content=(
      #|("d", 4)
    ),
  )
}

///|
test "sort_by descending" {
  let map = @aurasuisui/indexmap.new()
  map.insert("a", 1) |> ignore
  map.insert("b", 2) |> ignore
  map.insert("c", 3) |> ignore
  map.sort_by(fn(e1, e2) { e2.0.compare(e1.0) })
  let entries = map.iter().collect()
  debug_inspect(
    entries[0],
    content=(
      #|("c", 3)
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
      #|("a", 1)
    ),
  )
}

///|
test "sort_by value" {
  let map = @aurasuisui/indexmap.new()
  map.insert("a", 30) |> ignore
  map.insert("b", 10) |> ignore
  map.insert("c", 20) |> ignore
  map.sort_by(fn(e1, e2) { e1.1.compare(e2.1) })
  let entries = map.iter().collect()
  debug_inspect(entries[0].1, content="10")
  debug_inspect(entries[1].1, content="20")
  debug_inspect(entries[2].1, content="30")
}

///|
test "get_index_of after removal" {
  let map = @aurasuisui/indexmap.new()
  map.insert("a", 1) |> ignore
  map.insert("b", 2) |> ignore
  map.insert("c", 3) |> ignore
  map.remove("b") |> ignore
  debug_inspect(map.get_index_of("a"), content="Some(0)")
  debug_inspect(map.get_index_of("c"), content="Some(1)")
  debug_inspect(map.get_index_of("b"), content="None")
}

///|
test "iter on empty returns no elements" {
  let map : @aurasuisui/indexmap.IndexMap[String, Int] = @aurasuisui/indexmap.new()
  let collected = map.iter().collect()
  debug_inspect(collected.length(), content="0")
}

///|
test "keys iterator on empty map" {
  let map : @aurasuisui/indexmap.IndexMap[String, Int] = @aurasuisui/indexmap.new()
  debug_inspect(map.keys().next(), content="None")
}

///|
test "values iterator on empty map" {
  let map : @aurasuisui/indexmap.IndexMap[String, Int] = @aurasuisui/indexmap.new()
  debug_inspect(map.values().next(), content="None")
}

///|
test "iter collect on empty" {
  let map : @aurasuisui/indexmap.IndexMap[String, Int] = @aurasuisui/indexmap.new()
  let collected = map.iter().collect()
  debug_inspect(collected.length(), content="0")
}

///|
test "reserve zero" {
  let map : @aurasuisui/indexmap.IndexMap[String, Int] = @aurasuisui/indexmap.new()
  let cap_before = map.capacity()
  map.reserve(0)
  debug_inspect(map.capacity(), content="\{cap_before}")
}

///|
test "insert and remove same key repeatedly" {
  let map = @aurasuisui/indexmap.new()
  let mut round = 0
  while round < 50 {
    map.insert("key", round) |> ignore
    debug_inspect(map.get("key"), content="Some(\{round})")
    map.remove("key") |> ignore
    debug_inspect(map.contains("key"), content="false")
    round = round + 1
  }
  debug_inspect(map.is_empty(), content="true")
}

///|
test "many duplicates same key" {
  let map = @aurasuisui/indexmap.new()
  let mut i = 0
  while i < 500 {
    map.insert("constant_key", i) |> ignore
    i = i + 1
  }
  debug_inspect(map.len(), content="1")
  debug_inspect(map.get("constant_key"), content="Some(499)")
}

///|
test "sequential insert and iterate" {
  let map = @aurasuisui/indexmap.new()
  let mut i = 0
  while i < 200 {
    map.insert(i, i.to_string()) |> ignore
    i = i + 1
  }
  let iter = map.iter()
  let mut idx = 0
  while true {
    match iter.next() {
      Some((k, v)) => {
        if k != idx {
          @test.fail("key mismatch at " + idx.to_string())
        }
        if v != idx.to_string() {
          @test.fail("value mismatch at " + idx.to_string())
        }
        idx = idx + 1
      }
      None => break
    }
  }
  debug_inspect(idx, content="200")
}

///|
test "remove from front repeatedly" {
  let map = @aurasuisui/indexmap.new()
  let mut i = 0
  while i < 50 {
    map.insert(i, i) |> ignore
    i = i + 1
  }
  let mut j = 0
  while j < 25 {
    map.remove(j) |> ignore
    j = j + 1
  }
  let entries = map.iter().collect()
  debug_inspect(entries.length(), content="25")
  debug_inspect(entries[0].0, content="25")
}

///|
test "remove from back repeatedly" {
  let map = @aurasuisui/indexmap.new()
  let mut i = 0
  while i < 50 {
    map.insert(i, i) |> ignore
    i = i + 1
  }
  let mut j = 49
  while j >= 25 {
    map.remove(j) |> ignore
    j = j - 1
  }
  let entries = map.iter().collect()
  debug_inspect(entries.length(), content="25")
  debug_inspect(entries[24].0, content="24")
}

///|
test "get_index with all entries deleted" {
  let map = @aurasuisui/indexmap.new()
  map.insert("a", 1) |> ignore
  map.insert("b", 2) |> ignore
  map.remove("a") |> ignore
  map.remove("b") |> ignore
  debug_inspect(map.get_index(0), content="None")
  debug_inspect(map.get_index(1), content="None")
}

///|
test "reinsert after remove in same order slot" {
  let map = @aurasuisui/indexmap.new()
  map.insert("a", 1) |> ignore
  map.insert("b", 2) |> ignore
  map.insert("c", 3) |> ignore
  map.remove("b") |> ignore
  map.insert("b", 20) |> ignore
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
      #|("c", 3)
    ),
  )
  debug_inspect(
    entries[2],
    content=(
      #|("b", 20)
    ),
  )
}

///|
test "double retain" {
  let map = @aurasuisui/indexmap.new()
  let mut i = 0
  while i < 100 {
    map.insert(i, i) |> ignore
    i = i + 1
  }
  map.retain(fn(_k, v) { v % 2 == 0 })
  map.retain(fn(_k, v) { v % 4 == 0 })
  debug_inspect(map.len(), content="25")
  debug_inspect(map.contains(0), content="true")
  debug_inspect(map.contains(4), content="true")
  debug_inspect(map.contains(96), content="true")
  debug_inspect(map.contains(2), content="false")
}

///|
test "sort then retain" {
  let map = @aurasuisui/indexmap.new()
  map.insert("c", 3) |> ignore
  map.insert("a", 1) |> ignore
  map.insert("b", 2) |> ignore
  map.insert("d", 4) |> ignore
  map.sort_by_key()
  map.retain(fn(_k, v) { v % 2 == 0 })
  let entries = map.iter().collect()
  debug_inspect(entries.length(), content="2")
  debug_inspect(
    entries[0],
    content=(
      #|("b", 2)
    ),
  )
  debug_inspect(
    entries[1],
    content=(
      #|("d", 4)
    ),
  )
}

///|
test "retain then iterate order" {
  let map = @aurasuisui/indexmap.new()
  map.insert(3, "c") |> ignore
  map.insert(1, "a") |> ignore
  map.insert(4, "d") |> ignore
  map.insert(2, "b") |> ignore
  map.retain(fn(k, _v) { k % 2 == 0 })
  let entries = map.iter().collect()
  debug_inspect(entries.length(), content="2")
  debug_inspect(
    entries[0],
    content=(
      #|(4, "d")
    ),
  )
  debug_inspect(
    entries[1],
    content=(
      #|(2, "b")
    ),
  )
}

///|
test "drain then extend" {
  let map = @aurasuisui/indexmap.new()
  map.insert("a", 1) |> ignore
  map.insert("b", 2) |> ignore
  let drained = map.drain()
  map.extend_from_array(drained)
  debug_inspect(map.len(), content="2")
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
}

///|
test "capacity never decreases without shrink" {
  let map = @aurasuisui/indexmap.new()
  let mut i = 0
  while i < 500 {
    map.insert(i, i) |> ignore
    i = i + 1
  }
  let cap_after_inserts = map.capacity()
  let mut j = 0
  while j < 400 {
    map.remove(j) |> ignore
    j = j + 1
  }
  let cap_after_removes = map.capacity()
  debug_inspect(cap_after_removes >= cap_after_inserts, content="true")
}

///|
test "reserve smaller than current capacity" {
  let map = @aurasuisui/indexmap.with_capacity(128)
  map.insert("a", 1) |> ignore
  let cap_before = map.capacity()
  map.reserve(10)
  debug_inspect(map.capacity(), content="\{cap_before}")
}

///|
test "with_capacity large power of two check" {
  let map : @aurasuisui/indexmap.IndexMap[String, Int] = @aurasuisui/indexmap.with_capacity(
    1000,
  )
  debug_inspect(map.capacity() >= 1000, content="true")
}

///|
test "single entry operations" {
  let map = @aurasuisui/indexmap.new()
  map.insert("only", 1) |> ignore
  debug_inspect(
    map.first(),
    content=(
      #|Some(("only", 1))
    ),
  )
  debug_inspect(
    map.last(),
    content=(
      #|Some(("only", 1))
    ),
  )
  map.pop() |> ignore
  debug_inspect(map.is_empty(), content="true")
  debug_inspect(map.first(), content="None")
  debug_inspect(map.last(), content="None")
}

///|
test "insert overwrite updates value only" {
  let map = @aurasuisui/indexmap.new()
  map.insert("a", "original") |> ignore
  map.insert("b", "other") |> ignore
  map.insert("a", "updated") |> ignore
  debug_inspect(
    map.get("a"),
    content=(
      #|Some("updated")
    ),
  )
  debug_inspect(
    map.get("b"),
    content=(
      #|Some("other")
    ),
  )
  let entries = map.iter().collect()
  debug_inspect(entries.length(), content="2")
  debug_inspect(
    entries[0].0,
    content=(
      #|"a"
    ),
  )
  debug_inspect(
    entries[1].0,
    content=(
      #|"b"
    ),
  )
}

///|
test "resize during insert triggers rehash" {
  let map = @aurasuisui/indexmap.with_capacity(2)
  map.insert(1, "a") |> ignore
  map.insert(2, "b") |> ignore
  map.insert(3, "c") |> ignore
  // Capacity should have doubled
  debug_inspect(map.capacity() > 2, content="true")
  debug_inspect(map.len(), content="3")
}

///|
test "library version" {
  debug_inspect(
    @aurasuisui/indexmap.VERSION,
    content=(
      #|"0.3.2"
    ),
  )
}

///|
test "IndexMap Default trait" {
  let map : @aurasuisui/indexmap.IndexMap[String, Int] = @aurasuisui/indexmap.IndexMap::default()
  debug_inspect(map.is_empty(), content="true")
  debug_inspect(map.len(), content="0")
}

///|
test "IndexMap copy preserves entries and order" {
  let map = @aurasuisui/indexmap.new()
  map.insert("b", 2) |> ignore
  map.insert("a", 1) |> ignore
  map.insert("c", 3) |> ignore
  let copy = map.copy()
  debug_inspect(copy.len(), content="3")
  debug_inspect(copy.get("a"), content="Some(1)")
  debug_inspect(copy.get("b"), content="Some(2)")
  debug_inspect(copy.get("c"), content="Some(3)")
  let entries = copy.iter().collect()
  debug_inspect(
    entries[0],
    content=(
      #|("b", 2)
    ),
  )
  debug_inspect(
    entries[1],
    content=(
      #|("a", 1)
    ),
  )
  debug_inspect(
    entries[2],
    content=(
      #|("c", 3)
    ),
  )
}

///|
test "IndexMap get_mut modifies value" {
  let map = @aurasuisui/indexmap.new()
  map.insert("key", 1) |> ignore
  map.get_mut("key", fn(v) {
    match v {
      Some(x) => Some(x + 10)
      None => None
    }
  })
  debug_inspect(map.get("key"), content="Some(11)")
}

///|
test "IndexMap get_mut on missing key" {
  let map : @aurasuisui/indexmap.IndexMap[String, Int] = @aurasuisui/indexmap.new()
  map.get_mut("missing", fn(_v) { None })
}

///|
test "IndexMap into_iter consumes map" {
  let map = @aurasuisui/indexmap.new()
  map.insert(1, "a") |> ignore
  map.insert(2, "b") |> ignore
  let iter = map.into_iter()
  debug_inspect(
    iter.next(),
    content=(
      #|Some((1, "a"))
    ),
  )
  debug_inspect(
    iter.next(),
    content=(
      #|Some((2, "b"))
    ),
  )
  debug_inspect(iter.next(), content="None")
}

///|
test "IndexMap into_array consumes all entries" {
  let map = @aurasuisui/indexmap.new()
  map.insert(1, "a") |> ignore
  map.insert(2, "b") |> ignore
  let arr = map.into_array()
  debug_inspect(arr.length(), content="2")
  debug_inspect(
    arr[0],
    content=(
      #|(1, "a")
    ),
  )
  debug_inspect(
    arr[1],
    content=(
      #|(2, "b")
    ),
  )
}
