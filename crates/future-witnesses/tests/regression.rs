//! Each test exhibits a recorded trace that a candidate axiom forbids.
//! If one of these stops being representable in the Lean model, the model is too strong.
use future_witnesses::*;
use trace_recorder::{Config, Event, PollResult, Schedule, ready_count, record};

#[test]
fn pending_never_completes() {
    let trace = record(
        pending::<u32>(),
        Config {
            schedule: Schedule::Always,
            ..Config::default()
        },
    );
    assert_eq!(ready_count(&trace), 0, "refutes: every future terminates");
}

#[test]
fn ready_completes_without_wake() {
    let trace = record(ready(42), Config::default());
    assert!(
        !trace
            .iter()
            .any(|event| matches!(event, Event::Wake { .. })),
        "refutes: futures must register/use a waker"
    );
    assert_eq!(ready_count(&trace), 1);
}

#[test]
fn self_wake_then_pending_again() {
    let trace = record(self_wake::yield_times(2), Config::default());
    // wake → poll → Pending: a wake does not imply the next poll is Ready.
    let returns: Vec<_> = trace
        .iter()
        .filter_map(|event| match event {
            Event::PollReturn { result, .. } => Some(result.clone()),
            _ => None,
        })
        .collect();
    assert_eq!(returns[..2], [PollResult::Pending, PollResult::Pending]);
    assert!(matches!(returns[2], PollResult::Ready(_)));
}

#[test]
fn repoll_after_ready_panics_without_ub() {
    let trace = record(
        repoll_panics::once(7u8),
        Config {
            schedule: Schedule::Always,
            poll_after_ready: true,
            ..Config::default()
        },
    );
    assert!(
        matches!(trace.last(), Some(Event::Panic { call: 1 })),
        "refutes: Ready is absorbing / re-poll idempotent"
    );
}

#[test]
fn ready_is_not_success() {
    let trace = record(err_result::always_err(), Config::default());
    assert!(
        matches!(&trace[2], Event::PollReturn { result: PollResult::Ready(s), .. } if s.starts_with("Err"))
    );
}

#[test]
fn correct_oneshot_wakes_latest_waker() {
    use std::task::{Context, Poll, Waker};
    let (tx, mut rx) = oneshot::channel::<u8>();
    let mut rx = std::pin::Pin::new(&mut rx);
    let (w1, c1) = counting_waker();
    let (w2, c2) = counting_waker();
    assert!(rx.as_mut().poll(&mut Context::from_waker(&w1)).is_pending());
    // spurious poll, new waker
    assert!(rx.as_mut().poll(&mut Context::from_waker(&w2)).is_pending());
    tx.send(1);
    assert_eq!((c1.get(), c2.get()), (0, 1));
    assert_eq!(
        rx.as_mut().poll(&mut Context::from_waker(Waker::noop())),
        Poll::Ready(1)
    );
}

#[test]
fn buggy_oneshot_loses_wake() {
    use std::task::Context;
    let (tx, mut rx) = oneshot::buggy_channel::<u8>();
    let mut rx = std::pin::Pin::new(&mut rx);
    let (w1, c1) = counting_waker();
    let (w2, c2) = counting_waker();
    let _ = rx.as_mut().poll(&mut Context::from_waker(&w1));
    let _ = rx.as_mut().poll(&mut Context::from_waker(&w2));
    tx.send(1);
    // The latest context (w2) is never notified: the contract violation the type system misses.
    assert_eq!((c1.get(), c2.get()), (1, 0));
}

fn counting_waker() -> (std::task::Waker, Counter) {
    use std::sync::{
        Arc,
        atomic::{AtomicUsize, Ordering},
    };
    struct CountingWake(Arc<AtomicUsize>);
    impl std::task::Wake for CountingWake {
        fn wake(self: Arc<Self>) {
            self.0.fetch_add(1, Ordering::SeqCst);
        }
    }
    let count = Arc::new(AtomicUsize::new(0));
    (
        std::task::Waker::from(Arc::new(CountingWake(count.clone()))),
        Counter(count),
    )
}
struct Counter(std::sync::Arc<std::sync::atomic::AtomicUsize>);
impl Counter {
    fn get(&self) -> usize {
        self.0.load(std::sync::atomic::Ordering::SeqCst)
    }
}

#[test]
fn drop_does_not_undo_effects() {
    use std::sync::{
        Arc,
        atomic::{AtomicUsize, Ordering},
    };
    let counter = Arc::new(AtomicUsize::new(0));
    let trace = record(
        drop_effects::effect_then_pending(counter.clone()),
        Config::default(),
    );
    assert!(matches!(trace.last(), Some(Event::Drop)));
    assert_eq!(
        counter.load(Ordering::SeqCst),
        1,
        "refutes: dropping a future reverses its effects"
    );
}

#[test]
fn async_fn_repoll_panics() {
    // A compiler-generated async fn state machine; the panic on re-poll is rustc
    // behaviour at the pinned release, not a documented std guarantee.
    async fn answer() -> u8 {
        42
    }
    let trace = record(
        answer(),
        Config {
            schedule: Schedule::Always,
            poll_after_ready: true,
            ..Config::default()
        },
    );
    assert!(matches!(trace.last(), Some(Event::Panic { call: 1 })));
}
