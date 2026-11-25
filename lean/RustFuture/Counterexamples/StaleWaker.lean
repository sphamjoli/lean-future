import RustFuture.Contracts.Future
/-! `WakesLatest` is neither vacuous nor unsatisfiable. After two polls with
wakers 0 and 1 both returning `Pending`, waking only 0 violates it and waking 1
satisfies it. -/
namespace RustFuture.Counterexamples
open RustFuture Contracts

def suspendedTwice (w : WakerId) : Trace Unit := fun
  | 0 => .pollBegin 0 0
  | 1 => .pollReturn 0 .pending
  | 2 => .pollBegin 1 1
  | 3 => .pollReturn 1 .pending
  | 4 => .wake w
  | _ => .internal

theorem stale_violates_latest : ¬ WakesLatest (suspendedTwice 0) := by
  intro h
  have hs : SuspendedWith (suspendedTwice 0) 3 1 := ⟨2, 1, by decide, rfl, rfl⟩
  have hnp : NoPollBetween (suspendedTwice 0) 3 4 := fun m _ _ h1 h2 => by omega
  obtain ⟨k, hk, _, hw⟩ := h 3 1 hs 4 0 (by decide) hnp rfl
  match k, hk, hw with
  | 4, _, hw => simp [suspendedTwice] at hw
  | k + 5, _, hw => simp [suspendedTwice] at hw

theorem wake_index {w w' : WakerId} {k : Nat} (h : suspendedTwice w k = .wake w') : k = 4 ∧ w' = w := by
  match k, h with
  | 4, h => simp [suspendedTwice] at h; exact ⟨rfl, h.symm⟩
  | 0, h | 1, h | 2, h | 3, h => simp [suspendedTwice] at h
  | k + 5, h => simp [suspendedTwice] at h

theorem latest_satisfiable : WakesLatest (suspendedTwice 1) := by
  intro i w ⟨b, c, hb, hbeg, hret⟩ k w' hik hnp hk
  obtain ⟨rfl, -⟩ := wake_index hk
  match i, hret with
  | 1, _ => exact absurd rfl (hnp 2 1 1 (by decide) (by decide))
  | 3, hret =>
    simp [suspendedTwice] at hret
    subst hret
    have hw : w = 1 := by
      match b, hb, hbeg with
      | 0, _, h | 1, _, h => simp [suspendedTwice] at h
      | 2, _, h => simp [suspendedTwice] at h; exact h.symm
    subst hw
    exact ⟨4, by decide, fun m _ _ h1 h2 => by omega, rfl⟩
  | 0, h | 2, h | 4, h => simp [suspendedTwice] at h
  | i + 5, h => simp [suspendedTwice] at h

end RustFuture.Counterexamples
