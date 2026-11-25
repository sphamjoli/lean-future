/-! The bridge: `π(Traces R) ⊆ Traces M`. Everything proved about `M` transfers
only to *represented* concrete executions. For liveness, `project` must not
hide divergence (it maps infinite executions to infinite traces by construction
when `A = Trace α`). -/
namespace RustFuture.Properties

def Refines {C A : Type} (concrete : C → Prop) (abstract : A → Prop) (project : C → A) : Prop :=
  ∀ e, concrete e → abstract (project e)

theorem verification_transfer {C A : Type}
    (concrete : C → Prop) (abstract : A → Prop) (project : C → A) (property : A → Prop)
    (refinement : Refines concrete abstract project)
    (verified : ∀ t, abstract t → property t) :
    ∀ t, concrete t → property (project t) :=
  fun t ht => verified (project t) (refinement t ht)

end RustFuture.Properties
