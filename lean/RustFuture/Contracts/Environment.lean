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

/-- An obligation arises when a visit that began at `b` with waker `w` returns
`Pending` at `i`. It is active at position `j` while the epoch lasts (no new
visit has begun) and the future has not been dropped nor the program aborted. If progress is possible
and the future is still wanted at such a `j`, the obligation is met by a wake of
a waker equivalent to `w` anywhere in the epoch, including one issued during the
visit or already queued before `j`. Otherwise the epoch must end with a new
visit, which supersedes the obligation; if that visit also returns `Pending`, a
fresh obligation arises. A drop or abort ends the obligation. -/
def ProgressNotifies {σ α : Type} (W : WakerEnv) (E : EnvironmentModel σ) (s : Nat → σ)
    (t : Trace α) : Prop :=
  ∀ b i w, SuspendedFrom t b i w →
    ∀ j, i < j → NoPollBetween t i j → (∀ m, i < m → m ≤ j → ¬ TerminalAt t m) →
      E.progressOpportunity (s j) → E.stillInterested (s j) →
        (∃ k w', b < k ∧ NoPollBetween t i k ∧ t k = .wake w' ∧ WakeEquivalent W w' w) ∨
        (∃ k, j < k ∧ NoPollBetween t i k ∧ PollBeginAt t k)

/-- Satisfiable without any wake: if progress never becomes possible, the
obligation never fires. This is why `Pending → ◇wake` is not an axiom. -/
theorem progressNotifies_of_no_progress {σ α : Type} (W : WakerEnv) (E : EnvironmentModel σ)
    (s : Nat → σ) (t : Trace α) (h : ∀ j, ¬ E.progressOpportunity (s j)) :
    ProgressNotifies W E s t :=
  fun _ _ _ _ j _ _ _ hp _ => absurd hp (h j)

end RustFuture.Contracts
