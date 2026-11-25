import RustFuture.Contracts.Executor
import RustFuture.Contracts.Environment
/-! Liveness. Note `Pending → ◇Wake` is *false* (a packet may never arrive);
the obligation is conditional on an independent progress opportunity. -/
namespace RustFuture.Properties
open RustFuture

/-- Target invariant for `NoLostWakeup` over a state-based implementation model:
whenever the future is pending and a value is available, either a notification
is outstanding, a poll is in flight, or the sender still owes a notification
(it has stored the value and taken the waker, but not yet called `wake`). The
third case is needed for a correct sender that wakes after releasing its lock;
a separate liveness argument must show the sender discharges it. -/
structure LostWakeObservables (σ : Type) where
  pending : σ → Prop
  valueAvailable : σ → Prop
  notificationOutstanding : σ → Prop
  pollInFlight : σ → Prop
  senderOwesNotification : σ → Prop
  completed : σ → Prop

def NoLostWakeup {σ : Type} (O : LostWakeObservables σ) (reachable : σ → Prop) : Prop :=
  ∀ s, reachable s → O.pending s → O.valueAvailable s →
    O.notificationOutstanding s ∨ O.pollInFlight s ∨ O.senderOwesNotification s

end RustFuture.Properties

namespace RustFuture.Properties

/-- Companion to `NoLostWakeup`. On its own, the third disjunct of
`NoLostWakeup` can be met by a model whose sender owes a notification for ever,
which would make the invariant hollow. This liveness property closes that gap
along a run `s`: whenever the sender owes a notification, at a strictly later
point either the notification has been delivered or the future has completed
(a re-poll that finds the value needs no notification). The oneshot model proves
it for every run of the model under a fairness assumption on the sender. -/
def SenderEventuallyPays {σ : Type} (O : LostWakeObservables σ) (s : Nat → σ) : Prop :=
  ∀ n, O.senderOwesNotification (s n) →
    ∃ m, n < m ∧ (O.notificationOutstanding (s m) ∨ O.completed (s m))

end RustFuture.Properties
