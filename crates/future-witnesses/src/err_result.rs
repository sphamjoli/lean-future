//! A future whose output is an application-level failure.
//! Refutes: "`Ready` implies success" — output correctness is a separate,
//! implementation-specific specification.
pub async fn always_err() -> Result<u32, &'static str> {
    Err("refused")
}
