// Copyright (c) 2024-2026 moonbit-indexmap contributors
// SPDX-License-Identifier: Apache-2.0

// Larger-N correctness + IndexMap-vs-builtin-Map comparison tests.
//
// Despite the historical `bench_*` names, these contain NO timing — they are
// correctness tests at 1k–10k scale (the real statistical benchmarks live in
// `perf_bench_test.mbt`, run by `moon bench`). What's genuinely UNIQUE here and
// not subsumed by `model_wbtest.mbt` / `indexmap-test-suite` is:
//   - the 6 `cmp:` tests: IndexMap vs the built-in `Map` on the same workload;
//   - `cmp: max_probe after many inserts`: the benign-key probe-distance bound.
// The former pure-scale `bench_*` correctness tests were dropped (the model /
// fuzz streams and the test-suite's stress tests already cover scale).

// ---------------------------------------------------------------------------
// Robin Hood probe-distance bound (benign sequential-int keys)
// ---------------------------------------------------------------------------

///|
test "cmp: max_probe after many inserts" {
  let map = @aurasuisui/indexmap.with_capacity(16)
  let mut i = 0
  while i < 1000 {
    map.insert(i, i) |> ignore
    i = i + 1
  }
  let probe = map.max_probe()
  debug_inspect(probe >= 0, content="true")
  // With well-distributed sequential int keys and Robin Hood equalization, max
  // probe stays a small constant. This is the benign-key baseline against which
  // the adversarial (total-collision) tests in `adversarial_test.mbt` degrade.
  debug_inspect(probe < 20, content="true")
}

// ---------------------------------------------------------------------------
// IndexMap vs built-in Map (same-workload parity checks)
// ---------------------------------------------------------------------------

///|
test "cmp: insert 5000 keys IndexMap vs Map" {
  let imap = @aurasuisui/indexmap.with_capacity(8192)
  let bmap : Map[Int, Int] = Map([])
  let mut i = 0
  while i < 5000 {
    imap.insert(i, i * 2) |> ignore
    bmap[i] = i * 2
    i = i + 1
  }
  debug_inspect(imap.len(), content="5000")
  debug_inspect(bmap.length(), content="5000")
}

///|
test "cmp: lookup 2000 keys IndexMap vs Map" {
  let imap = @aurasuisui/indexmap.with_capacity(4096)
  let bmap : Map[Int, Int] = Map([])
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
    match bmap.get(j) {
      Some(_) => found_bmap = found_bmap + 1
      None => ()
    }
    j = j + 1
  }
  debug_inspect(found_imap, content="2000")
  debug_inspect(found_bmap, content="2000")
}

///|
test "cmp: remove 1000 keys IndexMap vs Map" {
  let imap = @aurasuisui/indexmap.with_capacity(2048)
  let bmap : Map[Int, Int] = Map([])
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
  debug_inspect(imap.len(), content="1000")
  debug_inspect(bmap.length(), content="1000")
}

///|
test "cmp: iteration order IndexMap preserved, Map undefined" {
  let imap = @aurasuisui/indexmap.new()
  imap.insert("c", 3) |> ignore
  imap.insert("a", 1) |> ignore
  imap.insert("b", 2) |> ignore
  // IndexMap: order is c, a, b (insertion order)
  let imap_entries = imap.iter().collect()
  debug_inspect(
    imap_entries[0].0,
    content=(
      #|"c"
    ),
  )
  debug_inspect(
    imap_entries[1].0,
    content=(
      #|"a"
    ),
  )
  debug_inspect(
    imap_entries[2].0,
    content=(
      #|"b"
    ),
  )
  // Built-in Map makes no guarantee about iteration order
}

///|
test "cmp: IndexMap provides index access, Map does not" {
  let imap = @aurasuisui/indexmap.new()
  imap.insert("first", 1) |> ignore
  imap.insert("second", 2) |> ignore
  imap.insert("third", 3) |> ignore
  // IndexMap: access by position
  debug_inspect(
    imap.get_index(0),
    content=(
      #|Some(("first", 1))
    ),
  )
  debug_inspect(
    imap.get_index(1),
    content=(
      #|Some(("second", 2))
    ),
  )
  debug_inspect(
    imap.get_index(2),
    content=(
      #|Some(("third", 3))
    ),
  )
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
  debug_inspect(imap.len(), content="10000")
  // Delete even numbers
  let mut j = 0
  while j < 10000 {
    if j % 2 == 0 {
      imap.remove(j) |> ignore
    }
    j = j + 1
  }
  debug_inspect(imap.len(), content="5000")
  // Verify remaining odd keys exist
  let mut k = 1
  while k < 10000 {
    debug_inspect(imap.contains(k), content="true")
    k = k + 2
  }
}
