# Work-machine tooling — capture map

Files that lived only on the work machine, outside any repo (the
`~/Work/ditto-worktree` pool root is not itself a git worktree). Captured
2026-07-01.

| Repo path | Live path | Notes |
|---|---|---|
| `ditto-worktree/justfile` | `~/Work/ditto-worktree/justfile` | Headless-agent harness: `just chat` (nohup'd claude runs with taskbook status protocol), `just status` (board-authoritative dashboard), `sweep`, worktree lifecycle (`new`/`old`/`del`), Ditto build/fetch/test recipes. |
| `bin/tb-ticket` | `~/.local/bin/tb-ticket` | Taskbook wrapper encoding the `@flutter` + `@<TICKET>` + `@blocked` board pattern and the `~/.taskbook-journals/<TICKET>.md` sidecar journal. |
| `taskbook.json` | `~/.taskbook.json` | Taskbook config (points storage at `~`). |

## Not captured (deliberately)

- **Taskbook data** — `~/.taskbook/storage/`, `~/.taskbook/archive/`, and
  `~/.taskbook-journals/` contain real ticket content: internal, mutable state.
  Wrong for a public repo. Back up privately (see options below).
- **`~/Work/ditto-worktree/CLAUDE.md`** and the per-worktree checkouts —
  Ditto-internal monorepo docs; belong in the monorepo or an internal repo.

## Deployment wiring (not yet done)

None of these files are deployed by home-manager yet. When wiring, this content
is work-profile-only — it belongs behind `profiles/work.nix`, not `common.nix`
(same argument as the Claude work/home split plan). Sketch:

```nix
home.file."Work/ditto-worktree/justfile".source =
  oosSymlink "${homeDir}/dotfiles/tools/work/ditto-worktree/justfile";
home.file.".local/bin/tb-ticket" = {
  source = oosSymlink "${homeDir}/dotfiles/tools/work/bin/tb-ticket";
  executable = true;
};
home.file.".taskbook.json".source = oosSymlink "${homeDir}/dotfiles/tools/work/taskbook.json";
```

Note `home.file` happily deploys into `~/Work/ditto-worktree/` even though that
directory isn't nix-created — but the first switch will collide with the
existing plain files (move them aside).

## Taskbook data backup options

1. **Private repo + launchd auto-commit** (recommended): a private GitHub repo
   holding `~/.taskbook` + `~/.taskbook-journals`, with a nix-darwin
   `launchd.user.agents` entry doing `git add -A && git commit && git push`
   hourly. Survives machine loss; content stays private.
2. Fold into whatever machine-level backup already runs (Time Machine only
   covers hardware failure, not machine handback).
3. Not agenix — that's for secrets, not mutable data.

## Unmanaged-install inventory (found while capturing)

- `tb` (taskbook) is an **npm global** (`npm i -g taskbook`) via homebrew's
  node — invisible to both `brew leaves` and nix. Route through nix
  (`nodePackages` or a `writeShellApplication` wrapper) or document as a
  manual restore step.
