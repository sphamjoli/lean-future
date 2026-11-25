import RustFuture.Contracts.Assumptions
/-! A consistency witness in which every conditional rule actually fires.

The run: Bob picks up task 0, polls with waker 0, Alice returns `Pending`, the
parcel arrives, waker 0 is used, Bob picks the task up again, polls with waker 1,
and Alice returns `Ready 7`. The task is live until the `Ready`, progress is
possible from position 3, and Alice is wanted until position 7. -/
namespace RustFuture.Contracts
open RustFuture

def wakeRun : Trace Nat := fun
  | 0 => .taskPollBegin 0
  | 1 => .pollBegin 0 0
  | 2 => .pollReturn 0 .pending
  | 3 => .external
  | 4 => .wake 0
  | 5 => .taskPollBegin 0
  | 6 => .pollBegin 1 1
  | 7 => .pollReturn 1 (.ready 7)
  | _ => .internal

/-- A model of Alice for this story: her state is the current position, and at
each position she takes exactly the event the story lists there. -/
def liveModel : FutureModel Nat Nat where
  initial n := n = 0
  step n e n' := n' = n + 1 ∧ e = wakeRun n

theorem wakeRun_is_run : liveModel.IsRunWith id wakeRun :=
  ⟨rfl, fun _ => ⟨rfl, rfl⟩⟩

/-- States are trace positions. Progress is possible from position 3; Alice is
wanted before position 7; the task is live before position 7. -/
def liveContext : Context Nat Nat where
  memory := { exclusiveAccess := fun _ => True, isUnpin := True, pinValid := fun _ => True,
              unpin_trivial := fun _ _ => trivial }
  executor := { env := ⟨fun _ => 0⟩, liveFrom := fun i _ => i < 7, hb := (· < ·),
                hb_of_lt := fun _ _ h => h, hb_trans := fun _ _ _ => Nat.lt_trans }
  environment := { progressOpportunity := fun n => 3 ≤ n, stillInterested := fun n => n < 7 }

theorem wakeRun_wake {k w : Nat} (h : wakeRun k = .wake w) : k = 4 ∧ w = 0 := by
  match k, h with
  | 4, h => simp [wakeRun] at h; exact ⟨rfl, h.symm⟩
  | 0, h | 1, h | 2, h | 3, h | 5, h | 6, h | 7, h => simp [wakeRun] at h
  | k + 8, h => simp [wakeRun] at h

theorem wakeRun_pending {i c : Nat} (h : wakeRun i = .pollReturn c .pending) : i = 2 := by
  match i, h with
  | 2, _ => rfl
  | 0, h | 1, h | 3, h | 4, h | 5, h | 6, h | 7, h => simp [wakeRun] at h
  | k + 8, h => simp [wakeRun] at h

theorem wakeRun_pollBegin {i : Nat} (h : PollBeginAt wakeRun i) : i = 1 ∨ i = 6 := by
  obtain ⟨c, w, h⟩ := h
  match i, h with
  | 1, _ => exact .inl rfl
  | 6, _ => exact .inr rfl
  | 0, h | 2, h | 3, h | 4, h | 5, h | 7, h => simp [wakeRun] at h
  | k + 8, h => simp [wakeRun] at h

theorem wakeRun_ready {i : Nat} (h : ReadyAt wakeRun i) : i = 7 := by
  obtain ⟨c, v, h⟩ := h
  match i, h with
  | 7, _ => rfl
  | 0, h | 1, h | 2, h | 3, h | 4, h | 5, h | 6, h => simp [wakeRun] at h
  | k + 8, h => simp [wakeRun] at h

/-- Assumptions and obligations hold together on a run where a wake on a live
task, delivery, a latest-waker window and a progress opportunity all occur. -/
theorem assumptions_consistent_live :
    liveModel.IsRunWith id wakeRun ∧
      Assumptions liveContext id wakeRun ∧ Obligations liveContext id wakeRun := by
  refine ⟨wakeRun_is_run, ⟨fun _ _ => ⟨trivial, trivial⟩, ?_, ?_⟩, ⟨?_, ?_, ?_⟩⟩
  · intro i hi j hij hj
    have := wakeRun_ready hi; have := wakeRun_pollBegin hj; omega
  · intro i w hw _
    obtain ⟨rfl, rfl⟩ := wakeRun_wake hw
    exact ⟨5, by decide, (by decide : (4 : Nat) < 5), rfl⟩
  · intro i h
    match i, h with
    | 0, h | 1, h | 2, h | 3, h | 4, h | 5, h | 6, h | 7, h => simp [wakeRun] at h
    | k + 8, h => simp [wakeRun] at h
  · intro i w ⟨b, c, hb, hbeg, hret⟩ k w' hik hnp hk
    have hi := wakeRun_pending hret
    subst hi
    have hw : w = 0 := by
      match b, hb, hbeg with
      | 0, _, h => simp [wakeRun] at h
      | 1, _, h => simp [wakeRun] at h; exact h.2.symm
    subst hw
    obtain ⟨rfl, -⟩ := wakeRun_wake hk
    exact ⟨4, by decide, hnp, rfl⟩
  · intro i c hi j hij hp hs
    have := wakeRun_pending hi
    simp [liveContext] at hp hs
    by_cases h4 : j ≤ 4
    · exact ⟨4, h4, .inl ⟨0, rfl⟩⟩
    · exact ⟨6, by omega, .inr ⟨1, 1, rfl⟩⟩

end RustFuture.Contracts
