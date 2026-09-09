---
name: html-deck
description: Generate self-contained, single-file HTML presentation decks — no framework, no build step, no dependencies beyond Google Fonts. Use this skill whenever the user wants to create slides, a slide deck, a talk, a presentation, or a "deck" that should be an HTML file (not PowerPoint/PPTX, not Google Slides, not a terminal/Markdown tool like presenterm). Especially use it for technical talks, conference/meetup presentations, video-series intros, or any time the user wants code-authored, version-controllable slides. Two themes ship with it: a dark editorial Ditto-brand theme (the default) and a RustConf 2026 theme for Rust-conference and Rust-community talks. Also trigger when the user references this house style, asks for "a deck like Tonbi's", asks for something "in the RustConf style", or wants to convert an outline/notes into presentable slides. Default to this skill for HTML decks even if the user doesn't say "HTML" explicitly, as long as they don't ask for PPTX or a WYSIWYG tool.
---

# HTML Deck

Generates a presentation as **one self-contained `.html` file**: all CSS and JS inline, slides as stacked `<div>`s, a ~40-line vanilla-JS engine for navigation. No reveal.js, Slidev, Marp, or build step. Opens directly in any browser; lives happily in git.

This is a code-authored alternative to PPTX and to terminal tools like presenterm — closest in spirit to reveal.js but with zero framework.

## When to use vs. not

- **Use** for: technical talks, conference/meetup decks, series intros, anything the user wants as an HTML file or in version control.
- **Don't use** for: `.pptx` (use the `pptx` skill), Google Slides, or when the user explicitly wants a terminal/Markdown renderer. For a terminal deck, presenterm is installed and `tools/presenterm/themes/rustconf.yaml` carries the matching RustConf palette.

## Themes

Two templates, **one component system**. They define the same class names and ship the same engine, so slide markup moves between them unchanged — retheming a finished deck means swapping the `<head>` block, not rewriting slides.

| | `template.html` | `template-rustconf.html` |
| --- | --- | --- |
| Look | dark, editorial, monochrome + acid yellow | RustConf 2026: light slides, deep-navy title/section slides |
| Brand | Ditto 2024 brand guidelines | rustconf.com (2026 redesign) |
| Use for | Ditto-facing talks, internal decks, the default house style | Rust-conference talks, Rust community content, anything that should read as RustConf-adjacent |

**Pick `template.html` unless the talk is Rust-community-facing or the user asks for the RustConf look.** When in doubt, ask which.

## Workflow

1. **Get the content first.** If the user gave an outline, notes, or a topic, work from it. If the deck is thin on substance, ask for the spine: the one-sentence thesis, the audience, and roughly how many slides / how long the talk is. Don't invent technical claims — for the user's own domain (Rust, FFI, Ditto, CRDTs, SDK work), use what they give you and flag anything you're unsure of rather than fabricating.
2. **Pick the theme, then read that template.** Always start from `template.html` or `template-rustconf.html`. Each is the canonical design system and engine for its theme — copy it, don't reinvent it. Read it in full before editing so you use the real class names.
3. **Build the deck** by editing a copy: replace the sample slides with real ones, keeping `data-slide="N"` sequential from 0. Reuse the component patterns (see below) rather than writing new CSS. Only add new CSS if a slide genuinely needs a layout the template doesn't cover.
4. **Renumber.** Make sure `data-slide` indices are 0-based and contiguous, and the `<title>` reflects the deck. The JS derives counts automatically — don't hardcode totals.
5. **Save to `/mnt/user-data/outputs/`** with a descriptive kebab-case filename (e.g. `production-ffi-at-scale.html`), then call `present_files`.

## The Ditto design system (`template.html`)

Themed to the **2024 Ditto brand guidelines**. Tokens live in `:root` — always use the variables, never raw hex in slide markup:

- Palette (RAL values from the brand guide): `--bg #0a0a0a` (RAL 9005 deep black), `--surface #1d1d1d` (9017 off-black), `--text-dim #9c9c9c` (9022 mid grey), `--light #d6d6d6` (9018 light grey), `--text #f6f6f6` (9016 near-white), and the single brand accent `--accent #e9ef44` (RAL 1016, Ditto acid yellow).
- **The system is essentially monochrome + yellow.** There is one accent. The `--blue/--green/--purple/--red` tokens are deliberately aliased to greys/yellow so older multi-color components degrade gracefully into the brand. Don't reintroduce rainbow accents — use greys for differentiation and yellow only for the thing you want the eye to land on.
- Fonts: `--font-display` for headlines, `--font-body` Inter (the exact brand body face), `--font-mono` for eyebrows/labels/buttons. Headlines are **upright** (no italics); emphasis is an upright `<em>` set in `--accent` yellow, never italic.
- Motifs: **diamond/dot field** (`.diamond-bg`) — the signature Ditto pattern, sparse-to-dense across the slide. Use it on title and section slides. `.grid-bg` (faint square grid) is the quieter alternative.
- **Primary CTA** (`.cta`) — yellow fill, dark uppercase mono text, straight from the brand guide.

### Font licensing caveat (important)

Ditto's real brand fonts are **Kairos Sans** (headlines) and **Aeonik Fono** (eyebrows/buttons) — both commercially licensed and not on Google Fonts. The template substitutes free look-alikes: **Space Grotesk** (wide geometric ≈ Kairos Sans), **Inter** (exact brand match), **Space Mono** (≈ Aeonik Fono). The `--font-display`/`--font-mono` stacks list the real brand fonts first, so if you self-host the licensed files the deck upgrades automatically with no other changes. For an internal/external talk the substitutes are fine; for anything customer-facing, self-host the real fonts.

## The RustConf design system (`template-rustconf.html`)

