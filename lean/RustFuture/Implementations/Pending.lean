import RustFuture.Contracts.Future
import RustFuture.Semantics.WellFormed
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

namespace RustFuture.Implementations
open RustFuture

theorem pendingTrace_even {α : Type} {n : Nat} (h : n % 2 = 0) :
    pendingTrace α n = .pollBegin (n / 2) 0 := by simp [pendingTrace, h]

theorem pendingTrace_odd {α : Type} {n : Nat} (h : n % 2 ≠ 0) :
    pendingTrace α n = .pollReturn (n / 2) .pending := by simp [pendingTrace, h]

theorem pendingTrace_begin {α : Type} {i c w : Nat} (h : pendingTrace α i = .pollBegin c w) :
    i % 2 = 0 ∧ c = i / 2 := by
  by_cases h2 : i % 2 = 0
  · rw [pendingTrace_even h2] at h; simp at h; exact ⟨h2, h.1.symm⟩
  · rw [pendingTrace_odd h2] at h; simp at h

theorem pendingTrace_ends {α : Type} {k c : Nat} (h : EndsAt (pendingTrace α) k c) :
    k % 2 ≠ 0 ∧ c = k / 2 := by
  rcases h with ⟨r, hr⟩ | hp
  · by_cases h2 : k % 2 = 0
    · rw [pendingTrace_even h2] at hr; simp at hr
    · rw [pendingTrace_odd h2] at hr; simp at hr; exact ⟨h2, hr.1.symm⟩
  · unfold pendingTrace at hp; split at hp <;> simp at hp

/-- The canonical pending run is well formed: visit numbers are unique, visits
never overlap, and nothing is dropped or aborted. -/
theorem pendingTrace_wellFormed (α : Type) : WellFormed (pendingTrace α) where
  uniqueCalls := by
    intro i j c w w' hi hj
    obtain ⟨hi2, rfl⟩ := pendingTrace_begin hi
    obtain ⟨hj2, hc⟩ := pendingTrace_begin hj
    omega
  noOverlap := by
    intro i c w j c' w' hij hi hj
    obtain ⟨hi2, rfl⟩ := pendingTrace_begin hi
    obtain ⟨hj2, -⟩ := pendingTrace_begin hj
    have hdiv : (i + 1) / 2 = i / 2 := by omega
    refine ⟨i + 1, i / 2, by omega, by omega, Or.inl ⟨.pending, ?_⟩⟩
    rw [pendingTrace_odd (by omega), hdiv]
  nothingAfterTerminal := by
    intro i hT
    exfalso
    rcases hT with h | h <;> (unfold pendingTrace at h; split at h <;> simp at h)

/-- Every return of the canonical pending run answers the visit just before it,
and each visit ends once. -/
theorem pendingTrace_callsMatched (α : Type) : CallsMatched (pendingTrace α) where
  endMatchesBegin := by
    intro k c hk
    obtain ⟨hk2, rfl⟩ := pendingTrace_ends hk
    have hdiv : (k - 1) / 2 = k / 2 := by omega
    refine ⟨k - 1, 0, by omega, ?_⟩
    rw [pendingTrace_even (by omega), hdiv]
  endsOnce := by
    intro k k' c hk hk'
    obtain ⟨hk2, rfl⟩ := pendingTrace_ends hk
    obtain ⟨hk2', hc⟩ := pendingTrace_ends hk'
    omega

end RustFuture.Implementations
