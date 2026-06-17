// Benchmark tests for IndexMap and IndexSet.
// These tests measure performance characteristics under various workloads.

///|
test "bench insert 1000 int keys" {
  let map = @aurasuisui/indexmap.new()
  let mut i = 0
  while i < 1000 {
    map.insert(i, i * 2) |> ignore
    i = i + 1
  }
  inspect(map.len(), content="1000")
  inspect(map.capacity() >= 1024, content="true")
  // Verify a sample to ensure correctness
  inspect(map.get(0), content="Some(0)")
  inspect(map.get(500), content="Some(1000)")
  inspect(map.get(999), content="Some(1998)")
}

///|
test "bench insert 5000 int keys" {
  let map = @aurasuisui/indexmap.with_capacity(1024)
  let mut i = 0
  while i < 5000 {
    map.insert(i, i * 3) |> ignore
    i = i + 1
  }
  inspect(map.len(), content="5000")
  inspect(map.get(0), content="Some(0)")
  inspect(map.get(4999), content="Some(14997)")
}

///|
test "bench insert 10000 int keys" {
  let map = @aurasuisui/indexmap.with_capacity(4096)
  let mut i = 0
  while i < 10000 {
    map.insert(i, i) |> ignore
    i = i + 1
  }
  inspect(map.len(), content="10000")
  let mut j = 0
  while j < 10000 {
    match map.get(j) {
      Some(_) => ()
      None => @test.fail("missing key in 10000 insert")
    }
    j = j + 1000
  }
}

///|
test "bench lookup 5000 keys" {
  let map = @aurasuisui/indexmap.with_capacity(8192)
  let mut i = 0
  while i < 5000 {
    map.insert(i, i * 10) |> ignore
    i = i + 1
  }
  let mut found = 0
  let mut j = 0
  while j < 5000 {
    match map.get(j) {
      Some(_) => found = found + 1
      None => ()
    }
    j = j + 1
  }
  inspect(found, content="5000")
}

///|
test "bench lookup missing keys" {
  let map = @aurasuisui/indexmap.with_capacity(1024)
  let mut i = 0
  while i < 500 {
    map.insert(i, i) |> ignore
    i = i + 1
  }
  let mut miss = 0
  let mut j = 1000
  while j < 2000 {
    if !map.contains(j) {
      miss = miss + 1
    }
    j = j + 1
  }
  inspect(miss, content="1000")
}

