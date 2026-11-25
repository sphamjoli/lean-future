import RustFuture.Properties.Liveness
/-! Abstract state of `future_witnesses::oneshot`. The target is `NoLostWakeup`
for `correct::Receiver`. Status: open. -/
namespace RustFuture.Implementations

structure OneshotState where
  value : Bool
  -- waker id stored in the slot
  registered : Option Nat
  -- waker of the most recent poll
  latestPollWaker : Option Nat
  inPoll : Bool
  -- last poll returned `Pending`
  suspended : Bool
  -- the latest poll's waker has been woken since the future suspended (saturating stock)
  latestNotified : Bool
  -- the sender has taken the waker and will call `wake` after releasing the lock
  senderOwes : Bool

def oneshotObs : Properties.LostWakeObservables OneshotState where
  pending s := s.suspended = true
  valueAvailable s := s.value = true
  notificationOutstanding s := s.latestNotified = true
  pollInFlight s := s.inPoll = true
  senderOwesNotification s := s.senderOwes = true

end RustFuture.Implementations
