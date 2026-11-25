# The Lean specification

The model as Lean definitions and theorems. It uses only Lean's core library and declares no axioms of its own.

## Layers

| Layer | What it contains |
|---|---|
| Rust semantics | Exclusive access, pin validity and memory invariants, as preconditions left abstract, to be proved by a separate memory model. Unpin types are exempt from pin restrictions |
| Semantics | Well-formed executions (unique visits, no overlap, no drop during a visit, nothing after drop or abort), poll results, waker and task identities, contexts, events, infinite traces, and the future as a labelled transition system whose step is a relation |
| Contracts | The assumptions bundle; memory safety and protocol conformance as separate definitions; waker equivalence and polling epochs; the future contract (no undefined behaviour, latest waker), the caller's protocol (no poll after Ready), the executor contract (conditional wake delivery, with liveness and ordering owned by the executor model) and the environment (progress opportunity, defined without reference to wakes) |
| Properties | Safety, the no-lost-wakeup invariant, cancellation safety, and refinement together with the general verification-transfer theorem |
| Implementations | Models of the pending, ready and self-waking futures, and concrete transition semantics for the correct and faulty oneshot receivers with their sender |
| Counterexamples | Termination is not universal; the latest-waker clause rejects a stale-only wake and accepts a newest-waker wake; the faulty oneshot receiver reaches a state that breaks the no-lost-wakeup invariant |
| Theorems | A trust-base check of every headline result, and the vocabulary for compositional verification |

## All assumptions in one place

Every assumption is bundled in one structure, and the promises a future owes are bundled in another. A future conforms when every run that meets the assumptions also meets the promises. None of these are Lean axioms, so the trust-base check stays clean, and a proof shows the bundle is consistent.

## Proved, stated and open

Proved, using core axioms only: the verification-transfer theorem; every run of the pending model is free of undefined behaviour and never Ready, and such a run exists; the latest-waker clause rejects a wake of only a waker for a different task, accepts a wake of the newest waker, and accepts a wake of an older waker for the same task; the canonical pending run is well formed; a future polled for ever that never wakes breaks the progress rule, so a busy executor cannot hide it; dropping a suspended future discharges its obligation; wake delivery rejects a live wake with no later poll; the progress obligation never fires when progress never becomes possible; the faulty oneshot receiver reaches a lost-wake-up state by an actual execution; the correct oneshot receiver keeps the no-lost-wakeup invariant in every reachable state; on every run where the sender eventually makes the wake it owes, the correct receiver's latest waker is woken or it completes; and such a fair run, with a wake owed, exists; and the assumptions and promises are jointly satisfiable.

Stated but not proved: cancellation safety, and the conditions under which composition is sound.

Open: linking the oneshot machine to the trace-based rules and to compiled Rust, deriving happens-before from program order and synchronisation, accounting for finite (terminated or stuck) executions, the requirement that polls return promptly, a concrete executor model, and the refinement bridge from Rust code.
