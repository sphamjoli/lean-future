import RustFuture.Semantics.Future
/-! The `Future` behavioural contract: clauses only, each traced in the claim catalogue.
None of these is a Lean `axiom`; they are predicates an implementation must satisfy.

Scope: every predicate here is stated over the trace of a single future (a
per-future projection). In a shared trace, wakes issued by other futures would
otherwise be attributed to this one. -/
namespace RustFuture.Contracts
open RustFuture

/-- Required of every implementation reachable through safe access. Conditioning
on valid access (`Rust.PinModel.ValidPoll` at each `pollBegin`) is open work. -/
def NoUB {α : Type} (t : Trace α) : Prop := ∀ i, t i ≠ .undefinedBehaviour

/-- Rule 2, placed on the caller: never poll after `Ready`.
Implementations may not assume more than this, so `Ready` is not absorbing. -/
def CallerStopsAtReady {α : Type} (t : Trace α) : Prop :=
  ∀ i, ReadyAt t i → ∀ j, i < j → ¬ PollBeginAt t j

/-- Index `i` is a `Pending` return of a poll that was given waker `w`. -/
def SuspendedWith {α : Type} (t : Trace α) (i : Nat) (w : WakerId) : Prop :=
  ∃ b c, b < i ∧ t b = .pollBegin c w ∧ t i = .pollReturn c .pending

/-- No poll begins strictly between `i` and `k`. -/
def NoPollBetween {α : Type} (t : Trace α) (i k : Nat) : Prop :=
  ∀ m c w, i < m → m < k → t m ≠ .pollBegin c w

/-- Latest-waker clause. If the future issues any wake while suspended (after a
`Pending` return and before the next poll), the waker of that most recent poll
is among those woken in the window. Waking older wakers as well is permitted
(it is a spurious wake). -/
def WakesLatest {α : Type} (t : Trace α) : Prop :=
  ∀ i w, SuspendedWith t i w →
    ∀ k w', i < k → NoPollBetween t i k → t k = .wake w' →
      ∃ k', i < k' ∧ NoPollBetween t i k' ∧ t k' = .wake w

end RustFuture.Contracts
