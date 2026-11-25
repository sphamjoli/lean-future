import RustFuture.Rust.Pin
import RustFuture.Contracts.Future
import RustFuture.Contracts.Executor
import RustFuture.Contracts.Environment
import RustFuture.Implementations.Pending
/-! Every assumption of the model, in one place.

These are deliberately not Lean `axiom`s. A global axiom would hold for every
future at once, could never be discharged by a particular implementation, and,
if two axioms contradicted each other, would let Lean prove anything silently.
Instead, `Assumptions` is a structure: a theorem that needs the assumptions
takes one as a hypothesis, `#print axioms` stays clean, and
`assumptions_consistent` shows the bundle can actually be met. -/
namespace RustFuture.Contracts
open RustFuture

/-- The three outside models the future model depends on. -/
structure Context (σ α : Type) where
  -- Rule 1: exclusive access and pin validity (supplied by a Rust memory model)
  memory : Rust.PinModel σ
  -- Rule 3: task liveness and happens-before (supplied by an executor model)
  executor : ExecutorModel α
  -- Rule 4: progress opportunity and interest (supplied by an environment model)
  environment : EnvironmentModel σ

/-- The assumptions on a single run `(s, t)` of a future in context `C`. -/
structure Assumptions {σ α : Type} (C : Context σ α) (s : Nat → σ) (t : Trace α) : Prop where
  -- Rule 1: every poll starts from a state with valid access
  validAccess : ∀ i, PollBeginAt t i → C.memory.ValidPoll (s i)
  -- Rule 2: the caller does not poll after Ready
  callerProtocol : CallerStopsAtReady t
  -- Rule 3: wakes on live tasks are delivered
  wakeDelivery : WakeDelivery C.executor t

/-- The obligations a conforming future must meet on such a run. -/
structure Obligations {σ α : Type} (C : Context σ α) (s : Nat → σ) (t : Trace α) : Prop where
  noUB : NoUB t
  latestWaker : WakesLatest t
  -- Rule 4: progress obligates notification
  progressNotifies : ProgressNotifies C.environment s t

/-- A future model conforms in context `C` if every run that meets the
assumptions also meets the obligations. -/
def Conforms {σ α : Type} (C : Context σ α) (M : FutureModel σ α) : Prop :=
  ∀ s t, M.IsRunWith s t → Assumptions C s t → Obligations C s t

/-- A context with trivially valid access, an executor whose tasks are never
live, and an environment where progress never becomes possible. It is the
weakest possible context, used only to show the bundle is consistent. -/
def trivialContext (α : Type) : Context Unit α where
  memory := { exclusiveAccess := fun _ => True, isUnpin := True, pinValid := fun _ => True,
              unpin_trivial := fun _ _ => trivial }
  executor := { env := ⟨id⟩, liveFrom := fun _ _ => False, hb := (· < ·),
                hb_of_lt := fun _ _ h => h, hb_trans := fun _ _ _ => Nat.lt_trans }
  environment := { progressOpportunity := fun _ => False, stillInterested := fun _ => True }

/-- The assumptions and obligations are jointly satisfiable: the pending
future's canonical run meets all of them. So they cannot be contradictory,
which a set of global axioms could never demonstrate about itself. -/
theorem assumptions_consistent :
    ∃ (C : Context Unit Nat) (s : Nat → Unit) (t : Trace Nat),
      (Implementations.pendingModel Nat).IsRunWith s t ∧ Assumptions C s t ∧ Obligations C s t := by
  obtain ⟨s, hrun⟩ := Implementations.pendingTrace_is_run Nat
  refine ⟨trivialContext Nat, s, Implementations.pendingTrace Nat, hrun, ⟨?_, ?_, ?_⟩, ⟨?_, ?_, ?_⟩⟩
  · exact fun _ _ => ⟨trivial, trivial⟩
  · rintro i ⟨c, v, h⟩; unfold Implementations.pendingTrace at h; split at h <;> simp at h
  · intro i w h; unfold Implementations.pendingTrace at h; split at h <;> simp at h
  · exact (Implementations.pendingModel_all_runs Nat _ ⟨s, hrun⟩).1
  · intro i w _ k w' _ _ h; unfold Implementations.pendingTrace at h; split at h <;> simp at h
  · exact progressNotifies_of_no_progress _ _ _ (fun _ h => h)

end RustFuture.Contracts
