import RustFuture.Properties.Liveness
/-! Concrete transition semantics of the oneshot channel in
`future_witnesses::oneshot`, for both receivers.

Each step mirrors the Rust code:
* a poll takes the lock, then either takes the value and returns `Ready`, or
  registers a waker and returns `Pending`, and releases the lock, all as one
  step because nothing else can touch the slot meanwhile;
* `send` takes the lock, stores the value, takes the registered waker and
  releases the lock;
* the sender then calls `wake` on the waker it took, as a separate step,
  because another thread can act between the unlock and the wake.

The correct receiver registers the waker of every poll. The faulty receiver
registers only the first one. Wakers are identified by number, and each waker
is taken to belong to its own task. -/
namespace RustFuture.Implementations

structure OneshotState where
  -- the slot holds the value
  value : Bool
  -- the waker registered in the slot
  slot : Option Nat
  -- the waker of the most recent poll
  latest : Option Nat
  -- the most recent poll returned `Pending`
  suspended : Bool
  -- the receiver has returned `Ready`
  done : Bool
  -- the sender has stored the value
  sent : Bool
  -- the waker the sender took and has not yet woken
  owes : Option Nat
  -- the most recent poll's waker has been woken since that poll
  wokeLatest : Bool
  deriving DecidableEq

def OneshotState.init : OneshotState :=
  ⟨false, none, none, false, false, false, none, false⟩

inductive Variant where
  | correct
  | buggy

/-- What a `Pending` poll leaves in the slot. -/
def registerOnPoll : Variant → Option Nat → Nat → Option Nat
  | .correct, _, n => some n
  | .buggy, none, n => some n
  | .buggy, some w, _ => some w

inductive Step (v : Variant) : OneshotState → OneshotState → Prop where
  | pollReady (s : OneshotState) (n : Nat) : s.done = false → s.value = true →
      Step v s { s with value := false, done := true, suspended := false,
                        latest := some n, wokeLatest := false }
  | pollPending (s : OneshotState) (n : Nat) : s.done = false → s.value = false →
      Step v s { s with slot := registerOnPoll v s.slot n, latest := some n,
                        suspended := true, wokeLatest := false }
  | send (s : OneshotState) : s.sent = false →
      Step v s { s with value := true, sent := true, owes := s.slot, slot := none }
  | wake (s : OneshotState) (w : Nat) : s.owes = some w →
      Step v s { s with owes := none, wokeLatest := s.wokeLatest || decide (s.latest = some w) }

