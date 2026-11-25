import RustFuture.Properties.Refinement
import RustFuture.Contracts.Executor
import RustFuture.Contracts.Assumptions
import RustFuture.Contracts.Witness
import RustFuture.Contracts.Environment
import RustFuture.Counterexamples.NonTermination
import RustFuture.Counterexamples.LostWake
import RustFuture.Counterexamples.StaleWaker
import RustFuture.Counterexamples.BusyExecutor
/-! Trust-base check. Every headline theorem must depend on no axioms beyond Lean's
core (`propext`, `Quot.sound`, `Classical.choice`). CI checks this output. -/
#print axioms RustFuture.Properties.verification_transfer
#print axioms RustFuture.Implementations.pendingModel_all_runs
#print axioms RustFuture.Counterexamples.termination_not_universal
#print axioms RustFuture.Counterexamples.buggy_violates_noLostWakeup
#print axioms RustFuture.Implementations.correct_noLostWakeup
#print axioms RustFuture.Implementations.correct_senderEventuallyPays
#print axioms RustFuture.Implementations.exampleRun_witness
#print axioms RustFuture.Counterexamples.stale_violates_latest
#print axioms RustFuture.Counterexamples.latest_satisfiable
#print axioms RustFuture.Contracts.wakeDelivery_refutable
#print axioms RustFuture.Contracts.progressNotifies_of_no_progress
#print axioms RustFuture.Contracts.assumptions_consistent
#print axioms RustFuture.Contracts.assumptions_consistent_live
#print axioms RustFuture.Implementations.pending_without_wake
#print axioms RustFuture.Counterexamples.will_wake_accepted
#print axioms RustFuture.Implementations.pendingTrace_wellFormed
#print axioms RustFuture.Counterexamples.epoch_not_confused
#print axioms RustFuture.Counterexamples.reusedCall_not_wellFormed
#print axioms RustFuture.Implementations.pendingTrace_callsMatched
#print axioms RustFuture.Counterexamples.busy_executor_does_not_hide
#print axioms RustFuture.Counterexamples.cancellation_discharges
