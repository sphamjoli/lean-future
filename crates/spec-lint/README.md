# spec-lint

Checks the claim catalogue against the code so that the catalogue cannot drift into saying more than the evidence supports.

## Rules it enforces

Every claim cites the Rust documentation. Every claim's kind and evidence status come from a fixed vocabulary. A claim that names a Lean declaration must name one that exists. A claim that names a Rust witness must name a test that exists. A rejected claim must have a witness, because rejecting an axiom needs a concrete counterexample. A claim marked as proved must name the Lean theorem that proves it.

## What it cannot check

It checks that references exist, not that a Lean statement faithfully expresses the documented sentence. That judgement stays with a human reviewer. It also does not check that a proved theorem is free of extra axioms. A separate CI step audits that.
