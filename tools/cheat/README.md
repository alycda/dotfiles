# Cheat

[Cheat](https://github.com/cheat/cheat) is a command-line tool for creating and viewing interactive cheatsheets. It provides quick reference snippets without leaving the terminal.

Key features:
- **Plain text cheatsheets** - simple files, easy to version control
- **Multiple cheatpaths** - organize by community vs personal, or by topic
- **Editor integration** - uses `$EDITOR` (helix in this setup) for creating/editing sheets
- **Searchable** - find sheets by name or search within content

## Why cheat over IDE snippets?

Cheatsheets live in the terminal, not a specific editor. They work the same whether you're in VS Code, Helix, or a bare SSH session. Combined with a justfile, they're excellent for live demos - you can quickly show exact commands without fumbling ([live demo](https://www.youtube.com/watch?v=Ee-VWKtkmVg) by [Nathan Stocks](https://github.com/CleanCut)).

## Usage

```bash
cheat jj/log        # View a cheatsheet
cheat -l            # List all available cheatsheets
cheat -s keyword    # Search cheatsheets
cheat -e jj/new     # Create/edit a cheatsheet
```

## Structure

```
cheatsheets/
├── community/     # Shareable, general-purpose sheets
│   ├── claude/    # Claude Code tips
│   ├── git/       # Git commands
│   ├── jj/        # Jujutsu commands
│   └── nix/       # Nix commands
├── personal/      # Machine-specific or private sheets
└── inbox/         # Quarantine for unreviewed sheets (see below)
```

## The inbox

`community/` and `personal/` are nix store paths, so they are `readonly: true` and
nothing can write to them - `cheat -e <new-sheet>` has nowhere to land. The `inbox`
cheatpath is the one writable one, mounted at `~/.cheat/inbox`:

```bash
cheat -l -t unverified   # everything waiting for review
cheat -e scratch/thing   # new sheets land in the inbox
```

It is a quarantine, not a third library. Sheets arrive there unreviewed - from
`cheat -e`, or from an agent running the `cheat-memory` skill - and are promoted by
moving the file into `community/` or `personal/`. That keeps the "verified against
crush 0.88.1 source" standard of the curated sheets from being diluted by notes
nobody has checked.

On a machine with a live dotfiles checkout (`agentSkills.liveCheckout`), `~/.cheat/inbox`
is a symlink into `cheatsheets/inbox/`, so a sheet written mid-session shows up in
`jj status` right away and promotion is a plain `mv`. Elsewhere it is an ordinary
directory - still writable, just not versioned.

## Local `.cheat` directories

Cheat automatically detects a `.cheat` folder in your current working directory. This enables project-specific cheatsheets without any configuration:

```
my-project/
├── .cheat/
│   └── deploy      # Project-specific deploy commands
├── src/
└── justfile
```

When you `cd` into a directory with `.cheat`, those sheets are temporarily added to your available cheatpaths. Great for embedding runbooks or common commands directly in a repository.

## Configuration

See `conf.nix` - generates the `conf.yml` that cheat reads. Sets helix as the editor and defines the cheatpaths.
