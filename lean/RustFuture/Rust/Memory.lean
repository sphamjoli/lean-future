/-! Placeholder for memory-safety invariants. Open work: candidate sources are
Aeneas' LLBC semantics or RustBelt-style models; neither is assumed here. -/
namespace RustFuture.Rust

structure MemoryInvariant (σ : Type) where
  inv : σ → Prop

end RustFuture.Rust