inductive Reachable (v : Variant) : OneshotState → Prop where
  | init : Reachable v .init
  | step {s s' : OneshotState} : Reachable v s → Step v s s' → Reachable v s'

/-- The observables, all read off the state. `notificationOutstanding` is set
only by an actual wake of the most recent poll's waker. A poll is a single
step, so no poll is ever in flight. -/
def oneshotObs : Properties.LostWakeObservables OneshotState where
  pending s := s.suspended = true
  valueAvailable s := s.value = true
  notificationOutstanding s := s.wokeLatest = true
  pollInFlight _ := False
  senderOwesNotification s := s.owes ≠ none ∧ s.owes = s.latest
  completed s := s.done = true

/-- The invariant of the correct receiver. -/
structure CorrectInv (s : OneshotState) : Prop where
  waitingRegistered : s.suspended = true → s.value = false → s.slot = s.latest ∧ s.latest ≠ none
  noLostWake : s.suspended = true → s.value = true →
    s.wokeLatest = true ∨ (s.owes ≠ none ∧ s.owes = s.latest)
  sentClearsSlot : s.sent = true → s.slot = none
  sentMeansValueOrDone : s.sent = true → s.value = true ∨ s.done = true
  valueMeansSent : s.value = true → s.sent = true
  owesMeansSent : s.owes ≠ none → s.sent = true

theorem correctInv_init : CorrectInv OneshotState.init :=
  ⟨by simp [OneshotState.init], by simp [OneshotState.init], by simp [OneshotState.init],
   by simp [OneshotState.init], by simp [OneshotState.init], by simp [OneshotState.init]⟩

theorem correctInv_step {s s' : OneshotState} (h : CorrectInv s) (hs : Step .correct s s') :
    CorrectInv s' := by
  obtain ⟨i1, i2, i3, i4, i5, i6⟩ := h
  cases hs with
  | pollReady n hd hv =>
    refine ⟨?_, ?_, ?_, ?_, ?_, ?_⟩ <;> simp_all
  | pollPending n hd hv =>
    have hsent : s.sent = false := by
      cases h' : s.sent
      · rfl
      · rcases i4 h' with h'' | h'' <;> simp_all
    refine ⟨?_, ?_, ?_, ?_, ?_, ?_⟩ <;> simp_all [registerOnPoll]
  | send hsent =>
    have hv : s.value = false := by
      cases h' : s.value
      · rfl
      · simp_all
    refine ⟨?_, ?_, ?_, ?_, ?_, ?_⟩
    · simp
    · intro hsus _
      obtain ⟨hsl, hl⟩ := i1 hsus hv
      exact .inr ⟨by simpa [hsl] using hl, hsl⟩
    · simp
    · simp
    · simp
    · simp
  | wake w hw =>
    refine ⟨?_, ?_, ?_, ?_, ?_, ?_⟩
    · simpa using i1
    · intro hsus hval
      rcases i2 hsus hval with h' | ⟨_, h'⟩
      · exact .inl (by simp [h'])
      · exact .inl (by simp [← h', hw])
    · simpa using i3
    · simpa using i4
    · simpa using i5
    · simp

theorem correctInv_reachable {s : OneshotState} (h : Reachable .correct s) : CorrectInv s := by
  induction h with
  | init => exact correctInv_init
  | step _ hs ih => exact correctInv_step ih hs

/-- The correct receiver never loses a wake-up: in every reachable state where
it is waiting and the value is there, the latest waker has been woken or the
sender still owes it a wake. -/
theorem correct_noLostWakeup : Properties.NoLostWakeup oneshotObs (Reachable .correct) := by
  intro s hr hp hv
  rcases (correctInv_reachable hr).noLostWake hp hv with h | h
  · exact .inl h
  · exact .inr (.inr h)

/-- A run of the model: it starts in the initial state, and each step is a
transition or a pause (no change). -/
def IsRun (v : Variant) (r : Nat → OneshotState) : Prop :=
  r 0 = .init ∧ ∀ n, Step v (r n) (r (n + 1)) ∨ r (n + 1) = r n

theorem IsRun.reachable {v : Variant} {r : Nat → OneshotState} (h : IsRun v r) :
    ∀ n, Reachable v (r n) := by
  intro n
  induction n with
  | zero => rw [h.1]; exact .init
  | succ n ih =>
    rcases h.2 n with hs | he
    · exact .step ih hs
    · rw [he]; exact ih

/-- The scheduling assumption: a sender that owes a wake eventually makes the
call. Without it a sender thread could stall for ever after releasing the lock. -/
def SenderFair (r : Nat → OneshotState) : Prop :=
  ∀ n, (r n).owes ≠ none → ∃ m, n ≤ m ∧ (r (m + 1)).owes = none

/-- What stays true from the moment the sender owes the latest waker `w`. -/
def Settling (w : Nat) (s : OneshotState) : Prop :=
  s.sent = true ∧
    (s.done = true ∨ s.wokeLatest = true ∨ (s.owes = some w ∧ s.latest = some w))

theorem settling_step {w : Nat} {s s' : OneshotState} (hi : CorrectInv s) (h : Settling w s)
    (hs : Step .correct s s' ∨ s' = s) : Settling w s' := by
  obtain ⟨hsent, hcase⟩ := h
  rcases hs with hs | rfl
  · cases hs with
    | pollReady n _ _ => exact ⟨hsent, .inl rfl⟩
    | pollPending n hd hv =>
      rcases hi.sentMeansValueOrDone hsent with h' | h' <;> simp_all
    | send hs' => simp_all
    | wake w' hw =>
      refine ⟨hsent, ?_⟩
      rcases hcase with h' | h' | ⟨ho, hl⟩
      · exact .inl h'
      · exact .inr (.inl (by simp [h']))
      · rw [ho] at hw
        cases hw
        exact .inr (.inl (by simp [hl]))
  · exact ⟨hsent, hcase⟩

/-- Conditional liveness of the correct receiver. On every run in which the
sender eventually makes any wake it owes, whenever the sender owes the latest
waker a wake, at a strictly later point that waker has been woken or the
receiver has completed. -/
theorem correct_senderEventuallyPays {r : Nat → OneshotState} (hr : IsRun .correct r)
    (hf : SenderFair r) : Properties.SenderEventuallyPays oneshotObs r := by
  intro n ⟨hne, heq⟩
  obtain ⟨w, hw⟩ : ∃ w, (r n).owes = some w := by
    cases h : (r n).owes with
    | none => exact absurd h hne
    | some w => exact ⟨w, rfl⟩
  obtain ⟨m, hnm, hm⟩ := hf n hne
  have hsent : (r n).sent = true := (correctInv_reachable (hr.reachable n)).owesMeansSent hne
  have hstart : Settling w (r n) := ⟨hsent, .inr (.inr ⟨hw, by rw [← heq, hw]⟩)⟩
  have hall : ∀ k, Settling w (r (n + k)) := by
    intro k
    induction k with
    | zero => simpa using hstart
    | succ k ih =>
      have hi := correctInv_reachable (hr.reachable (n + k))
      exact settling_step hi ih (hr.2 (n + k))
  have hfin := hall (m + 1 - n)
  rw [show n + (m + 1 - n) = m + 1 by omega] at hfin
  refine ⟨m + 1, by omega, ?_⟩
  rcases hfin.2 with h | h | ⟨ho, _⟩
  · exact .inr h
  · exact .inl h
  · rw [hm] at ho; cases ho

/-- A fair run in which the sender really does owe the latest waker a wake:
poll with waker 1, send, wake waker 1, then nothing more. It shows the premise
of `correct_senderEventuallyPays` can hold, so the theorem is not vacuous. -/
def exampleRun : Nat → OneshotState
  | 0 => .init
  | 1 => ⟨false, some 1, some 1, true, false, false, none, false⟩
  | 2 => ⟨true, none, some 1, true, false, true, some 1, false⟩
  | _ => ⟨true, none, some 1, true, false, true, none, true⟩

theorem exampleRun_witness :
    IsRun .correct exampleRun ∧ SenderFair exampleRun ∧
      oneshotObs.senderOwesNotification (exampleRun 2) := by
  refine ⟨⟨rfl, fun step => ?_⟩, fun position hne => ?_, ⟨by simp [exampleRun], rfl⟩⟩
  · match step with
    | 0 => exact .inl (Step.pollPending OneshotState.init 1 rfl rfl)
    | 1 => exact .inl (Step.send _ rfl)
    | 2 => exact .inl (Step.wake _ 1 rfl)
    | step + 3 => exact .inr rfl
  · refine ⟨position, Nat.le_refl _, ?_⟩
    match position, hne with
    | 0, hne | 1, hne => exact absurd rfl hne
    | 2, _ => rfl
    | position + 3, hne => exact absurd rfl hne

end RustFuture.Implementations

