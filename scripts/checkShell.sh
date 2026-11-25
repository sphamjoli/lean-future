#!/usr/bin/env bash
#
# Syntax-checks each shell script passed as an argument with `bash -n` (parse,
# do not execute). Our git hooks and helper scripts are shell, which biome does
# not cover, so a syntax error would otherwise only surface the next time a hook
# runs. `bash` is always present, so this needs no extra dependency.
#
# Arguments are the files to check (lefthook passes the staged shell files).
# Exit status is non-zero if any file fails to parse.
set -euo pipefail

detail="$(mktemp)"
trap 'rm -f "$detail"' EXIT

status=0
for file in "$@"; do
  [ -f "$file" ] || continue
  if ! bash -n "$file" 2>"$detail"; then
    echo "Shell validation failed: $file" >&2
    sed 's/^/  /' "$detail" >&2
    status=1
  fi
done

exit "$status"
