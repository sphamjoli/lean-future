import RustFuture.Semantics.Waker
/-! `core::task::Context<'_>`: for this model, just the waker of the current call.
Lifetimes are discharged by the Rust memory model (`Rust/`), not here. -/
namespace RustFuture

structure Context where
  waker : WakerId
  deriving DecidableEq, Repr

end RustFuture
