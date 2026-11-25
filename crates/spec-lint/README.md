# spec-lint

Checks the claim catalogue against the code so that the catalogue cannot drift into saying more than the evidence supports.

## Rules it enforces

Every claim cites the Rust documentation. Every claim's kind and evidence status come from a fixed vocabulary. A claim that names a Lean declaration must name one that exists. A claim that names a Rust witness must name a test that exists. A rejected claim must have a witness, because rejecting an axiom needs a concrete counterexample. A claim marked as proved must name the Lean theorem that proves it, and that theorem must appear in the trust-base check, so its trust base is checked on every change.

## What it cannot check

It checks that references exist, not that a Lean statement faithfully expresses the documented sentence. That judgement stays with a person. It does not itself check which axioms a theorem uses; it makes sure the theorem is listed for the CI step that does.
