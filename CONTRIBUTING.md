# Contributing to Pacioli

Thanks for your interest in Pacioli. This guide covers **how the repository is
meant to grow** and the **mechanics of contributing** to it. For _why_ Pacioli
is split the way it is, read the [README](README.md) first.

Pacioli has begun landing its **first mechanics**: the thesis is settled and the
mechanics are built from the ground up as small, deliberate increments. This
guide describes the collaboration model and workflow; the Lean- and OKF-specific
conventions return to it alongside the code they govern (the first are under
"Development conventions" below).

Pacioli values **correctness, comprehensibility, and robust discussion** over
speed. There are no deadlines. A change that is small, well-explained, and
verified is always preferred to a large one that is none of those.

---

## The one decision every change turns on

Pacioli splits accounting on a single question:

> **Can this be made total and mechanical?**

Every contribution resolves to one side of that seam:

- **Yes → the mechanics.** Total functions and algebraic invariants — double
  entry, aggregation, close, consolidation. These belong in **Lean 4**, codified
  and proven.
- **No → the judgment.** Policy, timing, materiality, classification,
  GAAP-vs-IFRS — anything that is "it depends." These are curated as cited,
  human- and agent-readable reasoning in the **OKF bundle**.

Some statements straddle the seam and arrive as _both_: a judgment input plus a
mechanical theorem (the accounting equation is the canonical example — see the
README). The invariant that protects the seam is **policy never leaks into Lean
types**: if a Lean type could only be built by making a policy choice, that
choice belongs in the judgment half instead.

If you are unsure which side a change belongs on, **open an issue and discuss it
first.** Getting the seam right matters more than the change.

---

## The agent–human loop

Pacioli is built for **agent–human collaboration**:

- A **human brings an input** — an idea from accounting literature, a new
  standard, a policy question, a worked example.
- An **agent (or human) updates the repository** — deciding whether the input is
  _mechanical_ or _judgment_, and making the change while keeping the halves and
  the interface between them clean.

The loop is the intended shape, not a restriction; humans can edit directly.

---

## Development setup

The toolchain is managed by a **Nix flake**, so a dev shell gives you the pinned
lint tools — no global installs.

```sh
nix develop          # enter the dev shell (lint + hygiene tools)
```

Entering the shell **installs the git hooks** (via `git-hooks.nix`).

**With direnv** (recommended), the shell loads automatically on `cd`. The repo
tracks a shared `.envrc.shared`; each clone needs a thin, untracked local
`.envrc` that sources it:

```sh
printf 'source_env .envrc.shared\n' > .envrc
direnv allow
```

---

## What the checks enforce

The same checks run **locally and in CI** — `nix flake check` is the single
source of truth.

- **On commit** (fast hooks): `nixfmt`, `deadnix`, `statix` for Nix;
  `markdownlint` for docs; and whitespace/EOF/merge-conflict/YAML hygiene.
- **In CI** (every PR, and `main`): two required jobs — **`nix flake check`**
  (those hooks) and **`lake build`** (the full Lean compile plus the sorry
  check, via [`scripts/lean-check.sh`](scripts/lean-check.sh)). A red run on
  either blocks the merge.

The `lake build` job runs the _same_ `scripts/lean-check.sh` you run locally, so
the Lean gate is identical in both places. A deeper `no-sorry`/axiom guard
(`#print axioms` on the load-bearing theorems) is the remaining follow-up on
issue #37.

### Repository settings as code

