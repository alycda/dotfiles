---
name: html-deck
description: Generate self-contained, single-file HTML presentation decks — no framework, no build step, no dependencies beyond Google Fonts. Use this skill whenever the user wants to create slides, a slide deck, a talk, a presentation, or a "deck" that should be an HTML file (not PowerPoint/PPTX, not Google Slides, not a terminal/Markdown tool like presenterm). Especially use it for technical talks, conference/meetup presentations, video-series intros, or any time the user wants code-authored, version-controllable slides with a dark, editorial design. Also trigger when the user references this house style, asks for "a deck like Tonbi's", or wants to convert an outline/notes into presentable slides. Default to this skill for HTML decks even if the user doesn't say "HTML" explicitly, as long as they don't ask for PPTX or a WYSIWYG tool.
---

# HTML Deck

Generates a presentation as **one self-contained `.html` file**: all CSS and JS inline, slides as stacked `<div>`s, a ~40-line vanilla-JS engine for navigation. No reveal.js, Slidev, Marp, or build step. Opens directly in any browser; lives happily in git.

This is a code-authored alternative to PPTX and to terminal tools like presenterm — closest in spirit to reveal.js but with zero framework.

## When to use vs. not

- **Use** for: technical talks, conference/meetup decks, series intros, anything the user wants as an HTML file or in version control.
- **Don't use** for: `.pptx` (use the `pptx` skill), Google Slides, or when the user explicitly wants a terminal/Markdown renderer.

## Workflow

1. **Get the content first.** If the user gave an outline, notes, or a topic, work from it. If the deck is thin on substance, ask for the spine: the one-sentence thesis, the audience, and roughly how many slides / how long the talk is. Don't invent technical claims — for the user's own domain (Rust, FFI, Ditto, CRDTs, SDK work), use what they give you and flag anything you're unsure of rather than fabricating.
2. **Read the template.** Always start from `template.html`. It is the canonical design system and engine — copy it, don't reinvent it. Read it in full before editing so you use the real class names.
3. **Build the deck** by editing a copy of the template: replace the sample slides with real ones, keeping `data-slide="N"` sequential from 0. Reuse the component patterns (see below) rather than writing new CSS. Only add new CSS if a slide genuinely needs a layout the template doesn't cover.
4. **Renumber.** Make sure `data-slide` indices are 0-based and contiguous, and the `<title>` reflects the deck. The JS derives counts automatically — don't hardcode totals.
5. **Save to `/mnt/user-data/outputs/`** with a descriptive kebab-case filename (e.g. `production-ffi-at-scale.html`), then call `present_files`.

## The design system (Ditto brand — do not drift from it)

The template is themed to the **2024 Ditto brand guidelines**. Tokens live in `:root` — always use the variables, never raw hex in slide markup:

- Palette (RAL values from the brand guide): `--bg #0a0a0a` (RAL 9005 deep black), `--surface #1d1d1d` (9017 off-black), `--text-dim #9c9c9c` (9022 mid grey), `--light #d6d6d6` (9018 light grey), `--text #f6f6f6` (9016 near-white), and the single brand accent `--accent #e9ef44` (RAL 1016, Ditto acid yellow).
- **The system is essentially monochrome + yellow.** There is one accent. The `--blue/--green/--purple/--red` tokens are deliberately aliased to greys/yellow so older multi-color components degrade gracefully into the brand. Don't reintroduce rainbow accents — use greys for differentiation and yellow only for the thing you want the eye to land on.
- Fonts: `--font-display` for headlines, `--font-body` Inter (the exact brand body face), `--font-mono` for eyebrows/labels/buttons. Headlines are **upright** (no italics); emphasis is an upright `<em>` set in `--accent` yellow, never italic.

### Font licensing caveat (important)

Ditto's real brand fonts are **Kairos Sans** (headlines) and **Aeonik Fono** (eyebrows/buttons) — both commercially licensed and not on Google Fonts. The template substitutes free look-alikes: **Space Grotesk** (wide geometric ≈ Kairos Sans), **Inter** (exact brand match), **Space Mono** (≈ Aeonik Fono). The `--font-display`/`--font-mono` stacks list the real brand fonts first, so if you self-host the licensed files the deck upgrades automatically with no other changes. For an internal/external talk the substitutes are fine; for anything customer-facing, self-host the real fonts.

## Brand visual motifs

- **Diamond/dot field** (`.diamond-bg`) — the signature Ditto pattern: a dot field that fades from sparse to dense across the slide. Use it on title and section slides. `.grid-bg` (faint square grid) remains available as a quieter alternative.
- **Primary CTA** (`.cta`) — yellow fill, dark uppercase mono text, straight from the brand guide. Use on a title or closing slide.

## Components available in the template

Each is shown working in `template.html`. Pick the ones that fit; delete the rest.