///|
test "bench iteration 5000 elements" {
  let map = @aurasuisui/indexmap.with_capacity(8192)
  let mut i = 0
  while i < 5000 {
    map.insert(i, i) |> ignore
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
  inspect(count, content="5000")
}

///|
test "bench keys iteration 5000" {
  let map = @aurasuisui/indexmap.with_capacity(8192)
  let mut i = 0
  while i < 5000 {
    map.insert(i, i) |> ignore
    i = i + 1
  }
  let keys_iter = map.keys()
  let mut kcount = 0
  while true {
    match keys_iter.next() {
      Some(_) => kcount = kcount + 1
      None => break
    }
  }
  inspect(kcount, content="5000")
}

///|
test "bench values iteration 5000" {
  let map = @aurasuisui/indexmap.with_capacity(8192)
  let mut i = 0
  while i < 5000 {
    map.insert(i, i * 10) |> ignore
    i = i + 1
  }
  let vals_iter = map.values()
  let mut vcount = 0
  while true {
    match vals_iter.next() {
      Some(_) => vcount = vcount + 1
      None => break
    }
  }
  inspect(vcount, content="5000")
}

///|
test "bench delete 2000 of 3000" {
  let map = @aurasuisui/indexmap.with_capacity(4096)
  let mut i = 0
  while i < 3000 {
    map.insert(i, i) |> ignore
    i = i + 1
  }
  let mut j = 0
  while j < 2000 {
    map.remove(j) |> ignore
    j = j + 1
  }
  inspect(map.len(), content="1000")
  inspect(map.contains(2999), content="true")
  inspect(map.contains(0), content="false")
}

///|
test "bench delete all 1000 one by one" {
  let map = @aurasuisui/indexmap.with_capacity(2048)
  let mut i = 0
  while i < 1000 {
    map.insert(i, i) |> ignore
    i = i + 1
  }
  let mut j = 0
  while j < 1000 {
    map.remove(j) |> ignore
    j = j + 1
  }
  inspect(map.is_empty(), content="true")
}

///|
test "bench mixed insert and delete" {
  let map = @aurasuisui/indexmap.with_capacity(1024)
  let mut i = 0
  while i < 500 {
    map.insert(i, i) |> ignore
    i = i + 1
  }
  let mut j = 0
  while j < 250 {
    map.remove(j * 2) |> ignore
    j = j + 1
  }
  let mut k = 0
  while k < 250 {
    map.insert(k * 2 + 1000, k) |> ignore
    k = k + 1
  }
  inspect(map.len(), content="500")
  // Verify remaining odd keys
  let mut l = 0
  let mut odds = 0
  while l < 500 {
    if map.contains(l) {
      odds = odds + 1
    }
    l = l + 1
  }
  inspect(odds, content="250")
}

///|
test "bench retain large map" {
  let map = @aurasuisui/indexmap.with_capacity(4096)
  let mut i = 0
  while i < 2000 {
    map.insert(i, i) |> ignore
    i = i + 1
  }
  map.retain(fn(_k, v) { v % 2 == 0 })
  inspect(map.len(), content="1000")
  inspect(map.contains(0), content="true")
  inspect(map.contains(1), content="false")
  inspect(map.contains(1998), content="true")
}

///|
test "bench sort_by_key large map" {
  let map = @aurasuisui/indexmap.with_capacity(2048)
  let mut i = 999
  while i >= 0 {
    map.insert(i, i * 2) |> ignore
    i = i - 1
  }
  map.sort_by_key()
  let entries = map.iter().collect()
  inspect(entries[0], content="(0, 0)")
  inspect(entries[500], content="(500, 1000)")
  inspect(entries[999], content="(999, 1998)")
}

///|
test "bench different initial capacities small" {
  let map = @aurasuisui/indexmap.with_capacity(4)
  map.insert("a", 1) |> ignore
  map.insert("b", 2) |> ignore
  inspect(map.len(), content="2")
  inspect(map.get("a"), content="Some(1)")
}

///|
test "bench different initial capacities large" {
  let map = @aurasuisui/indexmap.with_capacity(16384)
  let mut i = 0
  while i < 1000 {
    map.insert(i, i) |> ignore
    i = i + 1
  }
  inspect(map.len(), content="1000")
  // Large initial capacity should avoid resize
  inspect(map.capacity(), content="16384")
}

///|
test "bench extend large batch" {
  let map = @aurasuisui/indexmap.new()
  let entries = []
  let mut i = 0
  while i < 1000 {
    entries.push((i, i * 10))
    i = i + 1
  }
  map.extend(entries)
  inspect(map.len(), content="1000")
  inspect(map.get(0), content="Some(0)")
  inspect(map.get(999), content="Some(9990)")
}

///|
test "bench drain large map" {
  let map = @aurasuisui/indexmap.with_capacity(2048)
  let mut i = 0
  while i < 1000 {
    map.insert(i, i) |> ignore
    i = i + 1
  }
  let drained = map.drain()
  inspect(drained.length(), content="1000")
  inspect(map.is_empty(), content="true")
}

///|
test "bench clear and reuse" {
  let map = @aurasuisui/indexmap.with_capacity(1024)
  let mut round = 0
  while round < 10 {
    let mut i = 0
    while i < 100 {
      map.insert(i, i * round) |> ignore
      i = i + 1
    }
    inspect(map.len(), content="100")
    map.clear()
    round = round + 1
  }
  inspect(map.is_empty(), content="true")
}

///|
test "bench string keys 2000" {
  let map = @aurasuisui/indexmap.with_capacity(2048)
  let mut i = 0
  while i < 2000 {
    map.insert(i.to_string(), i) |> ignore
    i = i + 1
  }
  inspect(map.len(), content="2000")
  inspect(map.get("0"), content="Some(0)")
  inspect(map.get("1999"), content="Some(1999)")
}

///|
test "bench IndexSet large" {
  let set = @aurasuisui/indexmap.IndexSet::with_capacity(4096)
  let mut i = 0
  while i < 5000 {
    set.insert(i) |> ignore
    i = i + 1
  }
  inspect(set.len(), content="5000")
  let mut j = 0
  while j < 5000 {
    if !set.contains(j) {
      @test.fail("missing element in set")
    }
    j = j + 500
  }
}

///|
test "bench IndexSet remove all" {
  let set = @aurasuisui/indexmap.IndexSet::with_capacity(2048)
  let mut i = 0
  while i < 2000 {
    set.insert(i) |> ignore
    i = i + 1
  }
  let mut j = 0
  while j < 2000 {
    set.remove(j) |> ignore
    j = j + 1
  }
  inspect(set.is_empty(), content="true")
}

///|
test "bench for_each large" {
  let map = @aurasuisui/indexmap.with_capacity(4096)
  let mut i = 0
  while i < 3000 {
    map.insert(i, i * 2) |> ignore
    i = i + 1
  }
  let mut sum = 0
  map.for_each(fn(_k, v) { sum = sum + v })
  // Sum of 0..2999 * 2 = (2999 * 3000) = 8,997,000
  inspect(sum, content="8997000")
}

///|
test "bench swap_remove many" {
  let map = @aurasuisui/indexmap.with_capacity(1024)
  let mut i = 0
  while i < 500 {
    map.insert(i, i) |> ignore
    i = i + 1
  }
  let mut j = 0
  while j < 100 {
    map.swap_remove_index(0) |> ignore
    j = j + 1
  }
  inspect(map.len(), content="400")
}

///|
test "bench reserve then fill" {
  let map = @aurasuisui/indexmap.new()
  map.reserve(2000)
  let cap = map.capacity()
  inspect(cap >= 2000, content="true")
  let mut i = 0
  while i < 2000 {
    map.insert(i, i) |> ignore
    i = i + 1
  }
  inspect(map.len(), content="2000")
}

///|
test "bench max_probe after many inserts" {
  let map = @aurasuisui/indexmap.with_capacity(16)
  let mut i = 0
  while i < 1000 {
    map.insert(i, i) |> ignore
    i = i + 1
  }
  let probe = map.max_probe()
  inspect(probe >= 0, content="true")
  inspect(probe < 20, content="true")
}

///|
test "bench load_factor after fill" {
  let map = @aurasuisui/indexmap.with_capacity(128)
  let mut i = 0
  while i < 80 {
    map.insert(i, i) |> ignore
    i = i + 1
  }
  let lf = map.load_factor()
  inspect(lf > 0.0, content="true")
  inspect(lf < 1.0, content="true")
}

///|
test "bench first and last on large map" {
  let map = @aurasuisui/indexmap.with_capacity(2048)
  let mut i = 0
  while i < 1000 {
    map.insert(i, i * 10) |> ignore
    i = i + 1
  }
  match map.first() {
    Some((k, v)) => {
      inspect(k, content="0")
      inspect(v, content="0")
    }
    None => @test.fail("expected first")
  }
  match map.last() {
    Some((k, v)) => {
      inspect(k, content="999")
      inspect(v, content="9990")
    }
    None => @test.fail("expected last")
  }
}

///|
test "bench get_index_of on large map" {
  let map = @aurasuisui/indexmap.with_capacity(2048)
  let mut i = 0
  while i < 1000 {
    map.insert(i, i) |> ignore
    i = i + 1
  }
  inspect(map.get_index_of(0), content="Some(0)")
  inspect(map.get_index_of(500), content="Some(500)")
  inspect(map.get_index_of(999), content="Some(999)")
}

///|
test "bench count_remaining on large iter" {
  let map = @aurasuisui/indexmap.with_capacity(4096)
  let mut i = 0
  while i < 2000 {
    map.insert(i, i) |> ignore
    i = i + 1
  }
  let iter = map.iter()
  inspect(iter.count_remaining(), content="2000")
}

///|
test "bench get_full on large map" {
  let map = @aurasuisui/indexmap.with_capacity(2048)
  let mut i = 0
  while i < 1000 {
    map.insert(i, i * 5) |> ignore
    i = i + 1
  }
  inspect(map.get_full(0), content="Some((0, 0))")
  inspect(map.get_full(999), content="Some((999, 4995))")
}

// ---------------------------------------------------------------------------
// Benchmark: IndexMap vs built-in Map comparison
// ---------------------------------------------------------------------------

///|
test "cmp: insert 5000 keys IndexMap vs Map" {
  let imap = @aurasuisui/indexmap.with_capacity(8192)
  let bmap : Map[Int, Int] = Map::new()
  let mut i = 0
  while i < 5000 {
    imap.insert(i, i * 2) |> ignore
    bmap[i] = i * 2
    i = i + 1
  }
  inspect(imap.len(), content="5000")
  inspect(bmap.size(), content="5000")
}

///|
test "cmp: lookup 2000 keys IndexMap vs Map" {
  let imap = @aurasuisui/indexmap.with_capacity(4096)
  let bmap : Map[Int, Int] = Map::new()
  let mut i = 0
  while i < 2000 {
    imap.insert(i, i * 3) |> ignore
    bmap[i] = i * 3
    i = i + 1
  }
  let mut found_imap = 0
  let mut found_bmap = 0
  let mut j = 0
  while j < 2000 {
    match imap.get(j) {
      Some(_) => found_imap = found_imap + 1
      None => ()
    }
    match bmap[j] {
      Some(_) => found_bmap = found_bmap + 1
      None => ()
    }
    j = j + 1
  }
  inspect(found_imap, content="2000")
  inspect(found_bmap, content="2000")
}

///|
test "cmp: remove 1000 keys IndexMap vs Map" {
  let imap = @aurasuisui/indexmap.with_capacity(2048)
  let bmap : Map[Int, Int] = Map::new()
  let mut i = 0
  while i < 2000 {
    imap.insert(i, i) |> ignore
    bmap[i] = i
    i = i + 1
  }
  let mut j = 0
  while j < 1000 {
    imap.remove(j) |> ignore
    bmap.remove(j) |> ignore
    j = j + 1
  }
  inspect(imap.len(), content="1000")
  inspect(bmap.size(), content="1000")
}

///|
test "cmp: iteration order IndexMap preserved, Map undefined" {
  let imap = @aurasuisui/indexmap.new()
  imap.insert("c", 3) |> ignore
  imap.insert("a", 1) |> ignore
  imap.insert("b", 2) |> ignore
  // IndexMap: order is c, a, b (insertion order)
  let imap_entries = imap.iter().collect()
  inspect(imap_entries[0].0, content="c")
  inspect(imap_entries[1].0, content="a")
  inspect(imap_entries[2].0, content="b")
  // Built-in Map makes no guarantee about iteration order
}

///|
test "cmp: IndexMap provides index access, Map does not" {
  let imap = @aurasuisui/indexmap.new()
  imap.insert("first", 1) |> ignore
  imap.insert("second", 2) |> ignore
  imap.insert("third", 3) |> ignore
  // IndexMap: access by position
  inspect(imap.get_index(0), content="Some((first, 1))")
  inspect(imap.get_index(1), content="Some((second, 2))")
  inspect(imap.get_index(2), content="Some((third, 3))")
  // Built-in Map: no index-based access
}

///|
test "cmp: 10000 insert-delete mixed workload" {
  let imap = @aurasuisui/indexmap.with_capacity(16384)
  // Insert 0..9999
  let mut i = 0
  while i < 10000 {
    imap.insert(i, i * 10) |> ignore
    i = i + 1
  }
  inspect(imap.len(), content="10000")
  // Delete even numbers
  let mut j = 0
  while j < 10000 {
    if j % 2 == 0 {
      imap.remove(j) |> ignore
    }
    j = j + 1
  }
  inspect(imap.len(), content="5000")
  // Verify remaining odd keys exist
  let mut k = 1
  while k < 10000 {
    inspect(imap.contains(k), content="true")
    k = k + 2
  }
}
