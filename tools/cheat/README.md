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
cheat jj/fix        # View a cheatsheet
cheat -l            # List all available cheatsheets
cheat -s keyword    # Search cheatsheets
cheat -e jj/new     # Create/edit a cheatsheet
```

## Structure

```text
.cheat/            # this repo's sheets, found from anywhere in the repo
tools/cheat/
└── conf.yml       # the config
```

## Local `.cheat` directories

Cheat automatically detects a `.cheat` folder in your current working directory. This enables project-specific cheatsheets without any configuration:

```text
my-project/
├── .cheat/
│   └── deploy      # Project-specific deploy commands
├── src/
└── justfile
```

When you `cd` into a directory with `.cheat`, those sheets are temporarily added to your available cheatpaths. Great for embedding runbooks or common commands directly in a repository.

## Configuration

`conf.yml` sets helix as the editor and `less -FRX` as the pager. It lists no
cheatpaths of its own: the repo's `.cheat/` is found automatically. mise points
`CHEAT_CONFIG_PATH` at it (see `mise.toml`), so it applies wherever mise is
active in this repo. Paths in `conf.yml` are not env-expanded, and relative ones
resolve against the working directory, so an added cheatpath needs an absolute
or `~` path. Linking it to `~/.config/cheat/conf.yml` (mise or home-manager) is
still to come.