Palette and type extracted from rustconf.com's `salient-dynamic-styles.css` (2026-09-09), not eyeballed:

- `--navy-deep #091130` (hero ground, body text colour), `--navy #112260`, `--off-white #fafbff` (page), `--rule #dce0e1` (hairlines), `--yellow #ffde52` (**the** accent), `--teal #37c3bf` (outlines, rules, spines), `--mint #a2faf7`, `--rust #f74c00` (the Rust orange — sparingly), `--electric #3452ff`.
- **Light by default, navy where it counts.** The site is dark-text-on-white with a deep-navy hero; the deck reproduces that rhythm. Add `.navy` to any slide to invert it — the class re-binds the semantic tokens (`--bg`, `--text`, `--surface`, `--border`, `--accent`), so every component follows automatically. Title, section, and stat slides ship as `.navy`. To flip the whole deck dark, move that block's declarations into `:root`.
- Fonts: **Alfa Slab One** display + **TikTok Sans** body — the site's actual pairing, both on Google Fonts (OFL), so no licensing substitution is needed. Alfa Slab One has exactly one weight and is very heavy: the site uses it only for the hero headline, and so does the template (`h1`, `.stat`, section-slide `h2`). Section headings are TikTok Sans. **Don't set body copy or h2 in the slab** — that is the fastest way to make this theme look wrong.
- Eyebrows and labels are sans caps with wide tracking (`--font-ui`), not mono. `--font-mono` is for code and the nav chrome only.
- Emphasis is the site's yellow used as a **highlighter bar** behind `<em>` inside `h2`, not a text-colour swap.
- Buttons: the site has exactly two, and both are here — `.cta` (square, 2px teal outline, uppercase) and `.link-cta` (uppercase text with a thick underline). `.cta.solid` fills yellow when a slide needs one loud button. Corners are square-to-4px; don't round them.
- Motif: `.code-bg` is the signature — the site's hero is **lines of code with every token redacted into a chunky pointed-hexagon bar** (mint, rust orange, yellow, white on navy), punctuation glyphs left legible in between. The template draws its own pattern in that language rather than shipping the site's `Hero-Image` asset, and masks it so it fades out on the left where headline text sits. Its bar edges carry a deliberate wobble: theirs are hand-drawn, not ruled, and clean geometry reads as a different design. `.cog-bg` (an oversized outlined **generic** gear — not the Rust logo, which is a Rust Foundation trademark) is the quieter alternative; `.grid-bg` and `.diamond-bg` also work, the latter kept as an alias so Ditto-themed markup ports cleanly.
- **`.tokens`** — the same joke as markup, for when a slide should spell one out: a row of `.tok.bar` (`orange`/`white`, widths `w1`/`w3`), `.tok.diamond`, `.tok.punct` for a brace, and one `.tok.word` left legible. The site does this with RUSTUP / HELLO / PRINTLN!. One line, one real word — it stops being a joke at two.
- The matching terminal theme is `tools/presenterm/themes/rustconf.yaml` — same palette, for `presenterm --theme rustconf`.

## Components available in both templates

Each is shown working in the template. Pick the ones that fit; delete the rest.

- **`.title-slide`** — opening slide with `.tag` eyebrow, big `<h1>`, `.subtitle`, optional `.cta`/`.link-cta`, and a `.title-glow`.
- **`.section-slide`** — centered divider; pairs with the theme's motif and `.section-sub`.
- **`.lead`** — a single large thesis statement on its own slide.
- **`.two-col`** + **`.card`** (variants `accent|blue|green|purple|yellow`, plus `rust` in the RustConf theme) — side-by-side comparison cards with a colored spine.
- **`pre > code`** — syntax-neutral code block with an accent left border, for technical/live-coding slides.
- **`.contrast`** with `.contrast-box.no` / `.contrast-box.yes` — the "not this / this" pattern.
- **`.principles`** + **`.principle`** (variants `p-accent|p-blue|p-green|p-purple`, plus `p-rust`) — numbered rule cards with a ghosted big number.
- **`.hl-list`** — bordered highlight list with mono bullets.
- **`.card-grid`** — `repeat(N,1fr)` grid for episode/topic cards (adjust the column count inline).
- **`.legend`** — color-key row to label a multi-color grid.
- **`.stat`** + **`.stat-label`** — one giant number for an impact slide.
- **`.cta`** — primary button. **`.link-cta`** — underlined uppercase text link (RustConf theme).
- Background motifs: `.grid-bg` in both; `.diamond-bg` in both; `.code-bg` and `.cog-bg` in the RustConf theme; `.navy` to invert a RustConf slide.
- **`.tokens`** + `.tok` (RustConf theme) — a hand-written line of redacted code.

## The engine (already in the template — leave it alone unless asked)

- Slides stacked with `position:absolute; inset:0`; visibility toggled by `.active` (opacity + small `translateY`).
- `navigate(±1)`, `showSlide(i)`, a progress bar, and an `NN / NN` counter.
- Keyboard: → / Space / Enter advance; ← / Backspace go back; Home / End jump; **N toggles speaker notes**.
- Touch: horizontal swipe.
- **Speaker notes**: put a `data-notes="..."` attribute on any slide; it shows in the notes panel when the presenter presses N. Use these to encode pacing cues (where to slow down, where the user tends to speed up) rather than cramming them on the slide.

## Quality bar

- Keep slides sparse — one idea each. Both systems are built on a single accent and a lot of whitespace; let the accent do the work.
- Prefer the existing components; a deck that uses 4–5 of them consistently looks far better than one with bespoke CSS on every slide.
- Verify the file opens standalone: the only external request should be the Google Fonts link.
- Sequential `data-slide` from 0; descriptive `<title>`; meaningful filename.
