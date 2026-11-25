import RustFuture.Semantics.Future
/-! Self-waking future (`yield_times n` in `future-witnesses`). Status: modelled
shape only; the `wake`-inside-poll ordering proof is open. -/
namespace RustFuture.Implementations
open RustFuture

def yieldModel (n : Nat) : FutureModel Nat Unit where
  initial k := k = n
  step k e k' := match e with
    | .wake _ => k' = k
    | .pollReturn _ .pending => 0 < k ∧ k' = k - 1
    | .pollReturn _ (.ready ()) => k = 0 ∧ k' = 0
    | .undefinedBehaviour => False
    | _ => k' = k

end RustFuture.Implementations
