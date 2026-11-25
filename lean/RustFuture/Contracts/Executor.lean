import RustFuture.Semantics.Future
/-! Executor obligations (Rule 3, conditional wake delivery).

`hb` (happens-before) is supplied by the executor model, not derived from trace
positions: two events appearing in order in a trace do not by themselves
establish a memory-model happens-before edge. The model only requires `hb` to
chain and to point forwards in the trace; beyond that an executor model may
choose it freely, including as plain trace order. Deriving `hb` from program
order and synchronisation is open work. -/
namespace RustFuture.Contracts
open RustFuture

structure ExecutorModel (α : Type) where
  env : WakerEnv
  liveFrom : Nat → TaskId → Prop
  hb : Nat → Nat → Prop
  hb_trans : ∀ i j k, hb i j → hb j k → hb i k
  hb_forward : ∀ i j, hb i j → i < j

/-- Every wake on a live task is followed by a later poll of that task that the
wake happens before. One poll may discharge many wakes. Nothing is said about
the result of that poll, child futures, fairness or latency. -/
def WakeDelivery {α : Type} (X : ExecutorModel α) (t : Trace α) : Prop :=
  ∀ i w, t i = .wake w → X.liveFrom i (X.env.taskOf w) →
    ∃ j, i < j ∧ X.hb i j ∧ t j = .taskPollBegin (X.env.taskOf w)

/-- An executor conforms if every trace it produces delivers wakes. -/
def ExecutorConforms {α : Type} (X : ExecutorModel α) (produces : Trace α → Prop) : Prop :=
  ∀ t, produces t → WakeDelivery X t

/-- Sanity: delivery is refutable. A wake on a live task with no later poll of
that task violates it. -/
theorem wakeDelivery_refutable {α : Type} (X : ExecutorModel α) (t : Trace α) (i : Nat) (w : WakerId)
    (hw : t i = .wake w) (hl : X.liveFrom i (X.env.taskOf w))
    (hn : ∀ j, i < j → t j ≠ .taskPollBegin (X.env.taskOf w)) :
    ¬ WakeDelivery X t := by
  intro h
  obtain ⟨j, hij, _, hj⟩ := h i w hw hl
  exact hn j hij hj

end RustFuture.Contracts
