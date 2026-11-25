/-! Memory-safety invariants are not modelled here. Candidate sources are
Aeneas' LLBC semantics or RustBelt-style models; neither is assumed here. -/
namespace RustFuture.Rust

structure MemoryInvariant (σ : Type) where
  inv : σ → Prop

end RustFuture.Rust
