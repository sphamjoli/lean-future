//! Completes once, then panics if polled again — exactly what `async fn`
//! state machines do ("`async fn` resumed after completion").
//! Refutes: "polling after completion is idempotent" and "Ready is absorbing".
//! Still conforming: a panic is not undefined behaviour.
use std::future::Future;
use std::pin::Pin;
use std::task::{Context, Poll};

pub struct Once<T>(Option<T>);

pub fn once<T>(v: T) -> Once<T> {
    Once(Some(v))
}

impl<T: Unpin> Future for Once<T> {
    type Output = T;
    /// # Panics
    ///
    /// Panics when polled after it has returned `Ready`. That panic is the
    /// behaviour this witness exists to show.
    fn poll(mut self: Pin<&mut Self>, _context: &mut Context<'_>) -> Poll<T> {
        match self.0.take() {
            Some(value) => Poll::Ready(value),
            None => panic!("Once polled after completion"),
        }
    }
}
