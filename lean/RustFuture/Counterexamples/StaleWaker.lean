import RustFuture.Contracts.Future
/-! `WakesLatest` is neither vacuous nor unsatisfiable, and it respects waker
equivalence. After two visits with wakers 0 and 1 both returning `Pending`:
* if the wakers belong to different tasks, waking only 0 violates the clause;
* waking 1 satisfies it;
* if both wakers belong to the same task (the `Waker::will_wake` case), waking
  only the older waker 0 also satisfies it. -/
namespace RustFuture.Counterexamples
open RustFuture Contracts

def suspendedTwice (w : WakerId) : Trace Unit := fun
  | 0 => .pollBegin 0 0
  | 1 => .pollReturn 0 .pending
  | 2 => .pollBegin 1 1
  | 3 => .pollReturn 1 .pending
  | 4 => .wake w
  | _ => .internal

/-- Each waker wakes its own task. -/
def distinctTasks : WakerEnv := ⟨id⟩

/-- Every waker wakes task 0. -/
def sameTask : WakerEnv := ⟨fun _ => 0⟩

theorem st_wake {w w' : WakerId} {k : Nat} (h : suspendedTwice w k = .wake w') : k = 4 ∧ w' = w := by
  match k, h with
  | 4, h => simp [suspendedTwice] at h; exact ⟨rfl, h.symm⟩
  | 0, h | 1, h | 2, h | 3, h => simp [suspendedTwice] at h
  | k + 5, h => simp [suspendedTwice] at h

theorem st_suspended {w b i v : WakerId} (h : SuspendedFrom (suspendedTwice w) b i v) :
    (b = 0 ∧ i = 1 ∧ v = 0) ∨ (b = 2 ∧ i = 3 ∧ v = 1) := by
  obtain ⟨c, hbi, hb, hi, -, -⟩ := h
  match i, hi with
  | 1, hi =>
    simp [suspendedTwice] at hi; subst hi
    match b, hbi, hb with
    | 0, _, hb => simp [suspendedTwice] at hb; exact .inl ⟨rfl, rfl, hb.symm⟩
  | 3, hi =>
    simp [suspendedTwice] at hi; subst hi
    match b, hbi, hb with
    | 0, _, hb | 1, _, hb => simp [suspendedTwice] at hb
    | 2, _, hb => simp [suspendedTwice] at hb; exact .inr ⟨rfl, rfl, hb.symm⟩
  | 0, hi | 2, hi | 4, hi => simp [suspendedTwice] at hi
  | i + 5, hi => simp [suspendedTwice] at hi

theorem stale_violates_latest : ¬ WakesLatest distinctTasks (suspendedTwice 0) := by
  intro h
  have hs : SuspendedFrom (suspendedTwice 0) 2 3 1 :=
    ⟨1, by decide, rfl, rfl, fun m _ _ h1 h2 => by omega, fun m h1 h2 => by omega⟩
  have hnp : NoPollBetween (suspendedTwice 0) 3 4 := fun m _ _ h1 h2 => by omega
  obtain ⟨k, w'', _, _, hw, heq⟩ := h 2 3 1 hs 4 0 (by decide) hnp rfl
  obtain ⟨-, rfl⟩ := st_wake hw
  simp [WakeEquivalent, distinctTasks] at heq

/-- Shared by both acceptance proofs: the only window with a wake is the one
after position 3, and the wake at 4 is the witness. -/
theorem accepts_if {E : WakerEnv} {w : WakerId} (heq : WakeEquivalent E w 1) :
    WakesLatest E (suspendedTwice w) := by
  intro b i v hs k w' hik hnp hk
  obtain ⟨rfl, -⟩ := st_wake hk
  rcases st_suspended hs with ⟨rfl, rfl, rfl⟩ | ⟨rfl, rfl, rfl⟩
  · exact absurd rfl (hnp 2 1 1 (by decide) (by decide))
  · exact ⟨4, w, by decide, hnp, rfl, heq⟩

theorem latest_satisfiable : WakesLatest distinctTasks (suspendedTwice 1) :=
  accepts_if rfl

theorem will_wake_accepted : WakesLatest sameTask (suspendedTwice 0) :=
  accepts_if rfl

end RustFuture.Counterexamples

namespace RustFuture.Counterexamples
open RustFuture Contracts

/-- The epoch-confusion trace from review: visit 0 begins with waker 1, waker 1
is used, visit 0 returns `Pending`, visit 0's number is reused for a new visit
with waker 2, and that returns `Pending`. -/
def reusedCall : Trace Unit := fun
  | 0 => .pollBegin 0 1
  | 1 => .wake 1
  | 2 => .pollReturn 0 .pending
  | 3 => .pollBegin 0 2
  | 4 => .pollReturn 0 .pending
  | _ => .internal

/-- The later `Pending` at 4 is not treated as ending the visit that began at 0,
so the old wake at 1 cannot be counted for the later epoch. -/
theorem epoch_not_confused : ¬ SuspendedFrom reusedCall 0 4 1 := by
  rintro ⟨c, _, _, _, hnp, _⟩
  exact hnp 3 0 2 (by decide) (by decide) rfl

/-- And the trace is not well formed anyway: visit number 0 is used twice. -/
theorem reusedCall_not_wellFormed : ¬ WellFormed reusedCall := by
  intro h
  have := h.uniqueCalls 0 3 0 1 2 rfl rfl
  omega

end RustFuture.Counterexamples
