//! A future that wakes itself before returning `Pending` (cf. `tokio::task::yield_now`).
//! Refutes: "wakes must originate externally" and "a wake implies the next poll is Ready"
//! (with `n > 1` the next poll after a wake is again `Pending`).
use std::future::Future;
use std::pin::Pin;
use std::task::{Context, Poll};

pub struct YieldTimes {
    remaining: u32,
}

pub fn yield_times(n: u32) -> YieldTimes {
    YieldTimes { remaining: n }
}

impl Future for YieldTimes {
    type Output = ();
    fn poll(mut self: Pin<&mut Self>, cx: &mut Context<'_>) -> Poll<()> {
        if self.remaining == 0 {
            return Poll::Ready(());
        }
        self.remaining -= 1;
        cx.waker().wake_by_ref();
        Poll::Pending
    }
}
