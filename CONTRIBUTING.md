# Contributing to moonbit-indexmap

Thanks for your interest in contributing!

## Getting Started

1. Install the [MoonBit toolchain](https://www.moonbitlang.com/download/)
2. Fork and clone the repository
3. Run `moon check && moon test` to verify everything works

## Development Workflow

```bash
# Format code
moon fmt

# Type check
moon check

# Run tests
moon test

# Run all checks
moon check && moon test && moon fmt --check
```

## Code Style

- Follow MoonBit's standard formatting (`moon fmt`)
- Use snake_case for functions, PascalCase for types
- Document public APIs with `///` doc comments
- Write tests in `test/*.mbt` using the `test` block syntax

## Pull Request Process

1. Create a feature branch from `main`
2. Make your changes with clear commit messages
3. Add tests for new functionality
4. Ensure `moon check && moon test` passes
5. Update documentation if needed
6. Submit a PR with a description of what changed and why

## Project Structure

```
src/
├── lib.mbt      # Public API and re-exports
├── map.mbt      # IndexMap core implementation
├── set.mbt      # IndexSet implementation
├── hash.mbt     # Hash utilities and constants
test/
├── map_test.mbt # IndexMap tests
└── set_test.mbt # IndexSet tests
```

## License

By contributing, you agree that your contributions will be licensed under the Apache 2.0 License.
