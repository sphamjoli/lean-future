/-! `core::task::Poll`. Type-level guarantee: a *normally returning* poll yields
one of these two values. Panics and divergence are not values; they are
modelled as trace events / absence of a `pollReturn`, see `Trace.lean`. -/
namespace RustFuture

inductive Poll (α : Type) where
  | pending
  | ready (value : α)
  deriving DecidableEq, Repr

def Poll.isReady {α : Type} : Poll α → Bool
  | .ready _ => true
  | .pending => false

end RustFuture
