import RustFuture.Semantics.Future
/-! Rule 4: progress obligates notification.

Progress opportunity is a predicate on states supplied by the environment model
(for example, "the channel slot holds a value"). It is defined without any
reference to wakes, otherwise the rule would be circular. -/
namespace RustFuture.Contracts
open RustFuture

structure EnvironmentModel (σ : Type) where
  progressOpportunity : σ → Prop
  stillInterested : σ → Prop

/-- Over a run `(s, t)`: once the future has returned `Pending`, if progress
later becomes possible while the future is still wanted, then some wake or some
new poll eventually follows. A poll counts because a poll already in flight
will observe the progress itself. -/
def ProgressNotifies {σ α : Type} (E : EnvironmentModel σ) (s : Nat → σ) (t : Trace α) : Prop :=
  ∀ i c, t i = .pollReturn c .pending →
    ∀ j, i < j → E.progressOpportunity (s j) → E.stillInterested (s j) →
      ∃ k, j ≤ k ∧ ((∃ w, t k = .wake w) ∨ PollBeginAt t k)

/-- Satisfiable without any wake: if progress never becomes possible, the
obligation never fires. This is why `Pending → ◇wake` is not an axiom. -/
theorem progressNotifies_of_no_progress {σ α : Type} (E : EnvironmentModel σ) (s : Nat → σ)
    (t : Trace α) (h : ∀ j, ¬ E.progressOpportunity (s j)) : ProgressNotifies E s t :=
  fun _ _ _ j _ hp _ => absurd hp (h j)

end RustFuture.Contracts
