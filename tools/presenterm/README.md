# presenterm themes

Terminal slide decks. `presenterm` itself is installed for every profile
(`home-manager/modules/common.nix`); this directory carries the theme content,
wired to `~/.config/presenterm/themes/` by
`home-manager/modules/tools/presenterm.nix`.

## rustconf

`themes/rustconf.yaml` — the RustConf 2026 palette, shared with the HTML deck
theme at `tools/agents/skills/html-deck/template-rustconf.html`. Both were
extracted from the live site's `salient-dynamic-styles.css` (2026-09-09):

| Token | Hex | Role on rustconf.com |
| --- | --- | --- |
| navy_deep | `#091130` | hero background, body text colour (`--nectar-font-color`) |
| navy | `#112260` | secondary navy, block backgrounds |
| white | `#fafbff` | page background |
| yellow | `#ffde52` | the accent (`--nectar-accent-color`) |
| teal | `#37c3bf` | button outlines, rules |
| mint | `#a2faf7` | pale tint |
| rust | `#f74c00` | the Rust orange, used sparingly |
| electric | `#3452ff` | rare fourth hue |

The web design is dark-text-on-white with a deep-navy hero. The terminal theme
inverts that deliberately — the hero navy is the ground, because a light theme
fights whatever terminal the deck is projected from. The HTML template keeps
both: light content slides, navy title/section slides.

```bash
presenterm --theme rustconf tools/presenterm/examples/rustconf-template.md
```

or, per deck, in the front matter:

```yaml
theme:
  name: rustconf
```

`examples/rustconf-template.md` is a skeleton deck exercising the elements the
theme styles: setext slide titles, the heading ladder, code, block quotes,
GitHub-style alerts, and the intro slide built from front matter.

## Maintenance

The theme is written against **presenterm 0.16.1** — the version the pinned
nixpkgs in `flake.lock` carries. The top-level `PresentationTheme` struct is
`#[serde(deny_unknown_fields)]`, so a key from a newer release makes the whole
theme fail to load, not degrade. Two consequences:

- `column_layout` and `d2` (present in upstream `themes/dark.yaml` on master)
  are deliberately absent here.
- After a `nix flake update` that bumps presenterm, new keys may be adopted —
  but check the release notes for *renamed* or *removed* ones first, since
  those break loading outright.

`code.theme_name` is a syntect theme name from a fixed list; an unknown one
fails at render time rather than at load.