This repo governs its own merge policy — the required checks, owner review and
conversation resolution — as a version-controlled **GitHub ruleset** in
[`.github/rulesets/main.json`](.github/rulesets/main.json).
Maintainers reconcile it with [`scripts/settings.sh`](scripts/settings.sh)
(`--check` to diff live vs. committed, `--apply` to push it). Org-wide rules are
managed separately in tofu; these two layers compose. Nothing bypasses the
ruleset: every PR, a maintainer's included, lands through the ordinary path in
[Landing it](#landing-it).

### House style

- **Markdown** wraps prose at **80 columns** (`MD013`); tables and code/Mermaid
  blocks are exempt. Table pipes must be aligned (`MD060`) — `prettier` does
  this.

### Development conventions

Three standing practices, adopted with the first mechanics:

- **Cite load-bearing invariants.** A Lean invariant traces to its mathematical
  or accounting source (README design principle 6) — put the citation in the
  declaration's docstring when it lands, not later.
- **Keep documentation in step with the code.** Update the affected docs
  (README status, this guide, module/declaration docstrings) in the _same_
  change as the code, so the docs never claim something the code has outgrown.
- **Critically review each substantive increment before committing** (see the
  next section).

### Critical review

Every substantive mechanics increment — a new definition, invariant, or proof —
is put through a **three-lens critical review** before it lands, so the practice
is repeatable by anyone (human or agent):

- **Lean idioms & proof robustness.** Is it idiomatic (naming, namespacing,
  `deriving`, the `@[simp]` / lemma API)? Are the proofs sturdy rather than
  accidental — no fragile bare `rw`/`add_comm`, no silent reliance on a
  definitional unfolding that a later `irreducible` would break? Is it
  `sorry`- and axiom-clean (`#print axioms`)?
- **Accounting fidelity.** Does the model faithfully capture the bookkeeping?
  Does any statement over- or under-claim (e.g. a differential law read as a
  standing identity, a per-class rule read as per-account)? What is the right
  next theorem?
- **Charter & seam alignment.** Does judgment stay out of the types (principle
  3)? Are the invariants that get full proofs the load-bearing ones (2), and are
  they cited (5)? Do the docstrings match what is actually proved?

Each lens reports findings ranked by severity. Triage them into **fix now** vs
**defer to a tracked issue**, apply the fixes, re-verify green and sorry-free
(`scripts/lean-check.sh`), and only then commit. Record the deferred findings as
issues so nothing is silently dropped.

These three lenses are the current set; **expand it as the work demands** — a
performance lens, an OKF-interface lens, or whatever a future increment calls
for.

---

## Contributing a change

Everything lands through a **pull request** — no direct commits to `main`.
Branch off `main`, make the change on **one side of the seam** (mechanics _or_
judgment), and keep it **small and well-explained** — say _why_, not just
_what_.

### Before opening (or un-drafting) the PR

- **Verify.** `scripts/lean-check.sh` is green and **sorry-free**; run
  `#print axioms` on any new load-bearing theorem and confirm there are no
  unexpected axioms.
- **Lint and format.** `nix flake check` is green — `nixfmt`, `deadnix`,
  `statix`, `markdownlint`, and whitespace/EOF hygiene. Format TOML with
  `taplo`; there is no `.lean` autoformatter, so follow the Mathlib layout (the
  100-column guide).
- **Docs in step, invariants cited.** Update the affected docs (README status,
  this guide, module/declaration docstrings) in the _same_ change, and cite any
  new load-bearing invariant (see
  [Development conventions](#development-conventions)).
- **Critical review.** Run the [critical review](#critical-review) — the three
  lenses (Lean idioms & proof robustness, accounting fidelity, charter & seam
  alignment). Triage findings **fix now** vs **defer**, apply the fixes, and
  file an issue for every deferred finding.

### Landing it

Open the PR as a **draft** while the increment is in progress; mark it ready once
the checklist above is done. For it to become mergeable:

- the required checks — **`nix flake check`** and **`lake build`** — pass;
- a **code owner has approved** — [`CODEOWNERS`](.github/CODEOWNERS) names
  **@ojhermann** and **@otto-agpalindrome**, and a review from either satisfies
  the rule. GitHub requests it automatically, so you needn't add anyone by hand.
  GitHub blocks self-approval, so the approval comes from whichever of the two
  accounts did not open the PR;
- **every review conversation is resolved** — no open comments.

**Only the owner merges**, with
`gh pr merge <PR#> --squash --body-file <file>`. Merges are **squash**, keeping
history linear; the ruleset permits no other method. `--body-file` composes the
squash commit body at merge time, which is what lets it carry a `Reviewed-by`
trailer naming the account that approved — the branch commits are written before
the review exists, so they cannot.

**The merge queue was removed on 2026-08-18**, for that reason. A queued merge
goes through GitHub's `enqueuePullRequest` mutation, which accepts no commit
body, so the trailer had nowhere to go. The cost, which the owner accepted: a
pull request is no longer re-tested against the latest `main` as it lands, and
`strict_required_status_checks_policy` is `false`, so a branch can merge green
against a base that has since moved. Rebase on `main` before asking for a merge
if the branch is old.

---

## Questions and discussion

Open a [GitHub issue](https://github.com/ojhermann-org/pacioli/issues) — for a
concept proposal, a kernel idea, or a "which side of the seam does this belong
on?" discussion. Robust discussion is welcome and is how the seam stays clean.
