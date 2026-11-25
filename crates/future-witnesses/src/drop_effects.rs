//! A future that performs an external side effect on its first poll and then
//! stays pending. Dropping it does not undo the effect.
//! Refutes: "dropping a future reverses its effects".
use std::future::Future;
use std::pin::Pin;
use std::sync::Arc;
use std::sync::atomic::{AtomicUsize, Ordering};
use std::task::{Context, Poll};

pub struct EffectThenPending {
    counter: Arc<AtomicUsize>,
}

pub fn effect_then_pending(counter: Arc<AtomicUsize>) -> EffectThenPending {
    EffectThenPending { counter }
}

impl Future for EffectThenPending {
    type Output = ();
    fn poll(self: Pin<&mut Self>, _cx: &mut Context<'_>) -> Poll<()> {
        self.counter.fetch_add(1, Ordering::SeqCst);
        Poll::Pending
    }
}
