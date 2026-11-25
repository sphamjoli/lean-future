import RustFuture.Semantics.Trace
/-! Execution well-formedness shared by every future.

`WellFormed` constrains only what the caller and executor do: when visits begin,
and when the future is dropped or the program aborts. It deliberately says
nothing about what the future returns, so that a misbehaving future cannot
escape its safety obligation by producing an ill-formed trace. What the future
owes about its own returns is `CallsMatched`, an obligation. -/
namespace RustFuture

/-- Visit `c` ends at position `k`, either by returning or by panicking. -/
def EndsAt {α : Type} (t : Trace α) (k : Nat) (c : CallId) : Prop :=
  (∃ r, t k = .pollReturn c r) ∨ t k = .panic c

/-- The future has been dropped, or the program has aborted, at position `i`.
A panic is not terminal: safe Rust can catch it and poll again. -/
def TerminalAt {α : Type} (t : Trace α) (i : Nat) : Prop :=
  t i = .drop ∨ t i = .abort

structure WellFormed {α : Type} (t : Trace α) : Prop where
  -- each visit number is used by at most one visit
  uniqueCalls : ∀ i j c w w', t i = .pollBegin c w → t j = .pollBegin c w' → i = j
  -- visits do not overlap: some visit ends before the next one begins (which
  -- visit is left to `CallsMatched`, since end events are the future's output)
  noOverlap : ∀ i c w j c' w', i < j → t i = .pollBegin c w → t j = .pollBegin c' w' →
    ∃ k c'', i < k ∧ k < j ∧ EndsAt t k c''
  -- nothing is polled after the future is dropped or the program aborts
  nothingAfterTerminal : ∀ i, TerminalAt t i → ∀ j, i < j → ¬ PollBeginAt t j

/-- An obligation on the future: every return or panic answers a visit that
began earlier, and each visit ends at most once. -/
structure CallsMatched {α : Type} (t : Trace α) : Prop where
  endMatchesBegin : ∀ k c, EndsAt t k c → ∃ b w, b < k ∧ t b = .pollBegin c w
  endsOnce : ∀ k k' c, EndsAt t k c → EndsAt t k' c → k = k'

end RustFuture
