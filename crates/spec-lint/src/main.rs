//! `cargo run -p spec-lint` fails if the claim catalogue drifts from the code.
//!
//! Rules (the catalogue indexes evidence, it never upgrades it):
//! 1. every claim has a `source` URL into doc.rust-lang.org (pinned version);
//! 2. `status` and `kind` come from the fixed vocabularies below;
//! 3. a `lean` reference names a declaration that textually exists under `lean/`;
//! 4. a `refuted_by` reference names a test that exists in `future-witnesses`;
//! 5. `kind = "rejected"` claims must have `refuted_by` (a rejected axiom needs a witness);
//! 6. `status = "proved"` requires a `lean` reference;
//! 7. a proved claim's declaration must be listed by a `#print axioms` line in
//!    the soundness file, so its trust base is checked in CI.
//!
//! The same failure prints the same bytes on every machine: each line is
//! `spec-lint: <code>: <message>`, files are named by their role, and
//! operating-system messages are reduced to a fixed word.

use serde::Deserialize;
use std::fmt;
use std::{fs, io, path::Path, process::ExitCode};
use thiserror::Error;

const KINDS: &[&str] = &[
    "type_level",
    "permitted",
    "rejected",
    "contract",
    "caller_protocol",
    "executor",
    "implementation",
];
const STATUSES: &[&str] = &["proved", "modelled", "assumed", "open"];

#[derive(Deserialize)]
struct Catalogue {
    rust_version: String,
    claim: Vec<Claim>,
}

#[derive(Deserialize)]
struct Claim {
    id: String,
    kind: String,
    status: String,
    source: String,
    lean: Option<String>,
    refuted_by: Option<String>,
}

/// Which input a read was about.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum SourceRole {
    Catalogue,
    LeanSources,
    WitnessSources,
    TrustBaseList,
}

impl fmt::Display for SourceRole {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        formatter.write_str(match self {
            Self::Catalogue => "claim catalogue",
            Self::LeanSources => "Lean sources",
            Self::WitnessSources => "witness sources",
            Self::TrustBaseList => "trust-base list",
        })
    }
}

/// Why a read failed, reduced to a fixed word.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum IoFailure {
    NotFound,
    PermissionDenied,
    NotUtf8,
    Other,
}

impl From<&io::Error> for IoFailure {
    fn from(error: &io::Error) -> Self {
        match error.kind() {
            io::ErrorKind::NotFound => Self::NotFound,
            io::ErrorKind::PermissionDenied => Self::PermissionDenied,
            io::ErrorKind::InvalidData => Self::NotUtf8,
            _ => Self::Other,
        }
    }
}

impl fmt::Display for IoFailure {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        formatter.write_str(match self {
            Self::NotFound => "not found",
            Self::PermissionDenied => "permission denied",
            Self::NotUtf8 => "not UTF-8",
            Self::Other => "unreadable",
        })
    }
}

/// A failure that stops the lint before any rule is checked.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Error)]
enum LoadError {
    #[error("read-failed: cannot read the {role}: {failure}")]
    ReadFailed {
        role: SourceRole,
        failure: IoFailure,
    },
    #[error("catalogue-invalid: the claim catalogue is not valid TOML of the expected shape")]
    CatalogueInvalid,
}

/// A rule a claim breaks.
#[derive(Debug, Clone, PartialEq, Eq, Error)]
enum Violation {
    #[error("source-not-rust-docs: {claim}: source must be a doc.rust-lang.org URL")]
    SourceNotRustDocs { claim: String },
    #[error("unknown-kind: {claim}: kind {kind:?} is not in the vocabulary")]
    UnknownKind { claim: String, kind: String },
    #[error("unknown-status: {claim}: status {status:?} is not in the vocabulary")]
    UnknownStatus { claim: String, status: String },
    #[error("lean-not-found: {claim}: Lean declaration {declaration:?} not found")]
    LeanNotFound { claim: String, declaration: String },
    #[error("witness-not-found: {claim}: witness test {test:?} not found")]
    WitnessNotFound { claim: String, test: String },
    #[error("rejected-without-witness: {claim}: a rejected claim needs a witness")]
    RejectedWithoutWitness { claim: String },
    #[error("proved-without-lean: {claim}: a proved claim needs a Lean reference")]
    ProvedWithoutLean { claim: String },
    #[error("proved-not-checked: {claim}: {declaration:?} is not listed for the trust-base check")]
    ProvedNotChecked { claim: String, declaration: String },
}

