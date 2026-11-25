import RustFuture.Contracts.Future
/-! Safety properties: things that must never happen on any finite prefix. -/
namespace RustFuture.Properties
open RustFuture

def Always {α : Type} (P : Event α → Prop) (t : Trace α) : Prop := ∀ i, P (t i)

theorem noUB_iff_always {α : Type} (t : Trace α) :
    Contracts.NoUB t ↔ Always (· ≠ .undefinedBehaviour) t := Iff.rfl

end RustFuture.Properties
