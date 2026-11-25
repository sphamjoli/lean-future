//! Single-value channel receivers: one conforming, one with a lost wake-up.
//!
//! The Lean model of both receivers is `RustFuture.Implementations.Oneshot`,
//! where `correct_noLostWakeup` proves the correct receiver never loses a
//! wake-up and `buggy_violates_noLostWakeup` proves the faulty one does.
//!
//! The slot is guarded by `parking_lot`'s mutex, which does not poison, so
//! taking the lock cannot fail.
use parking_lot::Mutex;
use std::future::Future;
use std::pin::Pin;
use std::sync::Arc;
use std::task::{Context, Poll, Waker};

struct Slot<T> {
    value: Option<T>,
    waker: Option<Waker>,
}

/// Sender half. `send` stores the value and wakes the *latest* registered waker.
pub struct Sender<T>(Arc<Mutex<Slot<T>>>);

impl<T> Sender<T> {
    /// Stores `value`, takes the registered waker under the lock, and wakes it
    /// after releasing the lock.
    pub fn send(self, value: T) {
        let taken = {
            let mut slot = self.0.lock();
            slot.value = Some(value);
            slot.waker.take()
        };
        if let Some(waker) = taken {
            waker.wake();
        }
    }
}

fn empty_slot<T>() -> Arc<Mutex<Slot<T>>> {
    Arc::new(Mutex::new(Slot {
        value: None,
        waker: None,
    }))
}

/// A channel whose receiver registers the waker of every poll.
pub fn channel<T>() -> (Sender<T>, correct::Receiver<T>) {
    let slot = empty_slot();
    (Sender(slot.clone()), correct::Receiver(slot))
}

/// A channel whose receiver registers only the first poll's waker.
pub fn buggy_channel<T>() -> (Sender<T>, buggy::Receiver<T>) {
    let slot = empty_slot();
    (Sender(slot.clone()), buggy::Receiver(slot))
}

/// The conforming receiver.
pub mod correct {
    use super::*;

    /// Receiver half that checks for the value and registers the waker under
    /// one lock, so no wake can be lost between the two.
    pub struct Receiver<T>(pub(super) Arc<Mutex<Slot<T>>>);

    impl<T> Future for Receiver<T> {
        type Output = T;
        fn poll(self: Pin<&mut Self>, context: &mut Context<'_>) -> Poll<T> {
            let mut slot = self.0.lock();
            match slot.value.take() {
                Some(value) => Poll::Ready(value),
                None => {
                    // Replacing any earlier waker keeps the latest one registered.
                    slot.waker = Some(context.waker().clone());
                    Poll::Pending
                }
            }
        }
    }
}

/// The faulty receiver.
pub mod buggy {
    use super::*;

    /// DELIBERATELY NON-CONFORMING. Registers the waker only on the first poll,
    /// so after a later poll with a fresh waker, `send` wakes a stale context
    /// and the latest-waker clause is broken. It compiles; the type system
    /// does not notice.
    pub struct Receiver<T>(pub(super) Arc<Mutex<Slot<T>>>);

    impl<T> Future for Receiver<T> {
        type Output = T;
        fn poll(self: Pin<&mut Self>, context: &mut Context<'_>) -> Poll<T> {
            let mut slot = self.0.lock();
            if let Some(value) = slot.value.take() {
                return Poll::Ready(value);
            }
            if slot.waker.is_none() {
                slot.waker = Some(context.waker().clone());
            }
            Poll::Pending
        }
    }
}
