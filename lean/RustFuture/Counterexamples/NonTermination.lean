import RustFuture.Implementations.Pending
/-! "Every future eventually completes" is not a valid axiom: there is a model,
every run of which is UB-free and never `Ready`, and that model has a run.
Rust witness: `future_witnesses::pending`, test `pending_never_completes`. -/
namespace RustFuture.Counterexamples
open RustFuture Implementations

theorem termination_not_universal :
    ∃ (M : FutureModel Unit Nat) (t : Trace Nat),
      M.Traces t ∧ Contracts.NoUB t ∧ ¬ EventuallyReady t :=
  ⟨pendingModel Nat, pendingTrace Nat, pendingTrace_is_run Nat,
    pendingModel_all_runs Nat _ (pendingTrace_is_run Nat)⟩

end RustFuture.Counterexamples
