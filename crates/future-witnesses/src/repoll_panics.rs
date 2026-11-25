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
    fn poll(mut self: Pin<&mut Self>, _cx: &mut Context<'_>) -> Poll<T> {
        Poll::Ready(self.0.take().expect("Once polled after completion"))
    }
}
