## Summary

<!-- 1-3 bullet points describing what this PR does and why -->

## Type

- [ ] Specification change (claim added, reclassified, or reworded)
- [ ] Proof (a claim's status moves toward `proved`)
- [ ] Witness (new Rust future or trace)
- [ ] Chore (refactor, deps, CI, docs)

## Component

- [ ] Claim catalogue (`spec/`, `crates/spec-lint/`)
- [ ] Lean specification (`lean/`)
- [ ] Witnesses (`crates/future-witnesses/`, `crates/trace-recorder/`)
- [ ] Docs
- [ ] CI / infra

## Related issues

<!-- Closes #123, Relates to #456 -->

## Evidence

<!-- For every claim whose status changed: old status, new status, and the artefact that earns it (Lean declaration, witness test). -->

## Checklist

- [ ] Branch is named `spha/<topic>`
- [ ] Title follows `type(scope): description` (e.g. `feat(lean): state the latest-waker clause`)
- [ ] No claim status upgraded without the artefact that earns it
- [ ] No new Lean `axiom`, no `sorry`; `#print axioms` shows core axioms only
- [ ] Every rejected claim still has a passing Rust witness
- [ ] Every new contract clause cites the pinned Rust documentation
- [ ] Comments sit on their own line above code, never trailing it
- [ ] Toolchain commands from DEPLOYMENTS.md pass locally
