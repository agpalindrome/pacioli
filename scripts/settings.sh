#!/usr/bin/env bash
#
# Reconcile this repo's own (non-org-level) GitHub settings from version
# control. The desired repo-level ruleset lives in .github/rulesets/main.json
# (GitHub's native ruleset format); this script diffs it against the live
# ruleset (--check) or applies it (--apply).
#
# Org-wide rules (the org `default-branch` ruleset) live in ~/github-settings
# and are managed with tofu — this script never touches them. The two layers
# compose; GitHub enforces the most restrictive.
#
# Array ORDER is not compared. GitHub decides it — an applied rule comes back
# appended to the end of `rules` rather than in any canonical order, so a rule
# written anywhere but last in main.json used to report drift immediately after
# an --apply that had in fact succeeded (observed 2026-08-11 in
# ojhermann-org/agpalindrome-aws, adding `non_fast_forward` to its `main`
# ruleset). `bypass_actors` and the nested `required_status_checks` are the same
# shape, and this repo requires two checks, so the nested case is live exposure
# here rather than something to guard against later. normalize() now sorts every
# array on both sides, so main.json may list rules, bypass actors and required
# status checks in any order.
#
# The cost, stated plainly: if GitHub ever gives an array in a ruleset a meaning
# that depends on its order, this diff will not see a change to it. Nothing in
# the current schema is known to work that way — rules all apply and none is
# first-match — but that is reasoning about the schema, not a guarantee from it.
#
# Run it yourself: it uses your `gh` auth (repo admin required). It is
# deliberately owner-run, not wired into CI, so settings never change silently.
#
# Requires: gh (authenticated), jq.
set -euo pipefail

need() { command -v "$1" >/dev/null 2>&1 || { echo "error: '$1' not found on PATH" >&2; exit 1; }; }
need gh
need jq

ROOT="$(git rev-parse --show-toplevel)"
RULESET_FILE="$ROOT/.github/rulesets/main.json"
REPO="$(gh repo view --json nameWithOwner --jq .nameWithOwner)"
NAME="$(jq -r .name "$RULESET_FILE")"

# The fields that define the ruleset; server-added metadata (id, timestamps,
# _links, source) is dropped so the diff shows only meaningful drift.
#
# `-S` sorts object keys; the walk() sorts array ELEMENTS, at every depth. Both
# sides of the diff go through this, so the comparison is order-insensitive —
# see the note on array order in the header for why that is wanted and what it
# costs.
normalize() {
  jq -S '{name, target, enforcement, bypass_actors, conditions, rules}
         | walk(if type == "array" then sort else . end)'
}

existing_id() {
  gh api "repos/$REPO/rulesets" \
    --jq ".[] | select(.name==\"$NAME\") | .id" 2>/dev/null | head -n1
}

case "${1:-}" in
  --check)
    id="$(existing_id)"
    if [ -z "$id" ]; then
      echo "drift: no live ruleset named '$NAME' on $REPO — run --apply to create it"
      exit 1
    fi
    want="$(normalize <"$RULESET_FILE")"
    live="$(gh api "repos/$REPO/rulesets/$id" | normalize)"
    if diff <(printf '%s\n' "$want") <(printf '%s\n' "$live") >/dev/null; then
      echo "in sync: ruleset '$NAME' on $REPO matches $RULESET_FILE"
    else
      echo "drift between $RULESET_FILE (<) and live ruleset '$NAME' (>):"
      diff <(printf '%s\n' "$want") <(printf '%s\n' "$live") || true
      exit 1
    fi
    ;;
  --apply)
    id="$(existing_id)"
    if [ -n "$id" ]; then
      echo "updating ruleset '$NAME' (id $id) on $REPO"
      gh api -X PUT "repos/$REPO/rulesets/$id" --input "$RULESET_FILE" >/dev/null
    else
      echo "creating ruleset '$NAME' on $REPO"
      gh api -X POST "repos/$REPO/rulesets" --input "$RULESET_FILE" >/dev/null
    fi
    echo "applied '$NAME' to $REPO."
    ;;
  *)
    echo "usage: $0 [--check|--apply]" >&2
    exit 2
    ;;
esac
