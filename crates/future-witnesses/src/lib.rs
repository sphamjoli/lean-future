//! Specification regression suite, concrete side.
//!
//! Each module is a *valid* Rust future (it compiles, uses only safe code and
//! never causes UB). Each one refutes at least one property that must therefore
//! NOT be an axiom of the Lean `Future` contract. The mapping is recorded in
//! `spec/claims.toml` (`refuted_by`) and mirrored in `lean/RustFuture/Counterexamples`.
//!
//! `oneshot::buggy` is the exception: it is deliberately *non-conforming*
//! (lost wake-up) and exists so the contract has a negative test.
#![forbid(unsafe_code)]

pub mod drop_effects;
pub mod err_result;
pub mod oneshot;
pub mod repoll_panics;
pub mod self_wake;

/// `std::future::pending()` — never completes. Refutes "every future terminates".
pub fn pending<T>() -> std::future::Pending<T> {
    std::future::pending()
}

/// `std::future::ready(v)` — completes on first poll without touching the waker.
/// Refutes "every Pending-free future registers a waker" and "every poll is preceded by a wake".
pub fn ready<T>(v: T) -> std::future::Ready<T> {
    std::future::ready(v)
}
