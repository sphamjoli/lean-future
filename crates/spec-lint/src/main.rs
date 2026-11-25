//! `cargo run -p spec-lint` — fails if the claim catalogue drifts from the code.
//!
//! Rules (mirrors the ARS risk-register posture: the catalogue indexes, never upgrades):
//! 1. every claim has a non-empty `source` URL into doc.rust-lang.org (pinned version);
//! 2. `status` and `kind` come from the fixed vocabularies below;
//! 3. a `lean` reference names a declaration that textually exists under `lean/`;
//! 4. a `refuted_by` reference names a test that exists in `future-witnesses`;
//! 5. `kind = "rejected"` claims MUST have `refuted_by` (a rejected axiom needs a witness);
//! 6. `status = "proved"` requires a `lean` reference.
use serde::Deserialize;
use std::{fs, path::Path, process::ExitCode};

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

fn walk(dir: &Path, ext: &str, out: &mut String) {
    let Ok(rd) = fs::read_dir(dir) else { return };
    for e in rd.flatten() {
        let p = e.path();
        if p.file_name().is_some_and(|n| n == ".lake" || n == "target") {
            continue;
        }
        if p.is_dir() {
            walk(&p, ext, out);
        } else if p.extension().is_some_and(|x| x == ext) {
            out.push_str(&fs::read_to_string(&p).unwrap_or_default());
        }
    }
}

fn main() -> ExitCode {
    let root = Path::new(env!("CARGO_MANIFEST_DIR")).join("../..");
    let text = fs::read_to_string(root.join("spec/claims.toml")).expect("spec/claims.toml");
    let cat: Catalogue = toml::from_str(&text).expect("valid catalogue");
    let (mut lean, mut rust) = (String::new(), String::new());
    walk(&root.join("lean"), "lean", &mut lean);
    walk(&root.join("crates/future-witnesses"), "rs", &mut rust);

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
            let short = d.rsplit('.').next().unwrap();
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
