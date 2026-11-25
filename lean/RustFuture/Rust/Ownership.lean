/-! Exclusive access (`&mut`) as an *opaque precondition* supplied by a separate
Rust memory model. Formalising ownership itself is out of scope (see POSITIONING). -/
namespace RustFuture.Rust

/-- What the memory model must provide about a state. Fields are hypotheses,
deliberately not definitions. -/
structure AccessModel (σ : Type) where
  exclusiveAccess : σ → Prop

end RustFuture.Rust
