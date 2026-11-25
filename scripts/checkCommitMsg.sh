#!/usr/bin/env bash
#
# Runs the commit-message convention checker under whichever JS runtime is
# present. Like scripts/checkDecorativeSeparators.sh, this exists because
# commit hooks fire from Git GUIs (GitHub Desktop, Tower, IDE panels) whose
# minimal PATH often lacks `bun` and `node`. All arguments are forwarded
# verbatim (lefthook's `commit-msg` hook passes the message file path).
#
# If no runtime is found we warn and exit 0 (fail-open) rather than block a
# commit from a GUI that cannot run the check.

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
script="${repo_root}/scripts/checkCommitMsg.mjs"

# shellcheck source=scripts/lib/resolve-js-runtime.sh
. "${repo_root}/scripts/lib/resolve-js-runtime.sh"

if ! runtime="$(resolve_js_runtime)"; then
  echo "checkCommitMsg: no bun/node runtime found; skipping." >&2
  exit 0
fi

exec "${runtime}" "${script}" "$@"
