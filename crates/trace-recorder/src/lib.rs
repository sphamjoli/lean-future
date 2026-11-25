//! Records concrete executions of a Rust `Future` as finite trace prefixes.
//!
//! The event vocabulary mirrors `RustFuture.Semantics.Trace.Event` in the Lean
//! project. A recorded trace is the *concrete* side of the refinement
//! `π(Traces(R)) ⊆ Traces(M)`; it is evidence that a behaviour is
//! representable, never a proof that the model is complete.
//!
//! Limits (deliberate, see README):
//! * one task, one thread — no concurrent wakes during a poll are produced;
//! * traces are finite prefixes, so they can refute safety properties but can
//!   neither prove nor refute liveness properties;
//! * a poll that panics is recorded as `Panic` and ends the trace.

use serde::Serialize;
use std::future::Future;
use std::panic::{AssertUnwindSafe, catch_unwind};
use std::pin::Pin;
use std::sync::atomic::{AtomicBool, AtomicUsize, Ordering};
use std::sync::{Arc, Mutex};
use std::task::{Context, Poll, Wake, Waker};

pub type CallId = usize;
pub type WakerId = usize;
pub type TaskId = usize;

/// Abstract poll result. The output is rendered with `Debug` so that traces of
/// any `Output` type are comparable.
#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
pub enum PollResult {
    Pending,
    Ready(String),
}

/// Mirrors the Lean `Event` constructors that a single-threaded harness can observe.
#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
pub enum Event {
    TaskPollBegin { task: TaskId },
    PollBegin { call: CallId, waker: WakerId },
    PollReturn { call: CallId, result: PollResult },
    Wake { waker: WakerId },
    Panic { call: CallId },
    Drop,
}

#[derive(Default)]
struct Shared {
    log: Mutex<Vec<Event>>,
    woken: AtomicBool,
}

impl Shared {
    /// Locks the event log. No code panics while holding this lock, so it is
    /// never poisoned.
    fn log(&self) -> std::sync::MutexGuard<'_, Vec<Event>> {
        self.log
            .lock()
            .expect("trace log mutex is never poisoned: no code panics while holding it")
    }
}

struct RecordingWaker {
    id: WakerId,
    shared: Arc<Shared>,
}

impl Wake for RecordingWaker {
    fn wake(self: Arc<Self>) {
        self.wake_by_ref()
    }
    fn wake_by_ref(self: &Arc<Self>) {
        self.shared.log().push(Event::Wake { waker: self.id });
        self.shared.woken.store(true, Ordering::SeqCst);
    }
}

/// When the harness polls again.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Schedule {
    /// Re-poll only after a wake (a well-behaved executor).
    OnWake,
    /// Re-poll unconditionally (spurious polls are permitted by the contract).
    Always,
}

#[derive(Debug, Clone, Copy)]
pub struct Config {
    pub max_polls: usize,
    pub schedule: Schedule,
    /// Keep polling after `Ready` — violates the *caller* protocol on purpose,
    /// to observe post-completion behaviour.
    pub poll_after_ready: bool,
    /// Use a fresh waker on each poll (exercises latest-waker semantics).
    pub fresh_waker_per_poll: bool,
}

impl Default for Config {
    fn default() -> Self {
        Self {
            max_polls: 16,
            schedule: Schedule::OnWake,
            poll_after_ready: false,
            fresh_waker_per_poll: true,
        }
    }
}

/// Run `fut` as task 0 and return the recorded trace prefix.
pub fn record<F>(fut: F, cfg: Config) -> Vec<Event>
where
    F: Future,
    F::Output: std::fmt::Debug,
{
    let shared = Arc::new(Shared::default());
    let next_waker = AtomicUsize::new(0);
    let mk_waker = || {
        let id = next_waker.fetch_add(1, Ordering::SeqCst);
        (
            id,
            Waker::from(Arc::new(RecordingWaker {
                id,
                shared: shared.clone(),
            })),
        )
    };
    let push = |e| shared.log().push(e);

    let mut fut = Box::pin(fut);
    let (mut wid, mut waker) = mk_waker();
    let mut done = false;

    for call in 0..cfg.max_polls {
        if call > 0 {
            if done && !cfg.poll_after_ready {
                break;
            }
            if cfg.schedule == Schedule::OnWake && !shared.woken.swap(false, Ordering::SeqCst) {
                // no wake outstanding: a conforming executor stays idle
                break;
            }
            if cfg.fresh_waker_per_poll {
                (wid, waker) = mk_waker();
            }
        }
        shared.woken.store(false, Ordering::SeqCst);
        push(Event::TaskPollBegin { task: 0 });
        push(Event::PollBegin { call, waker: wid });
        let mut cx = Context::from_waker(&waker);
        match catch_unwind(AssertUnwindSafe(|| Pin::as_mut(&mut fut).poll(&mut cx))) {
            Ok(Poll::Pending) => push(Event::PollReturn {
                call,
                result: PollResult::Pending,
            }),
            Ok(Poll::Ready(v)) => {
                push(Event::PollReturn {
                    call,
                    result: PollResult::Ready(format!("{v:?}")),
                });
                done = true;
            }
            Err(_) => {
                push(Event::Panic { call });
                let log = shared.log().clone();
                return log;
            }
        }
    }
    drop(fut);
    push(Event::Drop);
    shared.log().clone()
}

/// Serialise a trace for consumption by the Lean side (`lake exe checktrace`, future work).
pub fn to_json(trace: &[Event]) -> String {
    serde_json::to_string_pretty(trace).expect("trace is serialisable")
}

/// Count `PollReturn … Ready` events.
pub fn ready_count(trace: &[Event]) -> usize {
    trace
        .iter()
        .filter(|e| {
            matches!(
                e,
                Event::PollReturn {
                    result: PollResult::Ready(_),
                    ..
                }
            )
        })
        .count()
}

#[cfg(test)]
mod tests {
    use super::*;

    /// The exported JSON names each event and its fields, so a recording can be
    /// read by a checker outside Rust.
    #[test]
    fn json_export_names_events_and_fields() {
        let trace = record(std::future::ready(7u8), Config::default());
        let json: serde_json::Value =
            serde_json::from_str(&to_json(&trace)).expect("to_json emits valid JSON");
        let events = json.as_array().expect("a trace is a JSON array");
        assert_eq!(events.len(), trace.len());
        assert_eq!(events[1]["PollBegin"]["call"], 0);
        assert_eq!(events[2]["PollReturn"]["result"]["Ready"], "7");
        assert_eq!(events.last(), Some(&serde_json::json!("Drop")));
    }
}
