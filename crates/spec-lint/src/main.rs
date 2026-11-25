//! `cargo run -p spec-lint` — fails if the claim catalogue drifts from the code.
//!
//! Rules (mirrors the ARS risk-register posture: the catalogue indexes, never upgrades):
//! 1. every claim has a non-empty `source` URL into doc.rust-lang.org (pinned version);
//! 2. `status` and `kind` come from the fixed vocabularies below;
//! 3. a `lean` reference names a declaration that textually exists under `lean/`;
//! 4. a `refuted_by` reference names a test that exists in `future-witnesses`;
//! 5. `kind = "rejected"` claims MUST have `refuted_by` (a rejected axiom needs a witness);
//! 6. `status = "proved"` requires a `lean` reference;
//! 7. a proved claim's declaration must be audited by a `#print axioms` line in
//!    the soundness file, so its trust base is checked in CI.
use serde::Deserialize;
use std::{fs, io, path::Path, process::ExitCode};

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

/// Appends the contents of every file with extension `ext` under `dir`,
/// skipping build output. Any unreadable directory or file is an error, so the
/// lint never passes on a partial view of the sources.
fn walk(dir: &Path, ext: &str, out: &mut String) -> io::Result<()> {
    for entry in fs::read_dir(dir)? {
        let path = entry?.path();
        if path
            .file_name()
            .is_some_and(|n| n == ".lake" || n == "target")
        {
            continue;
        }
        if path.is_dir() {
            walk(&path, ext, out)?;
        } else if path.extension().is_some_and(|x| x == ext) {
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
    audited: String,
}

fn load(root: &Path) -> Result<Sources, String> {
    let read = |rel: &str| {
        fs::read_to_string(root.join(rel)).map_err(|e| format!("cannot read {rel}: {e}"))
    };
    let catalogue: Catalogue = toml::from_str(&read("spec/claims.toml")?)
        .map_err(|e| format!("spec/claims.toml is not a valid catalogue: {e}"))?;
    let (mut lean, mut rust) = (String::new(), String::new());
    walk(&root.join("lean"), "lean", &mut lean).map_err(|e| format!("cannot read lean/: {e}"))?;
    walk(&root.join("crates/future-witnesses"), "rs", &mut rust)
        .map_err(|e| format!("cannot read crates/future-witnesses/: {e}"))?;
    let audited = read("lean/RustFuture/Theorems/Soundness.lean")?;
    Ok(Sources {
        catalogue,
        lean,
        rust,
        audited,
    })
}

fn main() -> ExitCode {
    let root = Path::new(env!("CARGO_MANIFEST_DIR")).join("../..");
    let Sources {
        catalogue: cat,
        lean,
        rust,
        audited,
    } = match load(&root) {
        Ok(sources) => sources,
        Err(e) => {
            eprintln!("spec-lint: {e}");
            return ExitCode::FAILURE;
        }
    };

    let mut errs = Vec::new();
    for c in &cat.claim {
        let mut err = |m: String| errs.push(format!("{}: {m}", c.id));
        if !c.source.starts_with("https://doc.rust-lang.org/") {
            err(format!(
                "source must be a doc.rust-lang.org URL, got {:?}",
                c.source
            ));
        }
        if !KINDS.contains(&c.kind.as_str()) {
            err(format!("unknown kind {:?}", c.kind));
        }
        if !STATUSES.contains(&c.status.as_str()) {
            err(format!("unknown status {:?}", c.status));
        }
        if let Some(d) = &c.lean {
            let short = d.rsplit('.').next().unwrap_or(d);
            if !lean.contains(&format!(" {short} "))
                && !lean.contains(&format!(" {short}\n"))
                && !lean.contains(&format!(" {short} :"))
            {
                err(format!("lean declaration {d:?} not found"));
            }
        }
        if let Some(t) = &c.refuted_by
            && !rust.contains(&format!("fn {t}("))
        {
            err(format!("witness test {t:?} not found"));
        }
        if c.kind == "rejected" && c.refuted_by.is_none() {
            err("rejected claim without a witness".into());
        }
        if c.status == "proved"
            && let Some(d) = &c.lean
            && !audited
                .lines()
                .any(|l| l.trim() == format!("#print axioms {d}"))
        {
            err(format!(
                "proved claim {d:?} is not audited by #print axioms"
            ));
        }
        if c.status == "proved" && c.lean.is_none() {
            err("status=proved without a lean reference".into());
        }
    }
    if errs.is_empty() {
        println!(
            "spec-lint: {} claims OK (pinned to Rust {})",
            cat.claim.len(),
            cat.rust_version
        );
        ExitCode::SUCCESS
    } else {
        errs.iter().for_each(|e| eprintln!("spec-lint: {e}"));
        ExitCode::FAILURE
    }
}
