#!/usr/bin/env bash
# Local prose quality gate for Pacioli — the word-level half of the house style
# shared across the owner's repos. Run it from inside the dev shell (direnv
# loads it automatically; otherwise `nix develop --command scripts/prose-check.sh`).
#
# What it checks, and why this shape:
#
#   1. Scope — every tracked Markdown file is authored prose (README,
#      CONTRIBUTING, CLAUDE, docs/), so the whole set is in scope. The excludes
#      below drop build trees, not documents: `.lake` carries Mathlib's own
#      Markdown, and `.vale/styles` is the vendored rule set rather than writing
#      of ours. Neither reaches CI (both are gitignored, so the flake source
#      never sees them), and both are present in a working clone.
#
#   2. `--no-global` — without it vale merges a machine-global styles directory
#      on top of the vendored one, and a contributor's run stops agreeing with
#      CI's.
#
#   3. Errors block and warnings do not. That is vale's own exit code, which
#      counts errors alone whatever `MinAlertLevel` renders, so it needs no
#      flag here.
#
# The rules live in `.vale/styles`, vendored from the owner's `~/.claude/vale`
# by that repo's `scripts/sync-vale.sh`. Edit them there, not here: a local edit
# reads as drift on the next sync and is lost.
set -euo pipefail

cd "$(dirname "$0")/.."

files=()
while IFS= read -r file; do
  files+=("$file")
done < <(
  find . -type f -name '*.md' \
    -not -path './.git/*' \
    -not -path './.lake/*' \
    -not -path './.direnv/*' \
    -not -path './.vale/*' \
    -not -path './result/*' |
    sort
)

# An empty list is a broken gate, not a clean one: `vale` with no paths reads
# stdin, finds nothing and exits 0, so a scope that matches nothing reports
# green over nothing. This repo always has Markdown, so zero files means the
# excludes above have swallowed it.
if [ ${#files[@]} -eq 0 ]; then
  echo "FAIL: no Markdown matched — the scope in this script is wrong." >&2
  exit 1
fi

echo "==> vale (${#files[@]} files)"
vale --no-global --config .vale.ini "${files[@]}"

echo "OK: prose passes the house style."
