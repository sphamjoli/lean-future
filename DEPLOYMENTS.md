# Deployments, toolchains and running

Everything needed to build, test, check and contribute.

## Toolchains

Rust is pinned by `rust-toolchain.toml` at the repository root (currently 1.97.1); rustup installs it automatically on first use. Lean is pinned by `lean/lean-toolchain` (currently v4.36.0); elan installs it automatically on first use.

```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
```

```bash
curl -sSfL https://raw.githubusercontent.com/leanprover/elan/master/elan-init.sh | sh
```

## Building and checking the Lean specification

```bash
cd lean && lake build
```

The build prints the axioms that each headline theorem depends on. To fail on any unfinished proof or any axiom beyond Lean's three standard axioms (propositional extensionality, quotient soundness and choice) (as CI does):

```bash
cd lean && lake build > ../target/lean-build.log 2>&1; ../scripts/checkTrustBase.sh ../target/lean-build.log
```

## Running the Rust witnesses

```bash
cargo test --workspace
```

```bash
cargo clippy --workspace --all-targets -- -D warnings
```

## Checking the claim catalogue

```bash
cargo run -p spec-lint
```

## Git hooks

The hooks use lefthook. Pre-commit runs rustfmt and validates Markdown wrapping, YAML, TOML, shell scripts and workflows. Commit-msg enforces the conventional-commit format. Pre-push runs clippy, the tests, the catalogue lint and the Lean build with its trust-base check.

```bash
brew install lefthook actionlint
```

```bash
lefthook install
```

The Markdown-wrap and commit-message checks need bun or node and skip with a warning if neither is found. The YAML check needs ruby; the TOML check needs python 3.11 or later and skips without it. An equivalent pre-commit configuration is provided for anyone who prefers that tool:

```bash
pre-commit install
```

## Commit and pull-request conventions

Pull-request (PR) branches are named `spha/<topic>`. Commit messages and PR titles use the form `type(scope): subject`, kept short. Types are `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`, `ci`, `perf` and `revert`. Scopes (optional) are `spec`, `lean`, `witnesses`, `recorder`, `lint`, `docs`, `ci` and `deps`. Write one Markdown paragraph per line, and put comments on their own line above the code they describe, never trailing it.

## Continuous integration

On every push to main and every pull request, CI runs rustfmt; clippy and the witness suite; the Lean build with the trust-base check; the catalogue lint; and rustdoc with warnings treated as errors. A summary job fails the run if any of these fail. A separate PR workflow scans for secrets with gitleaks, checks the PR title and applies path-based labels, then posts one summary comment. A labels workflow syncs the repository's labels from the checked-in definition, and Dependabot keeps the pinned GitHub Actions up to date.

## Re-pinning to a new Rust release

Update the Rust toolchain pin and the release recorded in the claim catalogue, re-read the Future, Waker, Poll and Pin documentation for that release, update every catalogue source link, and treat any change in wording as a possible change of claim kind before touching the Lean model.
