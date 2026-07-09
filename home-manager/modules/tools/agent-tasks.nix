# Scheduled-agent task harness (daily-ticket-status-drafts A/B, v0).
#
# Work-scoped: imported from profiles/work.nix, NOT common.nix — the Linear
# write key and Ditto ticket workflow don't belong in devcontainer/home
# profiles. work.nix also backs the alyssa@work-dev aarch64-linux devcontainer,
# so everything here is additionally guarded to darwin.
#
# Deploys: the two harness scripts (nix-managed deps, shellcheck at build),
# the task bundle to ~/.agents/tasks/, and the agenix secrets — the encrypted
# task prompt exposed at a stable home path, and the Linear API key at the
# agenix runtime dir (mode 0400 default; only ticket-drafts-review reads it).
# Scripts also run from a plain repo checkout pre-activation via just recipes
# (rage-direct fallback) — see tools/agents/tasks/daily-ticket-status-drafts/README.md.
{ config, lib, pkgs, ... }:
let
  taskName = "daily-ticket-status-drafts";
  taskSrc = ../../../tools/agents/tasks/daily-ticket-status-drafts;
  mkTaskScript = name:
    pkgs.writeShellApplication {
      inherit name;
      runtimeInputs = [ pkgs.jq pkgs.curl pkgs.rage pkgs.coreutils ];
      # Included verbatim: the source's own shebang/strict-mode lines are
      # redundant under writeShellApplication but harmless, and keeping the
      # files byte-identical preserves the pre-activation checkout path.
      text = builtins.readFile (../../../tools/agents/bin + "/${name}");
    };
in
{
  config = lib.mkIf pkgs.stdenv.isDarwin {
    home.packages = [
      (mkTaskScript "ticket-drafts-run")
      (mkTaskScript "ticket-drafts-review")
    ];

    home.file = {
      ".agents/tasks/${taskName}/README.md".source = taskSrc + "/README.md";
      ".agents/tasks/${taskName}/output-schema.json".source = taskSrc + "/output-schema.json";
      ".agents/tasks/${taskName}/hooks/never-post-linear.json".source =
        taskSrc + "/hooks/never-post-linear.json";
    };

    age.secrets = {
      # Decrypted prompt at a stable home path (same per-secret `path` pattern
      # as agents.nix); plaintext stays in the agenix runtime dir, not the store.
      ticket-drafts-prompt = {
        file = ../../../secrets/personal/ticket-drafts-prompt.age;
        path = "${config.home.homeDirectory}/.agents/tasks/${taskName}/prompt.md";
      };
      # No `path`, no `mode`: lands at ~/.local/share/agenix/linear-api-key,
      # 0400 — deliberately not under a browsable location.
      linear-api-key = {
        file = ../../../secrets/personal/linear-api-key.age;
      };
    };
  };
}
