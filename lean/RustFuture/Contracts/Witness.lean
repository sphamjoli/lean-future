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

/-- States are trace positions. Both wakers belong to task 0. Progress is
possible from position 3; Alice is wanted, and the task live, before position 7.
Happens-before is supplied as trace order, a choice this witness makes, not one
the executor model forces. -/
def liveContext : Context Nat Nat where
  memory := { exclusiveAccess := fun _ => True, isUnpin := True, pinValid := fun _ => True,
              unpin_trivial := fun _ _ => trivial }
  executor := { env := ⟨fun _ => 0⟩, liveFrom := fun i _ => i < 7, hb := (· < ·),
                hb_trans := fun _ _ _ => Nat.lt_trans, hb_forward := fun _ _ h => h }
  environment := { progressOpportunity := fun n => 3 ≤ n, stillInterested := fun n => n < 7 }

theorem wakeRun_wake {k w : Nat} (h : wakeRun k = .wake w) : k = 4 ∧ w = 0 := by
  match k, h with
  | 4, h => simp [wakeRun] at h; exact ⟨rfl, h.symm⟩
  | 0, h | 1, h | 2, h | 3, h | 5, h | 6, h | 7, h => simp [wakeRun] at h
  | k + 8, h => simp [wakeRun] at h

theorem wakeRun_begin {i c w : Nat} (h : wakeRun i = .pollBegin c w) :
    (i = 1 ∧ c = 0 ∧ w = 0) ∨ (i = 6 ∧ c = 1 ∧ w = 1) := by
  match i, h with
  | 1, h => simp [wakeRun] at h; exact .inl ⟨rfl, h.1.symm, h.2.symm⟩
  | 6, h => simp [wakeRun] at h; exact .inr ⟨rfl, h.1.symm, h.2.symm⟩
  | 0, h | 2, h | 3, h | 4, h | 5, h | 7, h => simp [wakeRun] at h
  | k + 8, h => simp [wakeRun] at h

theorem wakeRun_return {k c : Nat} {r : Poll Nat} (h : wakeRun k = .pollReturn c r) :
    (k = 2 ∧ c = 0 ∧ r = .pending) ∨ (k = 7 ∧ c = 1 ∧ r = .ready 7) := by
  match k, h with
  | 2, h => simp [wakeRun] at h; exact .inl ⟨rfl, h.1.symm, h.2.symm⟩
  | 7, h => simp [wakeRun] at h; exact .inr ⟨rfl, h.1.symm, h.2.symm⟩
  | 0, h | 1, h | 3, h | 4, h | 5, h | 6, h => simp [wakeRun] at h
  | k + 8, h => simp [wakeRun] at h

theorem wakeRun_no_special {k : Nat} :
    wakeRun k ≠ .undefinedBehaviour ∧ wakeRun k ≠ .drop ∧ wakeRun k ≠ .abort ∧
      ∀ c, wakeRun k ≠ .panic c := by
  match k with
  | 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 => simp [wakeRun]
  | k + 8 => simp [wakeRun]

theorem wakeRun_ends {k c : Nat} (h : EndsAt wakeRun k c) : (k = 2 ∧ c = 0) ∨ (k = 7 ∧ c = 1) := by
  rcases h with ⟨r, hr⟩ | hp
  · rcases wakeRun_return hr with ⟨rfl, rfl, -⟩ | ⟨rfl, rfl, -⟩
    · exact .inl ⟨rfl, rfl⟩
    · exact .inr ⟨rfl, rfl⟩
  · exact absurd hp (wakeRun_no_special.2.2.2 c)

