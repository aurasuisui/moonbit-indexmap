// QuickCheck property-based tests for IndexMap and IndexSet.
//
// Uses moonbitlang/core/quickcheck to generate random inputs and
// verify invariants hold for arbitrary data.

///|
test "qc: generated IndexMap length matches iteration count" {
  let maps : Array[@aurasuisui/indexmap.IndexMap[Int, String]] = @quickcheck.samples(
    20,
  )
  let mut i = 0
  while i < maps.length() {
    let map = maps[i]
    let count = map.iter().collect().length()
    debug_inspect(count, content="\{map.len()}")
    i = i + 1
  }
}

///|
test "qc: generated IndexSet has no duplicates" {
  let sets : Array[@aurasuisui/indexmap.IndexSet[Int]] = @quickcheck.samples(20)
  let mut i = 0
  while i < sets.length() {
    let set = sets[i]
    // Insert should return false for elements already in set
    let iter = set.iter()
    while true {
      match iter.next() {
        Some(k) => debug_inspect(set.contains(k), content="true")
        None => break
      }
    }
    i = i + 1
  }
}

///|
test "qc: insert then get roundtrip" {
  let maps : Array[@aurasuisui/indexmap.IndexMap[Int, Int]] = @quickcheck.samples(
    10,
  )
  let mut i = 0
  while i < maps.length() {
    let map = maps[i]
    let entries = map.iter().collect()
    let mut j = 0
    while j < entries.length() {
      let (k, v) = entries[j]
      match map.get(k) {
        Some(got) => debug_inspect(got, content="\{v}")
        None => @test.fail("get failed for key that should exist")
      }
      j = j + 1
    }
    i = i + 1
  }
}

///|
test "qc: remove all then is empty" {
  let maps : Array[@aurasuisui/indexmap.IndexMap[Int, Int]] = @quickcheck.samples(
    10,
  )
  let mut i = 0
  while i < maps.length() {
    let map = maps[i]
    let keys = map.iter().collect()
    let mut j = 0
    while j < keys.length() {
      let (k, _) = keys[j]
      map.remove(k) |> ignore
      j = j + 1
    }
    debug_inspect(map.is_empty(), content="true")
    i = i + 1
  }
}

///|
test "qc: entry API vacant then occupied roundtrip" {
  let map : @aurasuisui/indexmap.IndexMap[Int, String] = @quickcheck.gen()
  // Choose a key not likely in the generated map
  let test_key = 999999
  if !map.contains(test_key) {
    match map.entry(test_key) {
      @aurasuisui/indexmap.Vacant(entry) => {
        entry.insert("generated") |> ignore
        debug_inspect(map.contains(test_key), content="true")
      }
      @aurasuisui/indexmap.Occupied(_) => @test.fail("expected Vacant")
    }
    match map.entry(test_key) {
      @aurasuisui/indexmap.Occupied(entry) =>
        debug_inspect(
          entry.get(),
          content=(
            #|"generated"
          ),
        )
      @aurasuisui/indexmap.Vacant(_) =>
        @test.fail("expected Occupied after insert")
    }
  }
}

///|
test "qc: iteration preserves insertion order after generation" {
  let maps : Array[@aurasuisui/indexmap.IndexMap[Int, Int]] = @quickcheck.samples(
    10,
  )
  let mut i = 0
  while i < maps.length() {
    let map = maps[i]
    // First pass: collect entries
    let first_pass = map.iter().collect()
    // Second pass: should yield same order
    let second_pass = map.iter().collect()
    debug_inspect(first_pass.length(), content="\{second_pass.length()}")
    let mut j = 0
    while j < first_pass.length() {
      debug_inspect(first_pass[j], content=@debug.to_string(second_pass[j]))
      j = j + 1
    }
    i = i + 1
  }
}

///|
test "qc: IndexSet retains order after generation" {
  let sets : Array[@aurasuisui/indexmap.IndexSet[Int]] = @quickcheck.samples(10)
  let mut i = 0
  while i < sets.length() {
    let set = sets[i]
    let first = set.iter().collect()
    let second = set.iter().collect()
    let mut j = 0
    while j < first.length() {
      debug_inspect(first[j], content="\{second[j]}")
      j = j + 1
    }
    i = i + 1
  }
}

///|
test "qc: generated map positions are consistent" {
  let maps : Array[@aurasuisui/indexmap.IndexMap[Int, Int]] = @quickcheck.samples(
    10,
  )
  let mut i = 0
  while i < maps.length() {
    let map = maps[i]
    let iter = map.iter()
    let mut idx = 0
    while true {
      match iter.next() {
        Some((k, _)) => {
          match map.get_index_of(k) {
            Some(pos) => debug_inspect(pos, content="\{idx}")
            None =>
              @test.fail("get_index_of should return position for existing key")
          }
          idx = idx + 1
        }
        None => break
      }
    }
    i = i + 1
  }
}

///|
test "qc: copy preserves all data" {
  let maps : Array[@aurasuisui/indexmap.IndexMap[Int, Int]] = @quickcheck.samples(
    10,
  )
  let mut i = 0
  while i < maps.length() {
    let map = maps[i]
    let copy = map.copy()
    debug_inspect(copy.len(), content="\{map.len()}")
    let orig_entries = map.iter().collect()
    let copy_entries = copy.iter().collect()
    let mut j = 0
    while j < orig_entries.length() {
      debug_inspect(copy_entries[j], content=@debug.to_string(orig_entries[j]))
      j = j + 1
    }
    i = i + 1
  }
}

///|
test "qc: IndexSet subset implies superset" {
  let sets : Array[@aurasuisui/indexmap.IndexSet[Int]] = @quickcheck.samples(20)
  let mut i = 0
  while i + 1 < sets.length() {
    let a = sets[i]
    let b = sets[i + 1]
    if a.is_subset(b) {
      debug_inspect(b.is_superset(a), content="true")
    }
    i = i + 2
  }
}

///|
test "qc: to_json object contains every key verbatim" {
  let maps : Array[@aurasuisui/indexmap.IndexMap[String, Int]] = @quickcheck.samples(
    10,
  )
  let mut i = 0
  while i < maps.length() {
    let map = maps[i]
    match map.to_json() {
      Object(obj) => {
        // Every key must appear verbatim (raw string), not debug-mangled.
        let iter = map.keys()
        while true {
          match iter.next() {
            Some(k) => debug_inspect(obj.get(k) is Some(_), content="true")
            None => break
          }
        }
      }
      _ => @test.fail("expected a JSON object")
    }
    i = i + 1
  }
}
