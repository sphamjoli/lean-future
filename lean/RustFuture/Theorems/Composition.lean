import RustFuture.Semantics.Future
/-! Research question: under which side conditions does
`F₁ ⊨ C₁ ∧ F₂ ⊨ C₂ → Compose F₁ F₂ ⊨ C₃`? Only the vocabulary is fixed. Status: open. -/
namespace RustFuture.Theorems
open RustFuture

def Satisfies {σ α : Type} (M : FutureModel σ α) (C : Trace α → Prop) : Prop :=
  ∀ t, M.Traces t → C t

end RustFuture.Theorems
