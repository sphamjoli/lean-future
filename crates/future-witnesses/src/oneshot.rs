//! Single-value channel receivers: one conforming, one with a lost wake-up.
//!
//! Target theorem (`Properties/Liveness.lean`, `NoLostWakeup`):
//! `Pending ∧ ValueAvailable → NotificationOutstanding ∨ PollInFlight`.
use std::future::Future;
use std::pin::Pin;
use std::sync::{Arc, Mutex};
use std::task::{Context, Poll, Waker};

struct Slot<T> {
    value: Option<T>,
    waker: Option<Waker>,
}

/// Sender half. `send` stores the value and wakes the *latest* registered waker.
pub struct Sender<T>(Arc<Mutex<Slot<T>>>);

impl<T> Sender<T> {
    pub fn send(self, v: T) {
        let waker = {
            let mut s = self.0.lock().unwrap();
            s.value = Some(v);
            s.waker.take()
        };
        if let Some(w) = waker {
            w.wake();
        }
    }
}

pub fn channel<T>() -> (Sender<T>, correct::Receiver<T>) {
    let slot = Arc::new(Mutex::new(Slot {
        value: None,
        waker: None,
    }));
    (Sender(slot.clone()), correct::Receiver(slot))
}

pub fn buggy_channel<T>() -> (Sender<T>, buggy::Receiver<T>) {
    let slot = Arc::new(Mutex::new(Slot {
        value: None,
        waker: None,
    }));
    (Sender(slot.clone()), buggy::Receiver(slot))
}

pub mod correct {
    use super::*;
    pub struct Receiver<T>(pub(super) Arc<Mutex<Slot<T>>>);

    impl<T> Future for Receiver<T> {
        type Output = T;
        fn poll(self: Pin<&mut Self>, cx: &mut Context<'_>) -> Poll<T> {
            // Check and register under one lock: no window for a lost wake.
            let mut s = self.0.lock().unwrap();
            match s.value.take() {
                Some(v) => Poll::Ready(v),
                None => {
                    // replaces any stale waker
                    s.waker = Some(cx.waker().clone());
                    Poll::Pending
                }
            }
        }
    }
}

pub mod buggy {
    use super::*;
    /// DELIBERATELY NON-CONFORMING. Registers the waker only on the first poll,
    /// so after a spurious poll with a fresh waker, `send` wakes a stale context
    /// (the latest-waker clause is violated). Compiles; type system is silent.
    pub struct Receiver<T>(pub(super) Arc<Mutex<Slot<T>>>);

    impl<T> Future for Receiver<T> {
        type Output = T;
        fn poll(self: Pin<&mut Self>, cx: &mut Context<'_>) -> Poll<T> {
            let mut s = self.0.lock().unwrap();
            if let Some(v) = s.value.take() {
                return Poll::Ready(v);
            }
            if s.waker.is_none() {
                s.waker = Some(cx.waker().clone());
            }
            Poll::Pending
        }
    }
}
