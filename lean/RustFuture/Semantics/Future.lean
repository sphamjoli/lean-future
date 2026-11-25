import RustFuture.Semantics.Trace
/-! A future as a labelled transition system `(S, A, →, S₀)`.
`step` is a *relation*: nondeterminism, environment input and non-returning
polls are all representable. The state `σ` includes the relevant environment. -/
namespace RustFuture

structure FutureModel (σ α : Type) where
  initial : σ → Prop
  step : σ → Event α → σ → Prop

/-- `t` is an infinite run of `M` witnessed by the state sequence `s`. -/
def FutureModel.IsRunWith {σ α : Type} (M : FutureModel σ α) (s : Nat → σ) (t : Trace α) : Prop :=
  M.initial (s 0) ∧ ∀ n, M.step (s n) (t n) (s (n + 1))

def FutureModel.Traces {σ α : Type} (M : FutureModel σ α) (t : Trace α) : Prop :=
  ∃ s, M.IsRunWith s t

end RustFuture
