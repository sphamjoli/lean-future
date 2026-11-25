import RustFuture.Implementations.Oneshot
/-! The `NoLostWakeup` invariant is refutable: a state that is suspended, has a
value, has no poll in flight, and whose latest waker was never woken (the sender
woke the stale waker 1 instead of 2) violates it.

What this does NOT show: that `buggy::Receiver` reaches this state. Reachability
from its transition system is open. The Rust test `buggy_oneshot_loses_wake`
exhibits the corresponding behaviour with two wakers that belong to distinct
tasks; with a single shared task waker nothing would be lost. -/
namespace RustFuture.Counterexamples
open RustFuture Implementations

def staleState : OneshotState := ⟨true, some 1, some 2, false, true, false⟩

theorem noLostWakeup_refutable :
    ¬ Properties.NoLostWakeup oneshotObs (· = staleState) := by
  intro h
  have := h staleState rfl rfl rfl
  simp [oneshotObs, staleState] at this

end RustFuture.Counterexamples
