# Pacioli — repo guide for Claude

Pacioli formalizes the **mechanical** half of accounting in Lean 4; the
**judgment** half is curated in OKF. Read the **[README](README.md)** for the
thesis and the mechanical/judgment seam, and **[CONTRIBUTING](CONTRIBUTING.md)**
for the workflow — the dev setup, the **Development conventions**, the
**Critical review** practice, and the **Contributing a change** PR checklist.
Follow those; this file only adds what an agent needs on top of them.

## Scope: this repo is the pure verified core

Applied use — for accountants, applications, and the MCP — is **not** built here.
It lives **downstream**, in separate repo(s), behind **one verified artifact
compiled from Lean** (a checker; CLI-over-JSON first, a Lean→C binary later). So
keep this repo pure: **no JSON / IO / FFI / currency tables / default charts,
and no entity IDs / surrogate keys / entry↔transaction foreign-key
associations, in the core.** Don't add an "applied" or "convenience" surface to
these modules; that belongs downstream. Identity and persistence are downstream
concerns: an ID reads in no mechanical theorem, and the entry↔transaction
relation is modelled by containment (`Transaction.entries`), not a key.
Decision + rationale: issues **#41** (applied delivery) and **#45**
(identity/association), plus the `pacioli-applied-layer-architecture` memory.

## Build and verify

- Enter the toolchain with `nix develop` (direnv auto-loads it on `cd`). Lean and
  Mathlib are **pinned at v4.32.0**; the flake provides `elan`, and `elan`
  provides the `lake`/`lean` shims, so run Lean commands inside the dev shell.
- The local gate is **`scripts/lean-check.sh`** — `lake build` + a sorry check.
  Run it before committing. For a new load-bearing theorem, also check
  `#print axioms`.
- CI is `nix flake check` (hygiene hooks only for now; wiring the Lean gates into
  CI is issue #37).

## Repo gotchas

- `Type*` needs `import Mathlib.Tactic.TypeStar`.
- Constructing a concrete `Transaction` and discharging `balanced` with
  `by decide` needs the `Fintype`-forall instance imported and a finite currency
  type; otherwise `decide` can't discharge the `∀ c`.
- Keep scratch / verification `.lean` files in the scratchpad and delete them —
  they are not part of the library. `Pacioli.lean` imports the real modules
  (`Entry → Aggregation → Transaction → Classification`; see
  [docs/architecture.md](docs/architecture.md)).

## Deletion & creation

- A **new module** is added to `Pacioli.lean` in dependency order.
- Do **not** weaken a load-bearing invariant without going through the seam: the
  value-type nonnegativity guard (`CanonicallyOrderedAdd` on `ν`), the bundled
  `Transaction.balanced` field, and "policy never leaks into a type" are the
  design, not incidental — changing them is an owner decision.
- Do **not** add entity IDs / surrogate keys to `Entry` or `Transaction`, or an
  entry↔transaction foreign-key field: identity and persistence are downstream
  (issue #45), and the association is already modelled by containment
  (`Transaction.entries`). Reopen only if a genuine *mechanical* law needs entry
  identity (e.g. reversal referencing a prior entry), added at the point of use.
- Treat the **pinned** files as sensitive — `lean-toolchain`,
  `lake-manifest.json`, `flake.lock` — don't change them casually; and don't
  delete proven theorems or whole modules without a clear, stated reason.
- `main` is **PR-only** and branch-protected; nothing merges without the owner
  (see the CONTRIBUTING PR checklist). Deferred review findings become issues.