- **`.title-slide`** — opening slide with `.tag` eyebrow (bordered yellow), big `<h1>`, `.subtitle`, optional `.cta`, and a `.title-glow`.
- **`.section-slide`** — centered divider; pairs with the diamond motif and `.section-sub`.
- **`.lead`** — a single large thesis statement on its own slide.
- **`.two-col`** + **`.card`** (variants `accent|blue|green|purple|yellow`) — side-by-side comparison cards with a colored spine.
- **`pre > code`** — syntax-neutral code block with an accent left border, for technical/live-coding slides.
- **`.contrast`** with `.contrast-box.no` / `.contrast-box.yes` — the "not this / this" red-vs-green pattern.
- **`.principles`** + **`.principle`** (variants `p-accent|p-blue|p-green|p-purple`) — numbered rule cards with a ghosted big number.
- **`.hl-list`** — bordered highlight list with mono bullets.
- **`.card-grid`** — `repeat(N,1fr)` grid for episode/topic cards (adjust the column count inline).
- **`.legend`** — color-key row to label a multi-color grid.
- **`.stat`** + **`.stat-label`** — one giant number for an impact slide.
- **`.cta`** — brand primary button (yellow fill, dark mono text).
- **`.title-qr`** — a QR centred on the title slide's `.title-glow`. Its offsets are derived from the glow's (`top:15%`/`right:8%`, 500px), so if you move the glow, move this with it.
- **`.image-slide`** — full-bleed single image, no chrome: a speaker card, screenshot, or diagram. Scales to the padded box, keeps aspect ratio.
- **`.two-col.media`** + **`.photo-stack`** — photo-and-text split: portraits stacked in one height-bound frame on the left, a `.lead` and `.hl-list` links on the right. `.photo-stack .credit` sits under the frame for photographer attribution.
- **`.cast-btn`/`.cast-overlay`/`.cast-screen`** — inline asciicast replay; see "Recorded terminal demos" below.
- **`.diamond-bg`** — signature Ditto dot/diamond field; **`.grid-bg`** — quieter faint grid. Add either class to any slide.

## The engine (already in the template — leave it alone unless asked)

- Slides stacked with `position:absolute; inset:0`; visibility toggled by `.active` (opacity + small `translateY`).
- `navigate(±1)`, `showSlide(i)`, a progress bar, and an `NN / NN` counter.
- Keyboard: → / Space / Enter advance; ← / Backspace go back; Home / End jump; **N toggles speaker notes**.
- Touch: horizontal swipe.
- **Step reveal (`data-step`)**: any element with `data-step="N"` starts hidden. → reveals the next step *before* advancing the slide; ← retracts the last one before going back. The slide counter does not move between steps. Elements sharing a number reveal together. This is presenterm's `<!-- pause -->` in spirit — use it to hold a conclusion back until after the audience has read the code.
- **Skipping a slide (`data-skip`)**: presenterm's `skip_slide`. The slide stays in the file and in DOM order but drops out of the run *and* out of the count. Use it for a slide you cut but don't want to lose — remove the attribute to bring it back. Don't delete a cut slide; skip it, so the reasoning survives in the file.
- **Presenter sync (`?sync=`)**: optional two-browser mode — see "Two-browser presenter mode" below. Inert unless the parameter is present.
- **Speaker notes**: put a `data-notes="..."` attribute on any slide; it shows in the notes panel when the presenter presses N. Use these to encode pacing cues (where to slow down, where the user tends to speed up) rather than cramming them on the slide.

## Two-browser presenter mode

Arc fullscreen on the projector, Brave with the speaker notes on the laptop,
both showing the same deck in step. Opt-in: with no `?sync=` parameter none of
it runs and the deck makes no network request.

```bash
node sync-relay.mjs my-deck.html          # serves the deck AND relays state
#   stage  http://localhost:8080/?sync=http://localhost:8080
#   notes  http://localhost:8080/?sync=http://localhost:8080&role=notes
```

**What crosses the wire is state, never keystrokes.** Sending keys would fire
"toggle notes" in *both* windows, which is exactly backwards — notes visibility
is a property of the role, not of the deck. The payload is `{slide, steps}` and
nothing else, so everything role-shaped (notes, the cast overlay, fullscreen)
stays local by construction. Since step groups are synced as a *count*, the two
windows agree on reveals without either replaying input.

Either window can drive, so it doesn't matter which browser has keyboard focus.
`seq` is a Lamport clock that drops stale updates and `from` discards your own
echo. A window that joins late is handed the current position by the relay
rather than waiting for the next keypress.

`?role=notes` gives the presenter's window an always-on panel with a NEXT line,
moves the counter clear of it, and hides the nav buttons. `?room=NAME` keeps two
decks on one relay from talking to each other.

### `?role=viewer` — attendees, with the ending kept back

`stage` and `notes` are two windows one person owns, so between them the
protocol is symmetric: either may drive. `viewer` is the first role that is a
**permission** rather than a presentation choice — an attendee on their own
machine.

A viewer never publishes position, so it cannot move anyone else's deck, and it
cannot navigate past the furthest slide the presenter has reached. Backwards is
always free: being able to re-read is the reason this is a lock and not a leash.

- **Detaching is implicit.** Navigating *is* the signal. Nobody should have to
  find an "unfollow" control before doing the obvious thing.
- **Re-attaching is explicit and always visible** — `F`, or the badge, which is
  a button precisely so the way back does not depend on a shortcut nobody
  mentioned. A detached viewer is never snapped forward automatically; that is
  the yank they stepped out of the way to avoid.
