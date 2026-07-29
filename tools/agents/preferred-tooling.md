# Preferred Tooling

Operational defaults for terminal work — the concrete expression of "Do More
With Less" (terminal-first, reproducible, plaintext) from the personal
constitution. These are **defaults, not absolutes**: prefer the tool named
below, but when it isn't installed — common in ephemeral sandboxes (Claude Code
on the web, CI runners, fresh containers) — fall back to the standard
equivalent rather than failing or installing it, and say which you used.

## Version control: prefer `jj`, fall back to `git`

`jj` (Jujutsu) is the default. Reach for it first, and run `jj status` before
making changes to see the working copy (`@`) and its parent. But `jj` is often
absent in sandboxes that ship only `git`; when it is, use `git` directly. This
is safe: jj is git-backed, so the repository is a normal git repo underneath and
git operations never corrupt jj state.

## Command-line defaults

| Task | Prefer | Fall back to |
|---|---|---|
| Search file contents | `rg` (ripgrep) | `grep` |
| List files | `eza` | `ls` |
| View / page files | `bat` | `cat` |
| Text editor | `hx` (Helix, `$EDITOR`) | `vi` / `nano` |
| Task runner | `just` (`just --list`) | `make`, package scripts |
| JSON | `jq` | — |
| GitHub | `gh`, `gh-dash` | web / API |
| Secrets | `rage` / `ragenix` (agenix) | — |
| Terminal multiplexer | `tmux` | — |
| Tasks / todos | `tb` (taskbook) | — |
| Cheatsheets | `cheat` | — |
| Terminal slides | `presenterm` | — |
| Terminal recording | `asciinema` | — |

## Language toolchains

- **Rust**: `rustup`-managed toolchain; `bacon` for background checks; `clippy`
  for lints. rust-analyzer and rustfmt come from rustup — never install them
  standalone (they conflict).

## The fallback rule, restated

Absence of a preferred tool is never a blocker and never a reason to install
software into a throwaway environment. Detect, fall back, proceed, and note the
substitution.
