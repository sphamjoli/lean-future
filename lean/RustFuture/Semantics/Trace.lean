import RustFuture.Semantics.Poll
import RustFuture.Semantics.Waker
/-! Observable events and (infinite) traces.

Choices made here:
* `pollBegin`/`pollReturn` are split so that a wake can occur *during* a poll.
* `undefinedBehaviour` is a label that conforming traces must never contain
  (`Contracts.NoUB`); it is not something the model "permits".
* Traces are `Nat → Event`, i.e. infinite, so liveness is expressible and
  divergence is not hidden. A finished execution idles on `.internal`. -/
namespace RustFuture

inductive Event (α : Type) where
  | pollBegin (call : CallId) (waker : WakerId)
  | pollReturn (call : CallId) (result : Poll α)
  | wake (waker : WakerId)
  | taskPollBegin (task : TaskId)
  | external
  | panic (call : CallId)
  | abort
  | undefinedBehaviour
  | drop
  | internal
  deriving DecidableEq, Repr

abbrev Trace (α : Type) := Nat → Event α

def ReadyAt {α : Type} (t : Trace α) (i : Nat) : Prop :=
  ∃ c v, t i = .pollReturn c (.ready v)

def PollBeginAt {α : Type} (t : Trace α) (i : Nat) : Prop :=
  ∃ c w, t i = .pollBegin c w

def EventuallyReady {α : Type} (t : Trace α) : Prop := ∃ i, ReadyAt t i

end RustFuture