/// Appends the contents of every file with extension `extension` under `dir`,
/// skipping build output. Any unreadable directory or file is an error, so the
/// lint never passes on a partial view of the sources.
fn walk(dir: &Path, extension: &str, out: &mut String) -> io::Result<()> {
    for entry in fs::read_dir(dir)? {
        let path = entry?.path();
        if path
            .file_name()
            .is_some_and(|name| name == ".lake" || name == "target")
        {
            continue;
        }
        if path.is_dir() {
            walk(&path, extension, out)?;
        } else if path.extension().is_some_and(|found| found == extension) {
            out.push_str(&fs::read_to_string(&path)?);
        }
    }
    Ok(())
}

/// Everything the lint reads, loaded once at the boundary.
struct Sources {
    catalogue: Catalogue,
    lean: String,
    rust: String,
    trust_list: String,
}

fn read_failed(role: SourceRole) -> impl Fn(io::Error) -> LoadError {
    move |error| LoadError::ReadFailed {
        role,
        failure: IoFailure::from(&error),
    }
}

fn load(root: &Path) -> Result<Sources, LoadError> {
    let catalogue_text = fs::read_to_string(root.join("spec/claims.toml"))
        .map_err(read_failed(SourceRole::Catalogue))?;
    let catalogue: Catalogue =
        toml::from_str(&catalogue_text).map_err(|_| LoadError::CatalogueInvalid)?;
    let mut lean = String::new();
    walk(&root.join("lean"), "lean", &mut lean).map_err(read_failed(SourceRole::LeanSources))?;
    let mut rust = String::new();
    walk(&root.join("crates/future-witnesses"), "rs", &mut rust)
        .map_err(read_failed(SourceRole::WitnessSources))?;
    let trust_list = fs::read_to_string(root.join("lean/RustFuture/Theorems/Soundness.lean"))
        .map_err(read_failed(SourceRole::TrustBaseList))?;
    Ok(Sources {
        catalogue,
        lean,
        rust,
        trust_list,
    })
}

fn declared(lean: &str, declaration: &str) -> bool {
    let short = declaration.rsplit('.').next().unwrap_or(declaration);
    [" ", "\n", " :"]
        .iter()
        .any(|after| lean.contains(&format!(" {short}{after}")))
}

fn check(claim: &Claim, sources: &Sources) -> Vec<Violation> {
    let id = || claim.id.clone();
    let mut found = Vec::new();
    if !claim.source.starts_with("https://doc.rust-lang.org/") {
        found.push(Violation::SourceNotRustDocs { claim: id() });
    }
    if !KINDS.contains(&claim.kind.as_str()) {
        found.push(Violation::UnknownKind {
            claim: id(),
            kind: claim.kind.clone(),
        });
    }
    if !STATUSES.contains(&claim.status.as_str()) {
        found.push(Violation::UnknownStatus {
            claim: id(),
            status: claim.status.clone(),
        });
    }
    if let Some(declaration) = &claim.lean
        && !declared(&sources.lean, declaration)
    {
        found.push(Violation::LeanNotFound {
            claim: id(),
            declaration: declaration.clone(),
        });
    }
    if let Some(test) = &claim.refuted_by
        && !sources.rust.contains(&format!("fn {test}("))
    {
        found.push(Violation::WitnessNotFound {
            claim: id(),
            test: test.clone(),
        });
    }
    if claim.kind == "rejected" && claim.refuted_by.is_none() {
        found.push(Violation::RejectedWithoutWitness { claim: id() });
    }
    if claim.status == "proved" {
        match &claim.lean {
            None => found.push(Violation::ProvedWithoutLean { claim: id() }),
            Some(declaration) => {
                let listing = format!("#print axioms {declaration}");
                if !sources
                    .trust_list
                    .lines()
                    .any(|line| line.trim() == listing)
                {
                    found.push(Violation::ProvedNotChecked {
                        claim: id(),
                        declaration: declaration.clone(),
                    });
                }
            }
        }
    }
    found
}

fn main() -> ExitCode {
    let root = Path::new(env!("CARGO_MANIFEST_DIR")).join("../..");
    let sources = match load(&root) {
        Ok(sources) => sources,
        Err(error) => {
            eprintln!("spec-lint: {error}");
            return ExitCode::FAILURE;
        }
    };
    let violations: Vec<Violation> = sources
        .catalogue
        .claim
        .iter()
        .flat_map(|claim| check(claim, &sources))
        .collect();
    if violations.is_empty() {
        println!(
            "spec-lint: {} claims OK (pinned to Rust {})",
            sources.catalogue.claim.len(),
            sources.catalogue.rust_version
        );
        ExitCode::SUCCESS
    } else {
        for violation in &violations {
            eprintln!("spec-lint: {violation}");
        }
        ExitCode::FAILURE
    }
}
