# Contributing to NanoAI

Thanks for your interest in contributing! NanoAI is an open-source hybrid AI runtime written in Rust.

## Development Setup

1. Install Rust 1.75+: https://rustup.rs
2. Install CMake 3.24+: https://cmake.org
3. Clone with submodules: `git clone --recursive https://github.com/nanoai/nanortime.git`
4. Build: `cargo build`
5. Test: `cargo test --all`

## Code Style

- Follow the official Rust style guide
- Run `cargo fmt` before committing
- Run `cargo clippy -- -D warnings` and fix all issues
- Use `thiserror` for domain errors, `anyhow` for application errors
- Prefer `const` over `static`, `&str` over `String` in function params
- Document public APIs with `///` doc comments

## Commit Convention

We use [Conventional Commits](https://www.conventionalcommits.org/):

```
feat(router): implement hybrid routing with entropy check
fix(memory): correct KV-cache eviction policy
docs(readme): add installation instructions
test(tool-executor): add unit tests for HTTP execution
refactor(config): extract manifest loading to separate module
chore(ci): update GitHub Actions to v4
```

## Pull Request Process

1. Fork the repo and create a feature branch
2. Make your changes with tests
3. Ensure all tests pass: `cargo test --all`
4. Ensure formatting: `cargo fmt --all -- --check`
5. Ensure linting: `cargo clippy --all-targets -- -D warnings`
6. Submit a PR with a clear description

## Architecture Guidelines

- **Core crate** (`nanortime-core`): Business logic only. No platform-specific code.
- **FFI crate** (`nanortime-ffi`): C/C++ bridge. Thin wrapper over llama.cpp.
- **CLI crate** (`nanortime-cli`): User interface. No business logic.

When adding features:
- Orchestrator logic goes in `orchestrator/`
- Model logic goes in `execution/model_manager.rs`
- Inference logic goes in `inference/`
- New error types go in `error.rs`
- Configuration schema goes in `config/manifest.rs`

## Testing

- Unit tests: `#[cfg(test)]` modules alongside the code
- Integration tests: `tests/` directory
- Benchmarks: `benches/` directory

Every new feature must include tests. Bug fixes must include a regression test.

## Questions?

Open an issue on GitHub or start a discussion.
