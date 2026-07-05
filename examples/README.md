# Examples

The files in this directory are **copy-paste snippets** — they illustrate common
usage patterns but are not a runnable MoonBit package (no `moon.pkg`, not covered
by CI).

| File | What it demonstrates |
|------|---------------------|
| [`lru_cache.mbt`](lru_cache.mbt) | Fixed-capacity LRU cache built on `IndexMap`, using `first()` to find the least-recently-used entry |
| [`config_parse.mbt`](config_parse.mbt) | Order-preserving `key=value` config parser using the Entry API (`OccupiedEntry` / `VacantEntry`) |
| [`json_order.mbt`](json_order.mbt) | JSON serialization via `ToJson` that preserves key insertion order |

## How to use

1. Copy the snippet into your MoonBit project
2. Add `import { "aurasuisui/indexmap" }` to your `moon.pkg`
3. Replace the placeholder logic with your own

## Runnable example

For a runnable LRU cache example with its own `moon.pkg` and `main.mbt`, see
[indexmap-test-suite/cmd/lru_cache/](https://github.com/aurasuisui/indexmap-test-suite/tree/main/cmd/lru_cache).
