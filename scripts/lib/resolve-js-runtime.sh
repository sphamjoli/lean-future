#!/usr/bin/env bash
#
# Shared by every check-script wrapper (checkTrailingComments.sh and its
# siblings) to find a `bun` or `node` binary to run a `.mjs` gate under. This
# used to be duplicated in each wrapper as a fixed candidate list that
# included macOS Homebrew paths (`/opt/homebrew/bin/*`, `/usr/local/bin/*`) —
# meaningless outside macOS and a genuine portability bug on Linux and
# Windows, not just unnecessary duplication. `command -v` alone is what
# actually works across every OS and shell, since it reads the real PATH; the
# one thing worth checking beyond PATH is bun's own documented install
# location (`$BUN_INSTALL`, defaulting to `~/.bun`), because a GUI git client
# (GitHub Desktop, Tower, IDE panels) commonly runs hooks with a PATH that
# does not include a user-level install directory, on any OS, and this is the
# one such location bun's own installer promises consistently.
#
# Usage: `. "$(dirname "${BASH_SOURCE[0]}")/lib/resolve-js-runtime.sh"` then
# call `resolve_js_runtime`, which prints the resolved binary path (or
# nothing, with a non-zero exit, if none was found).
resolve_js_runtime() {
  if command -v bun >/dev/null 2>&1; then
    command -v bun
    return 0
  fi
  if command -v node >/dev/null 2>&1; then
    command -v node
    return 0
  fi

  local bun_install="${BUN_INSTALL:-${HOME}/.bun}"
  if [[ -x "${bun_install}/bin/bun" ]]; then
    echo "${bun_install}/bin/bun"
    return 0
  fi
  if [[ -x "${bun_install}/bin/bun.exe" ]]; then
    echo "${bun_install}/bin/bun.exe"
    return 0
  fi

  return 1
}

# Bun-only variant for a caller that also needs `bunx` (bun's own bin
# directory holds both, so a child process spawning `bunx` resolves it once
# that directory is on PATH) and cannot fall back to plain `node`.
resolve_bun_runtime() {
  if command -v bun >/dev/null 2>&1; then
    command -v bun
    return 0
  fi

  local bun_install="${BUN_INSTALL:-${HOME}/.bun}"
  if [[ -x "${bun_install}/bin/bun" ]]; then
    echo "${bun_install}/bin/bun"
    return 0
  fi
  if [[ -x "${bun_install}/bin/bun.exe" ]]; then
    echo "${bun_install}/bin/bun.exe"
    return 0
  fi

  return 1
}
