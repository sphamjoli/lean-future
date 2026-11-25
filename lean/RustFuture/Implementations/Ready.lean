import RustFuture.Semantics.Future
/-! Model of `std::future::ready(v)`: first poll returns `Ready v`, never wakes.
Re-polling is left **unconstrained** beyond no-UB (std panics). -/
namespace RustFuture.Implementations
open RustFuture

inductive ReadyState | fresh | taken
  deriving DecidableEq

def readyModel {α : Type} (v : α) : FutureModel ReadyState α where
  initial s := s = .fresh
  step s e s' := e ≠ .undefinedBehaviour ∧ (∀ w, e ≠ .wake w) ∧
    match s, e with
    | .fresh, .pollReturn _ r => r = .ready v ∧ s' = .taken
    -- std's `Ready` panics instead
    | .taken, .pollReturn _ _ => False
    | _, _ => s' = s

end RustFuture.Implementations
