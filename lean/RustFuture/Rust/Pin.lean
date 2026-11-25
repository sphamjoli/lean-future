import RustFuture.Rust.Ownership
/-! `Pin<&mut Self>` obligations. `Unpin` futures are exempt from the
restrictive effects, so pinning is NOT "all futures are immovable". -/
namespace RustFuture.Rust

/-- Pinning obligations. `unpin_trivial`: for `Unpin` types pinning imposes nothing. -/
structure PinModel (σ : Type) extends AccessModel σ where
  isUnpin : Prop
  pinValid : σ → Prop
  unpin_trivial : isUnpin → ∀ s, pinValid s

/-- Rule 1: valid access, as a precondition rather than an axiom. -/
def PinModel.ValidPoll {σ : Type} (P : PinModel σ) (s : σ) : Prop :=
  P.exclusiveAccess s ∧ P.pinValid s

end RustFuture.Rust
