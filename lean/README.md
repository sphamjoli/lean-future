# The Lean specification

The model as Lean definitions and theorems. It uses only Lean's core library and declares no axioms of its own.

## Layers

| Layer | What it contains |
|---|---|
| Rust semantics | Exclusive access, pin validity and memory invariants, as preconditions left abstract, to be proved by a separate memory model. Unpin types are exempt from pin restrictions |
| Semantics | Well-formed executions (matched visits, no overlap, nothing after a terminal event), poll results, waker and task identities, contexts, events, infinite traces, and the future as a labelled transition system whose step is a relation |
| Contracts | The assumptions bundle; memory safety and protocol conformance as separate definitions; waker equivalence and polling epochs; the future contract (no undefined behaviour, latest waker), the caller's protocol (no poll after Ready), the executor contract (conditional wake delivery, with liveness and ordering owned by the executor model) and the environment (progress opportunity, defined without reference to wakes) |
| Properties | Safety, the no-lost-wakeup invariant, cancellation safety, and refinement together with the general verification-transfer theorem |
| Implementations | Models of the pending, ready, self-waking and oneshot futures |
| Counterexamples | Termination is not universal; the latest-waker clause rejects a stale-only wake and accepts a newest-waker wake; a stale-waker state breaks the no-lost-wakeup invariant |
| Theorems | An axiom audit of every headline result, and the vocabulary for compositional verification |

## All assumptions in one place

Every assumption is bundled in one structure, and the promises a future owes are bundled in another. A future conforms when every run that meets the assumptions also meets the promises. None of these are Lean axioms, so the axiom audit stays clean, and a proof shows the bundle is consistent.

## Proved, stated and open

Proved, using core axioms only: the verification-transfer theorem; every run of the pending model is free of undefined behaviour and never Ready, and such a run exists; the latest-waker clause rejects a wake of only a waker for a different task, accepts a wake of the newest waker, and accepts a wake of an older waker for the same task; the canonical pending run is well formed; wake delivery rejects a live wake with no later poll; the progress obligation never fires when progress never becomes possible; the no-lost-wakeup invariant is refutable; and the assumptions and promises are jointly satisfiable.

Stated but not proved: the no-lost-wakeup invariant for the correct oneshot, cancellation safety, and the conditions under which composition is sound.

Open: reachability of the faulty oneshot state from its own transition system, proof that the correct sender always discharges what it owes, deriving happens-before from program order and synchronisation, accounting for finite (terminated or stuck) executions, the requirement that polls return promptly, a concrete executor model, and the refinement bridge from Rust code.
