#!/usr/bin/env bash
#
# Runs the Markdown-wrap checker under whichever JS runtime is present.
# Like scripts/checkDecorativeSeparators.sh, this exists because pre-commit
# hooks fire from Git GUIs (GitHub Desktop, Tower, IDE panels) whose minimal
# PATH often lacks `bun` and `node`. This checker is a script, not a native
# binary, so it needs a runtime; we resolve one from PATH and the usual
# install locations. All arguments are forwarded verbatim.
#
# If no runtime is found we warn and exit 0 (fail-open) rather than block a
# commit from a GUI that cannot run the check. `bun run check:markdown-wrap`
# audits the whole tree on demand.

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
script="${repo_root}/scripts/checkMarkdownWrap.mjs"

# shellcheck source=scripts/lib/resolve-js-runtime.sh
. "${repo_root}/scripts/lib/resolve-js-runtime.sh"

if ! runtime="$(resolve_js_runtime)"; then
  echo "checkMarkdownWrap: no bun/node runtime found; skipping." >&2
  echo "checkMarkdownWrap: run \`bun run check:markdown-wrap\` from a shell to audit." >&2
  exit 0
fi

exec "${runtime}" "${script}" "$@"
