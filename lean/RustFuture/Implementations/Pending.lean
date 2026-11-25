import RustFuture.Contracts.Future
/-! Model of `std::future::pending()`: every poll returns `Pending`, and no step
is undefined behaviour. The link to the standard library is empirical (a Rust
witness test), not a refinement proof. -/
namespace RustFuture.Implementations
open RustFuture

def pendingModel (α : Type) : FutureModel Unit α where
  initial _ := True
  step _ e _ := e ≠ .undefinedBehaviour ∧ ∀ c v, e ≠ .pollReturn c (.ready v)

/-- Every run of the model is UB-free and never `Ready`. -/
theorem pendingModel_all_runs (α : Type) (t : Trace α) (h : (pendingModel α).Traces t) :
    Contracts.NoUB t ∧ ¬ EventuallyReady t := by
  obtain ⟨s, _, hs⟩ := h
  exact ⟨fun i => (hs i).1, fun ⟨i, c, v, hi⟩ => (hs i).2 c v hi⟩

/-- A canonical infinite run: begin, return pending, begin, … -/
def pendingTrace (α : Type) : Trace α := fun n =>
  if n % 2 = 0 then .pollBegin (n / 2) 0 else .pollReturn (n / 2) .pending

theorem pendingTrace_is_run (α : Type) : (pendingModel α).Traces (pendingTrace α) := by
  refine ⟨fun _ => (), trivial, fun n => ⟨?_, fun c v h => ?_⟩⟩
  · intro h; unfold pendingTrace at h; split at h <;> simp at h
  · unfold pendingTrace at h; split at h <;> simp at h

end RustFuture.Implementations

namespace RustFuture.Implementations
open RustFuture

/-- Refutes "Pending implies an eventual wake": a run of the pending model that
returns `Pending` and contains no wake at all. -/
theorem pending_without_wake :
    (pendingModel Nat).Traces (pendingTrace Nat) ∧
      (∃ i c, pendingTrace Nat i = .pollReturn c .pending) ∧
      ∀ k w, pendingTrace Nat k ≠ .wake w := by
  refine ⟨pendingTrace_is_run Nat, ⟨1, 0, rfl⟩, fun k w h => ?_⟩
  unfold pendingTrace at h; split at h <;> simp at h

end RustFuture.Implementations
