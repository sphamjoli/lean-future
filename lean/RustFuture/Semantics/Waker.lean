/-! Wakers and tasks are identities, not behaviour. A wake concerns the *task*
a waker belongs to (`taskOf`), not an individual future. -/
namespace RustFuture

abbrev TaskId := Nat
abbrev WakerId := Nat
abbrev CallId := Nat

/-- The executor-supplied association of wakers to tasks. Grounded by the
executor model, never chosen to make a proof go through. -/
structure WakerEnv where
  taskOf : WakerId → TaskId

end RustFuture