theorem wakeRun_wellFormed : WellFormed wakeRun where
  uniqueCalls := by
    intro i j c w w' hi hj
    rcases wakeRun_begin hi with ⟨rfl, rfl, -⟩ | ⟨rfl, rfl, -⟩ <;>
      rcases wakeRun_begin hj with ⟨rfl, h, -⟩ | ⟨rfl, h, -⟩ <;> omega
  noOverlap := by
    intro i c w j c' w' hij hi hj
    rcases wakeRun_begin hi with ⟨rfl, rfl, -⟩ | ⟨rfl, rfl, -⟩ <;>
      rcases wakeRun_begin hj with ⟨rfl, -, -⟩ | ⟨rfl, -, -⟩
    · omega
    · exact ⟨2, 0, by decide, by decide, .inl ⟨.pending, rfl⟩⟩
    · omega
    · omega
  noDropDuringPoll := fun _ _ _ _ _ _ h => absurd h wakeRun_no_special.2.1
  nothingAfterTerminal := by
    intro i hT
    rcases hT with h | h
    · exact absurd h wakeRun_no_special.2.1
    · exact absurd h wakeRun_no_special.2.2.1

theorem wakeRun_callsMatched : CallsMatched wakeRun where
  endMatchesBegin := by
    intro k c hk
    rcases wakeRun_ends hk with ⟨rfl, rfl⟩ | ⟨rfl, rfl⟩
    · exact ⟨1, 0, by decide, rfl⟩
    · exact ⟨6, 1, by decide, rfl⟩
  endsOnce := by
    intro k k' c hk hk'
    rcases wakeRun_ends hk with ⟨rfl, rfl⟩ | ⟨rfl, rfl⟩ <;>
      rcases wakeRun_ends hk' with ⟨rfl, h⟩ | ⟨rfl, h⟩ <;> omega

/-- On a well-formed run of a model of Alice, all assumptions and obligations
hold together while a live wake, its delivery, a latest-waker epoch and a
progress opportunity all occur. Rule 1 holds only trivially here, because the
memory description allows everything. -/
theorem assumptions_consistent_live :
    liveModel.IsRunWith id wakeRun ∧ WellFormed wakeRun ∧
      Assumptions liveContext id wakeRun ∧ NoUB wakeRun ∧ CallsMatched wakeRun ∧
        ProtocolObligations liveContext id wakeRun := by
  refine ⟨wakeRun_is_run, wakeRun_wellFormed, ⟨fun _ _ => ⟨trivial, trivial⟩, ?_, ?_⟩,
    fun _ => wakeRun_no_special.1, wakeRun_callsMatched, ⟨?_, ?_⟩⟩
  · rintro i ⟨c, v, hi⟩ j hij ⟨c', w', hj⟩
    rcases wakeRun_return hi with ⟨rfl, -, h⟩ | ⟨rfl, -, -⟩
    · cases h
    · rcases wakeRun_begin hj with ⟨rfl, -, -⟩ | ⟨rfl, -, -⟩ <;> omega
  · intro i w hw _
    obtain ⟨rfl, rfl⟩ := wakeRun_wake hw
    exact ⟨5, by decide, (by decide : (4 : Nat) < 5), rfl⟩
  · intro b i w ⟨c, hbi, hb, hi, _, _⟩ k w' hik hnp _ hk
    rcases wakeRun_return hi with ⟨rfl, rfl, -⟩ | ⟨rfl, -, h⟩
    · obtain ⟨rfl, -⟩ := wakeRun_wake hk
      exact ⟨4, 0, by omega, hnp, rfl, rfl⟩
    · cases h
  · intro b i w ⟨c, hbi, hb, hi, _, _⟩ j hij hnp _ _ _
    rcases wakeRun_return hi with ⟨rfl, rfl, -⟩ | ⟨rfl, -, h⟩
    · rcases wakeRun_begin hb with ⟨rfl, -, -⟩ | ⟨rfl, -, -⟩
      · refine ⟨4, by decide, .inl ⟨0, w, rfl, ⟨1, 0, by decide, by decide, hb, fun m c w h1 h2 hm => ?_⟩, rfl⟩⟩
        rcases wakeRun_begin hm with ⟨rfl, -, -⟩ | ⟨rfl, -, -⟩ <;> omega
      · omega
    · cases h

end RustFuture.Contracts
