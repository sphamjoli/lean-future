# trace-recorder

A single-task executor that drives a future and records what an observer would see, using the same event vocabulary as the Lean model: the executor starting a poll of the task, a poll beginning with its waker, a poll returning with its result, wakes, panics and the final drop.

## What it lets you vary

You can vary three things:

- the scheduling policy: poll only after a wake, or poll unconditionally (spurious polls are allowed);
- whether to keep polling after Ready, which deliberately breaks the caller's protocol so that post-completion behaviour can be observed;
- whether each poll gets a fresh waker, which exercises the latest-waker clause.

## What a recording is, and what it is not

A recording is a finite prefix of one concrete run. It can show that a behaviour exists, so it can refute a proposed axiom that forbids that behaviour, and it can catch a safety property failing. Because it is finite, it can neither prove nor disprove a liveness property, and it does not prove the model complete. It covers one thread only, so wakes arriving in the middle of a poll from another thread are not yet produced. Recordings can be exported as JSON so they can later be checked against the Lean transition relation.
