// Copyright (c) 2024-2026 moonbit-indexmap contributors
// SPDX-License-Identifier: Apache-2.0

// Fuzzing (RELEASE_TEST_CHECKLIST Tier 1 "fuzzing: byte-stream / op-stream fuzz
// the mutation paths"). MoonBit has no coverage-guided fuzzer, so this is a
// hand-rolled, deterministic fuzz harness that deliberately SHARES the model
// test's `Op` interpreter and naive-array oracle (model_wbtest.mbt, same
// package): the same machinery that proves step-by-step model agreement is
// driven here at higher volume and seed diversity.
//
// Two flavors:
//   1. seed-sweep op-stream fuzz — many LCG seeds x a long op stream, oracle +
//      invariant agreement checked throughout;
//   2. decoded int-stream fuzz — random integers decoded into ops (opcode +
//      operands from bit fields), the "structure-aware byte-stream" flavor.
//
// Deterministic: `@quickcheck.samples` uses a fixed seed, and the LCG streams
// are seeded by index, so failures reproduce exactly.

// ---------------------------------------------------------------------------
// 1. Seed-sweep op-stream fuzz
// ---------------------------------------------------------------------------

///|
test "fuzz: sweep 60 LCG seeds x 1500 ops, oracle + invariants hold throughout" {
  let mut seed = 1
  while seed <= 60 {
    let m : IndexMap[Int, Int] = IndexMap::new()
    let oracle : Array[(Int, Int)] = []
    // spread the seeds so each stream diverges quickly
    let mut state = (seed * 1_000_003) & 0x7FFF_FFFF
    let mut i = 0
    while i < 1500 {
      state = (state * 1103515245 + 12345) & 0x7FFF_FFFF
      apply_op(m, oracle, gen_op(state, state >> 6, state >> 14))
      i = i + 1
    }
    check_internal_invariants(m)
    seed = seed + 1
  }
}

// ---------------------------------------------------------------------------
// 2. Decoded int-stream ("byte-stream") fuzz
// ---------------------------------------------------------------------------

///|
/// Decode one integer into an op: low bits pick the opcode, higher bits supply
/// the key/value/index operands. This is the structure-aware analog of feeding
//  raw fuzz bytes to a parser.
fn decode_op(x : Int) -> Op {
  gen_op(x, x >> 5, x >> 13)
}

///|
test "fuzz: 150 decoded random int-streams agree with the oracle + invariants" {
  let cases : Array[Array[Int]] = @quickcheck.samples(150)
  let mut c = 0
  while c < cases.length() {
    let xs = cases[c]
    let m : IndexMap[Int, Int] = IndexMap::new()
    let oracle : Array[(Int, Int)] = []
    let mut i = 0
    while i < xs.length() {
      apply_op(m, oracle, decode_op(xs[i]))
      i = i + 1
    }
    check_internal_invariants(m)
    c = c + 1
  }
}
