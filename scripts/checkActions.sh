#!/usr/bin/env bash
#
# Lints the GitHub Actions workflows with actionlint. CI does not syntactically
# verify workflow expressions, so a malformed `${{ }}`, a bad job dependency, or
# a shell-quoting slip in a run step would otherwise only surface at dispatch.
# actionlint parses the workflows, type-checks their expressions, and shellchecks
# the run scripts.
#
# Opportunistic: actionlint is not part of the toolchain everyone installs, so
# when it is absent this exits 0 rather than blocking a commit. Install it
# (`brew install actionlint`) to gain the check locally.

set -euo pipefail

# shellcheck source=scripts/lib/prepend-common-bin-dirs.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/prepend-common-bin-dirs.sh"
prepend_common_bin_dirs

if ! command -v actionlint >/dev/null 2>&1; then
  echo "checkActions: actionlint not installed; skipping (brew install actionlint to enable)." >&2
  exit 0
fi

# The run-step shellcheck integration is disabled: it reports style and info
# findings (SC2086, SC2129) across the existing workflows that a blocking hook
# cannot fail on without first cleaning every run script. actionlint's own
# checks stay on: workflow syntax, expression typing, and runner labels (the
# self-hosted labels are declared in .github/actionlint.yaml), which is the part
# that catches a broken ${{ }} or job wiring before dispatch.
#
# Any file arguments (the staged workflow files from lefthook) scope the lint to
# what this commit touches, so a pre-existing issue in an unrelated workflow
# never blocks editing a different one. With no arguments actionlint lints every
# workflow, which is what a manual whole-repo run wants.
exec actionlint -shellcheck= "$@"
