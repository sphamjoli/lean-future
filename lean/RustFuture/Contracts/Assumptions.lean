import RustFuture.Rust.Pin
import RustFuture.Semantics.WellFormed
import RustFuture.Contracts.Future
import RustFuture.Contracts.Executor
import RustFuture.Contracts.Environment
import RustFuture.Implementations.Pending
/-! Every assumption of the model, in one place.

These are deliberately not Lean `axiom`s. A global axiom would hold for every
future at once, could never be discharged by a particular implementation, and,
if two axioms contradicted each other, would let Lean prove anything silently.

Conformance is split in two. Memory safety (`NoUB`) is required whenever access
is valid, whatever the caller or executor does. The protocol obligations are
required only when the caller and executor keep their side of the protocol. -/
namespace RustFuture.Contracts
open RustFuture

/-- The three outside models the future model depends on. -/
structure Context (σ α : Type) where
  -- Rule 1: exclusive access and pin validity (supplied by a Rust memory model)
  memory : Rust.PinModel σ
  -- Rule 3: wakers, task liveness and happens-before (supplied by an executor model)
  executor : ExecutorModel α
  -- Rule 4: progress opportunity and interest (supplied by an environment model)
  environment : EnvironmentModel σ

/-- Rule 1 over a run: every visit starts from a state with valid access. -/
def ValidAccess {σ α : Type} (C : Context σ α) (s : Nat → σ) (t : Trace α) : Prop :=
  ∀ i, PollBeginAt t i → C.memory.ValidPoll (s i)

/-- The protocol assumptions on a single run `(s, t)` in context `C`. -/
structure Assumptions {σ α : Type} (C : Context σ α) (s : Nat → σ) (t : Trace α) : Prop where
  validAccess : ValidAccess C s t
  -- Rule 2: the caller does not poll after Ready
  callerProtocol : CallerStopsAtReady t
  -- Rule 3: wakes on live tasks are delivered
  wakeDelivery : WakeDelivery C.executor t

/-- The protocol obligations a conforming future must meet on such a run. -/
structure ProtocolObligations {σ α : Type} (C : Context σ α) (s : Nat → σ) (t : Trace α) : Prop where
  latestWaker : WakesLatest C.executor.env t
  -- Rule 4: progress obligates notification
  progressNotifies : ProgressNotifies C.executor.env C.environment s t

/-- Memory safety: on every well-formed run with valid access, no undefined
behaviour and every return answers a call, even if the caller polls after
`Ready` or after catching a panic, or the executor misbehaves. -/
def SafetyConforms {σ α : Type} (C : Context σ α) (M : FutureModel σ α) : Prop :=
  ∀ s t, M.IsRunWith s t → WellFormed t → ValidAccess C s t → NoUB t ∧ CallsMatched t

/-- Protocol correctness: on every well-formed run meeting the assumptions, the
protocol obligations hold. -/
def ProtocolConforms {σ α : Type} (C : Context σ α) (M : FutureModel σ α) : Prop :=
  ∀ s t, M.IsRunWith s t → WellFormed t → Assumptions C s t → ProtocolObligations C s t

/-- A future model conforms when it is both memory safe and protocol correct. -/
def Conforms {σ α : Type} (C : Context σ α) (M : FutureModel σ α) : Prop :=
  SafetyConforms C M ∧ ProtocolConforms C M

/-- The weakest context: access always valid, no task ever live, progress never
possible. Used only to show the bundle is consistent. -/
def trivialContext (α : Type) : Context Unit α where
  memory := { exclusiveAccess := fun _ => True, isUnpin := True, pinValid := fun _ => True,
              unpin_trivial := fun _ _ => trivial }
  executor := { env := ⟨id⟩, liveFrom := fun _ _ => False, hb := (· < ·),
                hb_trans := fun _ _ _ => Nat.lt_trans, hb_forward := fun _ _ h => h }
  environment := { progressOpportunity := fun _ => False, stillInterested := fun _ => True }

/-- Every rule holds together on the pending future's canonical run, which is
also well formed. The conditional rules hold only because their triggers never
fire there; `assumptions_consistent_live` is the stronger witness. -/
theorem assumptions_consistent :
    ∃ (C : Context Unit Nat) (s : Nat → Unit) (t : Trace Nat),
      (Implementations.pendingModel Nat).IsRunWith s t ∧ WellFormed t ∧
        Assumptions C s t ∧ NoUB t ∧ CallsMatched t ∧ ProtocolObligations C s t := by
  obtain ⟨s, hrun⟩ := Implementations.pendingTrace_is_run Nat
  refine ⟨trivialContext Nat, s, Implementations.pendingTrace Nat, hrun,
    Implementations.pendingTrace_wellFormed Nat, ⟨?_, ?_, ?_⟩,
    (Implementations.pendingModel_all_runs Nat _ ⟨s, hrun⟩).1,
    Implementations.pendingTrace_callsMatched Nat, ⟨?_, ?_⟩⟩
  · exact fun _ _ => ⟨trivial, trivial⟩
  · rintro i ⟨c, v, h⟩; unfold Implementations.pendingTrace at h; split at h <;> simp at h
  · intro i w h; unfold Implementations.pendingTrace at h; split at h <;> simp at h
  · intro b i w _ k w' _ _ h; unfold Implementations.pendingTrace at h; split at h <;> simp at h
  · exact progressNotifies_of_no_progress _ _ _ _ (fun _ h => h)

end RustFuture.Contracts
