import RustFuture.Implementations.Oneshot
/-! The faulty receiver loses a wake-up, by an actual execution of its
transition system: poll with waker 1 (registered), poll again with waker 2 (not
registered, because the faulty receiver keeps the first), the sender stores the
value and takes waker 1, then wakes waker 1. The receiver is now waiting, the
value is there, waker 2 has never been woken and the sender owes nothing.
Rust witness: test `buggy_oneshot_loses_wake`. -/
namespace RustFuture.Counterexamples
open RustFuture Implementations

def afterPoll1 : OneshotState := ⟨false, some 1, some 1, true, false, false, none, false⟩
def afterPoll2 : OneshotState := ⟨false, some 1, some 2, true, false, false, none, false⟩
def afterSend : OneshotState := ⟨true, none, some 2, true, false, true, some 1, false⟩
def lostState : OneshotState := ⟨true, none, some 2, true, false, true, none, false⟩

theorem buggy_reaches_lostState : Reachable .buggy lostState := by
  have h1 : Reachable .buggy afterPoll1 :=
    .step .init (Step.pollPending OneshotState.init 1 rfl rfl)
  have h2 : Reachable .buggy afterPoll2 := .step h1 (Step.pollPending afterPoll1 2 rfl rfl)
  have h3 : Reachable .buggy afterSend := .step h2 (Step.send afterPoll2 rfl)
  exact .step h3 (Step.wake afterSend 1 rfl)

/-- The faulty receiver violates the no-lost-wake-up invariant. -/
theorem buggy_violates_noLostWakeup :
    ¬ Properties.NoLostWakeup oneshotObs (Reachable .buggy) := by
  intro h
  have := h lostState buggy_reaches_lostState rfl rfl
  simp [oneshotObs, lostState] at this

end RustFuture.Counterexamples
