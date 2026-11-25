import RustFuture.Contracts.Environment
import RustFuture.Implementations.Pending
/-! Two regression checks on `ProgressNotifies`.

* A future that is polled for ever, always answers `Pending` and never arranges
  a wake, while progress is possible, violates the rule. Re-polling by a busy
  executor does not discharge the obligation.
* Dropping the future after the obligation arises discharges it. -/
namespace RustFuture.Counterexamples
open RustFuture Contracts Implementations

/-- Progress is always possible and the future is always wanted. -/
def alwaysProgress : EnvironmentModel Unit := ⟨fun _ => True, fun _ => True⟩

theorem busy_executor_does_not_hide :
    ¬ ProgressNotifies ⟨id⟩ alwaysProgress (fun _ => ()) (pendingTrace Nat) := by
  intro h
  have hs : SuspendedFrom (pendingTrace Nat) 0 1 0 :=
    ⟨0, by decide, rfl, rfl, fun m _ _ h1 h2 => by omega, fun m h1 h2 => by omega⟩
  have hnp : NoPollBetween (pendingTrace Nat) 1 2 := fun m _ _ h1 h2 => by omega
  have hnt : ∀ m, 1 < m → m ≤ 2 → ¬ TerminalAt (pendingTrace Nat) m := by
    intro m _ _ ht
    rcases ht with ht | ht <;> (unfold pendingTrace at ht; split at ht <;> simp at ht)
  obtain ⟨k, _, hk⟩ := h 0 1 0 hs 2 (by decide) hnp hnt trivial trivial
  rcases hk with ⟨w', v, hw, _⟩ | ⟨c, v, hr⟩ | ht
  · unfold pendingTrace at hw; split at hw <;> simp at hw
  · unfold pendingTrace at hr; split at hr <;> simp at hr
  · rcases ht with ht | ht <;> (unfold pendingTrace at ht; split at ht <;> simp at ht)

/-- The cancellation trace from review: poll, `Pending`, progress, drop. -/
def cancelled : Trace Unit := fun
  | 0 => .pollBegin 0 0
  | 1 => .pollReturn 0 .pending
  | 2 => .external
  | 3 => .drop
  | _ => .internal

theorem cancelled_suspended {b i w : Nat} (h : SuspendedFrom cancelled b i w) : b = 0 ∧ i = 1 := by
  obtain ⟨c, hbi, hb, hi, -, -⟩ := h
  match i, hi with
  | 1, _ =>
    match b, hbi, hb with
    | 0, _, _ => exact ⟨rfl, rfl⟩
  | 0, hi | 2, hi | 3, hi => simp [cancelled] at hi
  | i + 4, hi => simp [cancelled] at hi

theorem cancellation_discharges : ProgressNotifies ⟨id⟩ alwaysProgress (fun _ => ()) cancelled := by
  intro b i w hs j _ _ _ _ _
  obtain ⟨rfl, rfl⟩ := cancelled_suspended hs
  exact ⟨3, by decide, .inr (.inr (.inl rfl))⟩

end RustFuture.Counterexamples