- **The high-water mark never retreats.** If you step back to re-explain
  something, slides already shown stay reachable — content is not yanked away
  from people still reading it.
- A viewer gets each slide **fully revealed**. Step reveals are the presenter's
  pacing device; someone reading at their own rate should not have content
  hidden for another person's timing.

**This is not a secret.** Every slide is still in the file the viewer
downloaded — devtools, view-source, or ctrl-F will show the ending. It stops
idle skipping ahead, which is the real problem (an exercise solution read three
slides early). It will not stop anyone who decides to look, and it is not meant
to. Genuinely withholding content means not shipping it, which costs the deck
the single-file offline property that is the point of it —
`docs/follow-mode.md` works through that trade.

Without `?sync=`, `?role=viewer` has no presenter to track, so the gate stays
off rather than locking the deck at slide 1.

Everything past this — attendees at scale, presenter authentication, a reverse
channel — is parked in `docs/follow-mode.md`.

### Choosing a transport

The relay is local on purpose: the deck already carries a recorded terminal demo
so dead venue wifi can't break it, and slide navigation shouldn't reintroduce
the dependency the recording exists to avoid. It's SSE down / POST up rather
than WebSocket — no framing (so no dependency), and `EventSource` reconnects on
its own, so a laptop that sleeps mid-talk recovers with no reconnect code.

**This only works when the deck is served from the relay** (or another
`http://localhost` origin). A deck loaded from the published cf-now `https://`
URL cannot open a `ws://` or `http://localhost` connection — mixed content — so
presenting from the published URL means a hosted transport instead.

Adding one is a single function; nothing in the protocol changes:

```js
Transports.mine = (endpoint, room, onState) => {
  /* call onState(obj) on each remote update */
  return { send: state => { /* publish it */ } };
};
```

Then `?transport=mine&sync=<endpoint>`. Two ship in the template:

| `?transport=` | When |
| --- | --- |
| `sse` (default) | Local relay. Offline, no account. Requires the deck be served from the relay or another `http://localhost` origin. |
| `supabase` | Supabase Realtime broadcast. Use when presenting from the published (https) URL, or when the two machines aren't the same one. |

```
?transport=supabase&sync=https://<ref>.supabase.co&key=<publishable-key>&room=talk
```

The Supabase adapter talks to Realtime over a **raw `WebSocket`, not
`supabase-js`** — broadcast needs none of the SDK, and a CDN bundle would cost
the deck the single-file, works-offline property that is the point of it. It
speaks Phoenix channels: `phx_join` on `realtime:<room>`, `broadcast` frames
either way, and a `heartbeat` on the `phoenix` topic every 25s (Phoenix closes
a channel that stops heartbeating). The scheme follows the endpoint, so a
self-hosted Supabase on plain `http://` works as well as the hosted one.

Broadcast is **ephemeral** — nothing is written to the database, which is the
right shape for a position that means nothing once the talk ends. The cost is
that there's no history for a late joiner, so the deck sends a `hello` on
connect and whoever is further along answers. (The local relay replays
last-state server-side, so `hello` is redundant there and harmless — the clock
drops whichever copy lands second.)

The publishable key sits in the URL. It's public by design, but the URL is a
thing you paste around, so scope it to a broadcast-only channel rather than
reusing a key that can reach real tables.

## Recorded terminal demos (the demo-gods fallback)

For a talk with a live demo, record a fallback and embed it. The template ships
a tiny asciicast player: a `.cast-btn` opens a `.cast-overlay` that replays a
recording over the slide. Space pauses, Esc closes.

1. `asciinema rec docs/demo.cast` — do the demo, exit the shell.
2. Paste the file **verbatim** into a `<script type="application/json" id="cast-NAME">`
   on the slide (header line, then one event per line).
3. Point the button at it: `<button class="cast-btn" data-cast="cast-NAME">`.

Two deliberate limits: playback caps the gap between events at 2s, so a long
think-pause in the recording doesn't become a long silence in the room; and the
parser understands only the ANSI a build log tends to emit (SGR 0/1/2/32/92/96
plus a CR + erase-line progress line). That's what buys you a player with no
library, no CDN, and no dependency on the room's wifi. A recording using more
colors won't break — the extra escapes are simply dropped. If you need a real
terminal emulator, you need a different tool.

Delete the cast slide, the `.cast-*` CSS, and the cast handler in the script if
the deck has no recording.

## Quality bar

- Keep slides sparse — one idea each. The monochrome-plus-yellow system only reads well with whitespace; let the single accent do the work.
- Prefer the existing components; a deck that uses 4–5 of them consistently looks far better than one with bespoke CSS on every slide.
- Verify the file opens standalone: the only external request should be the Google Fonts link (Space Grotesk / Inter / Space Mono).
- The template's images are inline-SVG placeholders so it stays self-contained. Replace them with real files (or a data URI) — never ship a deck with a broken `src`, and always write real `alt` text, since the file outlives the room.
- Sequential `data-slide` from 0; descriptive `<title>`; meaningful filename.
