# future-witnesses

Real Rust futures that show where the line between permitted and required behaviour sits. Every future here compiles, uses only safe code, and never causes undefined behaviour. Each one exhibits a behaviour that some tempting axiom would forbid, so that axiom must stay out of the model.

## What each witness shows

| Witness | Behaviour | Statement it rules out |
|---|---|---|
| The standard pending future | Returns Pending forever | Every future eventually completes |
| The standard ready future | Completes on the first poll without touching its waker | Every future must use its waker |
| A self-waking future | Wakes itself, then returns Pending again after that wake | Wakes come only from outside, and a wake means the next poll is Ready |
| A once-only future | Panics when polled after completion | Ready is final and polling again is harmless |
| A failing async function | Completes with an error | Ready means success |
| A correct oneshot receiver | Checks for a value and registers the latest waker under one lock | Is the positive example for the no-lost-wakeup property |
| A faulty oneshot receiver | Registers its waker only on the first poll, so a later sender wakes a stale context | Deliberately breaks the latest-waker clause; the type system accepts it |

## Role in the system

The witnesses keep the specification in check. If the model is tightened until one of these behaviours can no longer be represented, the model has become stronger than Rust. The faulty receiver works in the other direction: the model must be strong enough to reject it.

Instructions for running the suite are in the repository's DEPLOYMENTS.md.
