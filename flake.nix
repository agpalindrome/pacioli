{
  description = "Pacioli — verified accounting mechanics (Lean 4) paired with curated judgment (OKF)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    git-hooks.url = "github:cachix/git-hooks.nix";
    git-hooks.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    { nixpkgs, git-hooks, ... }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      forAllSystems = nixpkgs.lib.genAttrs systems;

      # Fast, hermetic checks for the charter: Nix formatting/lint, markdown, and
      # whitespace/hygiene. (Lean guards — `no-sorry` and the full `lake build` —
      # will return with the mechanics.)
      hooksFor =
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        git-hooks.lib.${system}.run {
          src = ./.;
          hooks = {
            # `nixfmt` (not `nixfmt-rfc-style`): as of nixpkgs 25.11 the RFC 166
            # formatter *is* `pkgs.nixfmt`, and the old alias warns on eval.
            nixfmt.enable = true;
            deadnix.enable = true;
            statix.enable = true;
            check-merge-conflicts.enable = true;
            check-added-large-files.enable = true;
            trim-trailing-whitespace.enable = true;
            end-of-file-fixer.enable = true;
            check-yaml.enable = true;
            markdownlint = {
              enable = true;
              settings.configuration = {
                MD013 = {
                  # line length — prose wraps at 80 for terminal review; tables
                  # and code blocks (ASCII trees) can't reflow, so exempt them.
                  line_length = 80;
                  tables = false;
                  code_blocks = false;
                };
                MD033 = false; # inline HTML
                MD036 = false; # emphasis-as-heading — prose uses emphasis stylistically
                MD040 = false; # fenced code language not required (ASCII trees)
                MD025.front_matter_title = ""; # don't treat YAML front-matter title as an H1
              };
            };

            # vale — the word-level house style, vendored into `.vale/styles`
            # from the owner's shared `~/.claude/vale` by that repo's
            # `scripts/sync-vale.sh`. Rules are edited there, never here: a
            # local edit reads as drift on the next sync and is lost.
            #
            # `scripts/prose-check.sh` owns the scope, the `--no-global` flag
            # and the empty-file-list guard, so the commit hook and CI run one
            # gate rather than two that can disagree. This entry only puts the
            # flake-pinned `vale` on its PATH. `pass_filenames = false` because
            # the script selects its own inputs; `files` still confines the hook
            # to changes that touch Markdown.
            prose = {
              enable = true;
              name = "vale";
              description = "authored prose passes the shared house style";
              entry = toString (
                pkgs.writeShellScript "pacioli-prose-check" ''
                  export PATH=${
                    nixpkgs.lib.makeBinPath [
                      pkgs.coreutils
                      pkgs.findutils
                      pkgs.vale
                    ]
                  }:$PATH
                  # The script's own `#!/usr/bin/env bash` is right for a
                  # contributor running it by hand, and unusable here: the Linux
                  # build sandbox carries no `/usr/bin/env`, so the hook exits
                  # 126 without running. Naming the interpreter serves both
                  # callers. The Darwin sandbox does expose `/usr/bin/env`, so
                  # this passed locally and failed in CI (measured 2026-08-20).
                  exec ${pkgs.bash}/bin/bash ./scripts/prose-check.sh
                ''
              );
              files = "\\.md$";
              pass_filenames = false;
            };
          };
        };
    in
    {
      checks = forAllSystems (system: {
        pre-commit = hooksFor system;
      });

      devShells = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          hooks = hooksFor system;
        in
        {
          default = pkgs.mkShell {
            inherit (hooks) shellHook;
            buildInputs = hooks.enabledPackages ++ [
              # `elan` is Lean's official toolchain multiplexer: the flake
              # provides the `elan` binary, and `elan` provides `lake`/`lean`
              # shims that read `lean-toolchain` and fetch the pinned Lean into
              # ~/.elan. This is what both the VS Code Lean4 extension and
              # Helix's `lake serve` expect, and it's what makes mathlib's
              # prebuilt binary cache (`lake exe cache get`) usable.
              pkgs.elan
              # `taplo` formats `lakefile.toml` / `lake-manifest.json`-adjacent
              # TOML (the `.helix/languages.toml` formatter for TOML calls it).
              pkgs.taplo
            ];
          };
        }
      );

      formatter = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        pkgs.writeShellApplication {
          name = "fmt";
          runtimeInputs = [
            pkgs.nixfmt
            pkgs.findutils
          ];
          text = ''
            find . -name '*.nix' -not -path './.git/*' -print0 | xargs -0 nixfmt
          '';
        }
      );
    };
}
