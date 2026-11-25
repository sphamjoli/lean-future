import RustFuture.Semantics.Future
/-! Cancellation = `drop` of a suspended future. Dropping does NOT reverse
external effects. Status: **open**; only the shape is fixed. -/
namespace RustFuture.Properties
open RustFuture

def CancellationSafe {σ α : Type} (M : FutureModel σ α) (inv : σ → Prop) : Prop :=
  ∀ s s', inv s → M.step s .drop s' → inv s'

end RustFuture.Properties
