import RustFuture.Contracts.Executor
import RustFuture.Contracts.Environment
/-! Liveness. Note `Pending → ◇Wake` is *false* (a packet may never arrive);
the obligation is conditional on an independent progress opportunity. -/
namespace RustFuture.Properties
open RustFuture

/-- Target invariant for `NoLostWakeup` over a state-based implementation model:
whenever the future is pending and a value is available, either a notification
is outstanding or a poll is in flight. Status: **open** (statement only). -/
structure LostWakeObservables (σ : Type) where
  pending : σ → Prop
  valueAvailable : σ → Prop
  notificationOutstanding : σ → Prop
  pollInFlight : σ → Prop

def NoLostWakeup {σ : Type} (O : LostWakeObservables σ) (reachable : σ → Prop) : Prop :=
  ∀ s, reachable s → O.pending s → O.valueAvailable s →
    O.notificationOutstanding s ∨ O.pollInFlight s

end RustFuture.Properties
