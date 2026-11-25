//! Records concrete executions of a Rust `Future` as finite trace prefixes.
//!
//! The event vocabulary mirrors `RustFuture.Semantics.Trace.Event` in the Lean
//! project. A recorded trace is the *concrete* side of the refinement
//! `π(Traces(R)) ⊆ Traces(M)`; it is evidence that a behaviour is
//! representable, never a proof that the model is complete.
//!
//! Limits (deliberate, see README):
//! * one task, one thread: no concurrent wakes during a poll are produced;
//! * traces are finite prefixes, so they can refute safety properties but can
//!   neither prove nor refute liveness properties;
//! * a poll that panics is recorded as `Panic` and ends the trace.

use parking_lot::Mutex;
use serde::Serialize;
use std::future::Future;
use std::panic::{AssertUnwindSafe, catch_unwind};
use std::sync::Arc;
use std::sync::atomic::{AtomicBool, AtomicUsize, Ordering};
use std::task::{Context, Poll, Wake, Waker};
use thiserror::Error;

/// Number of a poll call within one recording.
pub type CallId = usize;
/// Number of a waker within one recording.
pub type WakerId = usize;
/// Number of a task within one recording.
pub type TaskId = usize;

/// Abstract poll result. The output is rendered with `Debug` so that traces of
/// any `Output` type are comparable.
#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
pub enum PollResult {
    /// The poll returned `Pending`.
    Pending,
    /// The poll returned `Ready` with this `Debug` rendering of the output.
    Ready(String),
}

/// Mirrors the Lean `Event` constructors that a single-threaded harness can observe.
#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
pub enum Event {
    /// The executor picks up the task.
    TaskPollBegin {
        /// The task picked up.
        task: TaskId,
    },
    /// A poll begins with the given waker.
    PollBegin {
        /// The poll's number.
        call: CallId,
        /// The waker passed to the poll.
        waker: WakerId,
    },
    /// A poll returns.
    PollReturn {
        /// The poll's number.
        call: CallId,
        /// What the poll returned.
        result: PollResult,
    },
    /// A waker is woken.
    Wake {
        /// The waker woken.
        waker: WakerId,
    },
    /// A poll panics.
    Panic {
        /// The poll that panicked.
        call: CallId,
    },
    /// The future is dropped.
    Drop,
}

/// Failure to export a trace.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Error)]
pub enum ExportError {
    /// The trace could not be encoded as JSON.
    #[error("trace-not-encodable: the trace could not be encoded as JSON")]
    NotEncodable,
}

/// State shared between the recorder and its wakers. `parking_lot`'s mutex
/// does not poison, so taking the lock cannot fail.
#[derive(Default)]
struct Shared {
    log: Mutex<Vec<Event>>,
    woken: AtomicBool,
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
        self.shared.log.lock().push(Event::Wake { waker: self.id });
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

/// How a recording is run.
#[derive(Debug, Clone, Copy)]
pub struct Config {
    /// The most polls to make before stopping.
    pub max_polls: usize,
    /// When to poll again.
    pub schedule: Schedule,
    /// Keep polling after `Ready`. This breaks the *caller* protocol on purpose,
    /// to observe post-completion behaviour.
    pub poll_after_ready: bool,
    /// Use a fresh waker on each poll, to exercise latest-waker semantics.
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

/// Runs `future` as task 0 and returns the recorded trace prefix.
pub fn record<F>(future: F, config: Config) -> Vec<Event>
where
    F: Future,
    F::Output: std::fmt::Debug,
{
    let shared = Arc::new(Shared::default());
    let next_waker = AtomicUsize::new(0);
    let new_waker = || {
        let id = next_waker.fetch_add(1, Ordering::SeqCst);
        let waker = Waker::from(Arc::new(RecordingWaker {
            id,
            shared: shared.clone(),
        }));
        (id, waker)
    };
    let push = |event| shared.log.lock().push(event);

    let mut future = Box::pin(future);
    let (mut waker_id, mut waker) = new_waker();
    let mut finished = false;

    for call in 0..config.max_polls {
        if call > 0 {
            if finished && !config.poll_after_ready {
                break;
            }
            // With no wake outstanding, a conforming executor stays idle.
            if config.schedule == Schedule::OnWake && !shared.woken.swap(false, Ordering::SeqCst) {
                break;
            }
            if config.fresh_waker_per_poll {
                (waker_id, waker) = new_waker();
            }
        }
        shared.woken.store(false, Ordering::SeqCst);
        push(Event::TaskPollBegin { task: 0 });
        push(Event::PollBegin {
            call,
            waker: waker_id,
        });
        let mut context = Context::from_waker(&waker);
        let outcome = catch_unwind(AssertUnwindSafe(|| future.as_mut().poll(&mut context)));
        match outcome {
            Ok(Poll::Pending) => push(Event::PollReturn {
                call,
                result: PollResult::Pending,
            }),
            Ok(Poll::Ready(output)) => {
                push(Event::PollReturn {
                    call,
                    result: PollResult::Ready(format!("{output:?}")),
                });
                finished = true;
            }
            Err(_) => {
                push(Event::Panic { call });
                return shared.log.lock().clone();
            }
        }
    }
    drop(future);
    push(Event::Drop);
    shared.log.lock().clone()
}

/// Serialises a trace as JSON, for a checker outside Rust.
///
/// # Errors
///
/// Returns [`ExportError::NotEncodable`] if the trace cannot be encoded.
pub fn to_json(trace: &[Event]) -> Result<String, ExportError> {
    serde_json::to_string_pretty(trace).map_err(|_| ExportError::NotEncodable)
}

/// Counts the polls in `trace` that returned `Ready`.
pub fn ready_count(trace: &[Event]) -> usize {
    trace
        .iter()
        .filter(|event| {
            matches!(
                event,
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

    /// Why the exported JSON did not have the expected shape.
    #[derive(Debug, Error)]
    enum ShapeError {
        #[error("json-invalid: the export is not valid JSON")]
        InvalidJson,
        #[error("json-not-array: the export is not a JSON array")]
        NotArray,
        #[error(transparent)]
        Export(#[from] ExportError),
    }

    /// The exported JSON names each event and its fields, so a recording can be
    /// read by a checker outside Rust.
    #[test]
    fn json_export_names_events_and_fields() -> Result<(), ShapeError> {
        let trace = record(std::future::ready(7u8), Config::default());
        let json: serde_json::Value =
            serde_json::from_str(&to_json(&trace)?).map_err(|_| ShapeError::InvalidJson)?;
        let events = json.as_array().ok_or(ShapeError::NotArray)?;
        assert_eq!(events.len(), trace.len());
        assert_eq!(events[1]["PollBegin"]["call"], 0);
        assert_eq!(events[2]["PollReturn"]["result"]["Ready"], "7");
        assert_eq!(events.last(), Some(&serde_json::json!("Drop")));
        Ok(())
    }
}
