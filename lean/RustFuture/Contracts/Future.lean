import RustFuture.Semantics.Future
import RustFuture.Semantics.WellFormed
/-! The `Future` behavioural contract: clauses only, each traced in the claim catalogue.
None of these is a Lean `axiom`; they are predicates an implementation must satisfy.

Scope: every predicate here is stated over the trace of a single future (a
per-future projection). In a shared trace, wakes issued by other futures would
otherwise be attributed to this one. -/
namespace RustFuture.Contracts
open RustFuture

/-- Required of every implementation reachable through safe access, whatever
the caller or executor does. -/
def NoUB {α : Type} (t : Trace α) : Prop := ∀ i, t i ≠ .undefinedBehaviour

/-- Rule 2, placed on the caller: never poll after `Ready`.
Implementations may not assume more than this, so `Ready` is not absorbing. -/
def CallerStopsAtReady {α : Type} (t : Trace α) : Prop :=
  ∀ i, ReadyAt t i → ∀ j, i < j → ¬ PollBeginAt t j

/-- Two wakers are equivalent when they wake the same task. Rust lets a future
keep an older waker when `Waker::will_wake` says it targets the same task. -/
def WakeEquivalent (E : WakerEnv) (w₁ w₂ : WakerId) : Prop :=
  E.taskOf w₁ = E.taskOf w₂

/-- No visit begins strictly between `i` and `k`. -/
def NoPollBetween {α : Type} (t : Trace α) (i k : Nat) : Prop :=
  ∀ m c w, i < m → m < k → t m ≠ .pollBegin c w

/-- The visit that began at `b` with waker `w` ended with `Pending` at `i`, with
no other visit beginning and no earlier end of the same visit in between.
Positions after `b` and before the next visit form that visit's epoch. -/
def SuspendedFrom {α : Type} (t : Trace α) (b i : Nat) (w : WakerId) : Prop :=
  ∃ c, b < i ∧ t b = .pollBegin c w ∧ t i = .pollReturn c .pending ∧
    NoPollBetween t b i ∧ ∀ m, b < m → m < i → ¬ EndsAt t m c

/-- Latest-waker clause, per epoch. If any wake happens while the future is
suspended (after a `Pending` return and before the next visit), then some wake
in the same epoch, possibly issued during the visit itself, targets the same
task as the latest visit's waker. -/
def WakesLatest {α : Type} (E : WakerEnv) (t : Trace α) : Prop :=
  ∀ b i w, SuspendedFrom t b i w →
    ∀ k w', i < k → NoPollBetween t i k → t k = .wake w' →
      ∃ k' w'', b < k' ∧ NoPollBetween t i k' ∧ t k' = .wake w'' ∧ WakeEquivalent E w'' w

end RustFuture.Contracts
