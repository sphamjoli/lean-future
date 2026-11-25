import RustFuture.Contracts.Future
import RustFuture.Semantics.WellFormed
/-! Rule 4: progress obligates notification.

Progress opportunity is a predicate on states supplied by the environment model
(for example, "the channel slot holds a value"). It is defined without any
reference to wakes, otherwise the rule would be circular. -/
namespace RustFuture.Contracts
open RustFuture

structure EnvironmentModel (σ : Type) where
  progressOpportunity : σ → Prop
  stillInterested : σ → Prop

/-- The waker current at position `k`, from the point of view of the visit
that began at `b`: the waker of the most recent visit begun at or after `b` and
before `k`. -/
def CurrentWaker {α : Type} (t : Trace α) (b k : Nat) (v : WakerId) : Prop :=
  ∃ b' c', b ≤ b' ∧ b' < k ∧ t b' = .pollBegin c' v ∧ NoPollBetween t b' k

/-- A wake at `k` counts for the obligation of the visit that began at `b` when
it targets the same task as the waker current at `k`. If the future has been
re-polled with a new waker since `b`, only that newer waker's task counts, so a
wake of an out-of-date waker does not. -/
def CountingWake {α : Type} (W : WakerEnv) (t : Trace α) (b k : Nat) : Prop :=
  ∃ w' v, t k = .wake w' ∧ CurrentWaker t b k v ∧ WakeEquivalent W w' v

/-- An obligation arises when a visit that began at `b` with waker `w` returns
`Pending` at `i`, and becomes active at a position `j` in the same epoch (no new
visit has begun, nothing terminal has happened) where progress is possible and
the future is still wanted. It is then discharged only by one of three things,
at some position after `b`: a counting wake, the future finishing with `Ready`,
or the future being dropped or the program aborting.

A new poll does not discharge it. Re-polling is the executor's choice and says
nothing about whether the future arranged a notification, so a busy executor
cannot hide a future that never wakes. Whether the system as a whole makes
progress is a separate property.

Known weakness: *eventually* has no bound. A future that never arranges a
notification still passes on a run where, much later and for unrelated reasons,
a wake for its current task happens, it completes with `Ready`, or the program
aborts. Ruling that out needs a bound tied to the scheduling assumptions. -/
def ProgressNotifies {σ α : Type} (W : WakerEnv) (E : EnvironmentModel σ) (s : Nat → σ)
    (t : Trace α) : Prop :=
  ∀ b i w, SuspendedFrom t b i w →
    ∀ j, i < j → NoPollBetween t i j → (∀ m, i < m → m ≤ j → ¬ TerminalAt t m) →
      E.progressOpportunity (s j) → E.stillInterested (s j) →
        ∃ k, b < k ∧ (CountingWake W t b k ∨ ReadyAt t k ∨ TerminalAt t k)

/-- Satisfiable without any wake: if progress never becomes possible, the
obligation never fires. This is why `Pending → ◇wake` is not an axiom. -/
theorem progressNotifies_of_no_progress {σ α : Type} (W : WakerEnv) (E : EnvironmentModel σ)
    (s : Nat → σ) (t : Trace α) (h : ∀ j, ¬ E.progressOpportunity (s j)) :
    ProgressNotifies W E s t :=
  fun _ _ _ _ j _ _ _ hp _ => absurd hp (h j)

end RustFuture.Contracts
