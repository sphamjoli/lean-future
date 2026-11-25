#!/usr/bin/env bash
#
# Shared by the checkers that shell out to a system tool (ruby, python3)
# rather than a JS runtime, so a Git GUI's minimal-environment shell still
# finds it. `/usr/bin` is the one location worth adding unconditionally: it
# exists on every Linux and macOS install and is a harmless no-op everywhere
# else, since `_prepend_path` only adds a directory that actually exists.
# Homebrew's `/opt/homebrew/bin`/`/usr/local/bin` were deliberately dropped
# from here: they only ever help on macOS, and ruby/python3 discovery is
# already scoped to Unix-like systems by the tools themselves (neither ships
# with Windows by default), so keeping them added nothing but a
# macOS-flavoured assumption dressed up as a portable fallback.
prepend_common_bin_dirs() {
  _prepend_path() {
    case ":${PATH:-}:" in
      *":$1:"*) ;;
      *) [ -d "$1" ] && PATH="$1:${PATH:-}" ;;
    esac
  }
  _prepend_path /usr/bin
  export PATH
}
