# Contributing to moonbit-indexmap

## Getting Started

1. Install [MoonBit](https://www.moonbitlang.com/download/)
2. Clone: `git clone https://github.com/aurasuisui/moonbit-indexmap`
3. Verify: `moon check && moon test`

## Commands

```bash
moon fmt      # Format code
moon check    # Type check
moon test     # Run 220 tests
```

## Project Layout

```
src/
├── lib.mbt           # Public API entry points
├── map.mbt           # IndexMap[K, V] core (~1171 lines)
├── set.mbt           # IndexSet[K] wrapper (~278 lines)
├── hash.mbt          # Hash utilities and constants
├── map_test.mbt      # IndexMap black-box tests (~1334 lines)
├── set_test.mbt      # IndexSet black-box tests (~533 lines)
├── bench_test.mbt    # Benchmark tests
├── property_test.mbt # Property/invariant tests
└── moon.pkg.json     # Package configuration
```

## Style

- MoonBit standard formatting (`moon fmt`)
- snake_case functions, PascalCase types, UPPER_CASE constants
- Documentation: `///|` doc comments on public APIs

## License

Apache 2.0 — see [LICENSE](LICENSE).
