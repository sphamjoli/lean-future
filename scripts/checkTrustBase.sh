#!/usr/bin/env bash
#
# Fails if a Lean build log shows a `sorry` warning, or if any `#print axioms`
# line in Theorems/Soundness.lean reports an axiom outside Lean's core trio
# (propext, Quot.sound, Classical.choice). This is the mechanical form of the
# rule "distinguish what was proved from what was trusted".
#
# Argument: path to the captured `lake build` output.
set -euo pipefail

log="${1:?usage: checkTrustBase.sh <lake build log>}"
status=0

if grep -q "declaration uses 'sorry'" "$log"; then
  echo "checkTrustBase: build contains sorry:" >&2
  grep "declaration uses 'sorry'" "$log" >&2
  status=1
fi

while IFS= read -r line; do
  axioms="$(printf '%s' "$line" | sed -n 's/.*depends on axioms: \[\(.*\)\]/\1/p')"
  for ax in ${axioms//,/ }; do
    case "$ax" in
      propext|Quot.sound|Classical.choice) ;;
      *) echo "checkTrustBase: non-core axiom '$ax' in: $line" >&2; status=1 ;;
    esac
  done
done < <(grep "depends on axioms" "$log" || true)

exit "$status"
