---
title: "alyssa.rs: a CV and portfolio site on Topcoat, Effect, and impeccable"
date: 2026-09-22
status: draft
repo: alyssa-rs (new; jj-local, pushed to Soft Serve on venari)
inputs:
  - "#172 effect + topcoat skills (open, stacked base of #173)"
  - "#173 self-hosted Convex on venari (draft, not needed by this plan)"
  - "pbakaus/impeccable @ plugin 4.3.1, engine 0.1.5 (read 2026-09-22)"
  - "tokio-rs/topcoat v0.8.1 (the rev the topcoat skill was written against)"
  - "effect 4.0.0-rc.117 (npm `rc` tag on 2026-09-22; `latest` is 3.22.2)"
---

# alyssa.rs: CV and portfolio

This is a plan, not a design. The visual direction is deliberately not chosen
here: impeccable's own flow (`init` records product truth, `shape` and
new-work choose the visual world) is where that happens, and this plan only
fixes the inputs to that flow. What it does decide is the split of work between
the three tools, the repo shape, the hosting, and the order of phases.

Wording rule for every artifact this plan produces (copy, code, routes, commit
messages): the document is a **CV**. The other word for it does not appear.

## The recommendation, in one paragraph

Topcoat serves the site. Effect owns the content pipeline that feeds it.
impeccable owns the design process and the quality gates. The boundary between
Effect and Topcoat is one committed file, `content/cv.json`, with a schema on
each side and a test on each side that reads the same fixture. The site is a
Rust binary plus an asset bundle, cross-compiled on the laptop and shipped to
venari the way `ghost-server` is, behind Caddy on ports 80/443, which are the
first inbound ports the box opens beyond 22.

## Why this split (and what was rejected)

**Where Effect goes.** Topcoat has no JS build step by design: no bundler, no
wasm, the client runtime is an injected script. An Effect program in the page
would mean adding the bundler Topcoat exists to avoid, so Effect does not run in
the browser or in the server. What a CV site does have is a content problem
that fits Effect exactly: one data model, strict validation (dates in order,
every project links to a real page, every employer has an end date or is
current), and several derived outputs (the JSON the site compiles in, a
plaintext CV at `/cv.txt` for people who paste into an applicant tracker,
later a PDF). That pipeline is an Effect CLI: `Schema` for the model,
`Effect.fn` for the steps, `FileSystem` for I/O, typed errors for every way
the content can be wrong. It is also the first real consumer of the #172
`effect` skill, on v4, in a greenfield repo where the v3/v4 gate is trivially
"v4".

Rejected: Effect as the HTTP server with Topcoat components rendered behind it
(two servers for a static CV), and effect-atom on the client (needs the JS
build). Both would be the tools for their own sake.

**Which Effect.** v4 `4.0.0-rc.117`, pinned exact. Reasons: greenfield, so no
migration cost; the package ships `AGENTS.md` and `ai-docs/` (checked in the
tarball), which is what the `effect` skill routes to; the Effect team's own
`effect-ts` skill installs it. Cost: it is a release candidate, so every bump is
a `just ci` run and a read of the migration notes, and the `effect` skill's
"verify against the installed package" rule is not optional. If you would
rather not ride an RC on a site that must simply stay up, v3 `3.22.2` is the
alternative and the pipeline is small enough that porting later is cheap.

**Where Topcoat's runtime earns its keep.** A CV is mostly static, so the
question "why not a static generator" is fair. Three things Topcoat gives that
a generator does not, in order of weight: the `view!`/`#[component]` model is
the Rust shape of the Effect stack the #172 skills pair, and this site is the
place to learn it on something real; `#[route]` for `/cv.json`, `/cv.txt`,
`/sitemap.xml` is the same code as the pages; and a contact procedure with
`topcoat-mail` later needs a server anyway. If those stop mattering, a crawl
of the running site is a static export (Phase 5 builds that crawl for the
detector regardless).

**Hosting.** venari, in `/srv/alyssa-rs/`, as a `site` container on an
internal network plus a `caddy` container publishing 80/443 with automatic
TLS. This is the "port other than 22 in the cloud firewall and a TLS reverse
proxy" decision that #173 deferred; the CV site is the forcing function, and
once Caddy is there the Convex frontend question is a `Caddyfile` stanza.
Alternatives: `cloudflared` (no inbound ports, but a hosted dependency in the
request path of a personal site), and Cloudflare Pages from the crawl (no
server at all, loses everything in the paragraph above). Opening two ports
changes the box's posture from ssh-only; the mitigations are in Phase 6.

## What impeccable can and cannot do against a Rust `view!` stack

Read from the repo, not from its marketing.

| Layer | Mechanism | On this stack |
|---|---|---|
| Skill and 24 commands | LLM playbooks in `skill/reference/*.md` | Works fully; the playbooks read PRODUCT.md, DESIGN.md, and the code |
| `PRODUCT.md` / `DESIGN.md` / `.impeccable/surfaces/*.md` | Plain committed files | Works fully |
| Detector, static | Scans `.html .astro .vue .svelte .css .scss .js .ts .jsx .tsx` (`crates/detect/src/detect_text.rs:34-55`) | Sees the Tailwind input CSS and nothing in `.rs`. `detector.extensions` can add `{"ext": ".rs", "engine": "html"}`; whether the HTML analyzer makes sense of `view!` bodies (quoted text nodes, `(expr)` interpolation) is an experiment in Phase 5, expected to be noisy |
| Detector, rendered | `impeccable detect http://...` drives headless Chrome over CDP (`crates/browser/src/cdp.rs`) | Works, and is the more truthful scan anyway: it sees what Topcoat emitted, computed contrast included. Needs Chrome on the machine that runs it |
| Design hook (post-edit) | Fires on the extension list above | Fires on `styles.css` edits, never on `view!` edits. `impeccable context` will emit `MANUAL_DETECTOR_REQUIRED`; the `just design-check` recipe in Phase 5 is the answer |
| Live mode | Injects a `<script>` before `</body>` in the HTML files the browser loads (`reference/live-setup.md`) | The file the browser loads is a `view!` body in a `.rs` file. Unverified whether an injected raw `<script>` block compiles inside `view!`; assume not. Fallback: point `files` at the crawl in `dist/site/**/*.html`, iterate there, port accepted changes to the `.rs` by hand |

Net: the judgment layer is intact, the mechanical layer works on rendered
output and CSS. That is a smaller loss than it looks, because a detector run on
the crawl in CI is closer to what impeccable calls "the site is the demo" than
a scan of source would be.

Two anti-references to record in PRODUCT.md's brand section so the visual work
does not drift into them: impeccable's own `DESIGN.md` (kinpaku gold on lacquer
black, a strong world that every project using the skill has seen), and the
`html-deck` skill's tokens, which are the employer's brand and cannot appear on
a personal site.

## Repository layout

```
alyssa-rs/
├── flake.nix                 # devShell only: fenix stable (>= 1.98), tailwindcss_4,
│                             #   nodejs_22, cargo-zigbuild; no `nix build` of the site
├── justfile                  # ci = fmt-check + clippy + cargo test + content-check
│                             #   + tsc + vitest (+ design-check when Chrome is present)
├── Cargo.toml                # one binary crate; [lints.rust] unsafe_code = "deny"
├── build.rs                  # tailwind BuildConfig: .input("styles.css").executable_env("TAILWIND_CLI")
├── styles.css                # Tailwind input: @import "tailwindcss" + the DESIGN.md tokens
├── src/
│   ├── main.rs               # topcoat::start(Router::builder().discover().assets(...).build())
│   ├── app.rs                # module_router! tree: /, /cv, /work, /work/<slug>, /talks
│   ├── layout.rs             # #[layout]: <head>, fonts, stylesheet, skip link, footer
│   ├── cv.rs                 # serde model of content/cv.json + include_str! at compile time
│   ├── routes/               # /cv.json, /cv.txt, /sitemap.xml, /robots.txt
│   └── components/           # topcoat ui vendored components, if any; otherwise ours
├── static/
│   ├── fonts/*.woff2         # committed, OFL/other permissive licences, served via asset!
│   └── img/                  # portrait, project images, all through asset!
├── content/
│   ├── cv.ts                 # the CV, authored as a typed TS value
│   ├── schema.ts             # Effect Schema: the model, the checks, the derived types
│   ├── pipeline.ts           # Effect CLI: validate | build | text ; NodeFileSystem
│   ├── cv.json               # GENERATED by `just content`; committed; Rust compiles it in
│   ├── package.json          # effect@4.0.0-rc.117, @effect/platform-node@4.0.0-rc.117 (exact)
│   └── tsconfig.json         # strict, exactOptionalPropertyTypes, noUncheckedIndexedAccess
├── tests/
│   ├── routes.rs             # every route answers 200; /cv.json round-trips through serde
│   └── fixtures/cv.json      # one fixture both the TS and Rust tests read
├── deploy/
│   ├── docker-compose.yml    # site + caddy; twin lives in dotfiles tools/venari/alyssa-rs/
│   ├── Caddyfile
│   └── Dockerfile            # alpine + the cross-compiled binary + assets/
├── PRODUCT.md                # written by /impeccable init (Phase 3)
├── DESIGN.md                 # written by new-work (Phase 3), never by hand first
├── .impeccable/              # config.json, surfaces/*.md, critique/*.md tracked;
│                             #   the README's ignore block for the rest
├── .gitignore                # BEFORE the first build: target/, node_modules/, dist/,
│                             #   .env, the impeccable block (jj snapshots everything)
└── AGENTS.md / CLAUDE.md     # thin: points at the effect, topcoat, impeccable skills
```

Why `cv.json` is committed although generated: `cargo build` must never need
Node (the deploy build, a future CI runner, `cargo test` on venari's mise
account). `just content-check` regenerates it and fails on a diff, the same
"the lockfile is the pin" rule as `tools/hackmd/package-lock.json`.

Why the CV is authored in TypeScript rather than YAML or TOML: a typed value
gets its shape errors at authoring time from `tsc`, and Schema decoding of that
value at build time still runs the checks types cannot express (date order,
slug references). No YAML dependency, no second syntax. It is still plaintext
in version control.

## Phases

Each phase ends in a state that can be pushed and left. Commits inside a phase
follow the dotfiles rule: one logical change each, message says why.

### Phase 0: dotfiles side (this branch and follow-ups)

- **Land #172.** The `effect` and `topcoat` skills are the guidance this repo
  is built with. #173 is not a dependency (no Convex in this plan).
- **impeccable as a Claude Code plugin**, not a skill: add the
  `pbakaus/impeccable` marketplace and `impeccable@impeccable` to
  `tools/agents/plugins/catalog.json`, per the "plugins are not skills" rule.
  The plugin's launcher downloads the engine binary into `~/.impeccable/bin/`
  on first run; that is runtime-mutable state in `$HOME` and stays unmanaged
  (the `~/.claude` rule). Note it in the catalog comment so nobody tries to
  wrap it in a derivation.
- **Chrome for URL detection.** The rendered detector launches headless
  Chrome. On the laptop that is the Homebrew cask; record which. Without it,
  `impeccable detect` silently falls back to the static scan and reports an
  undercount.
- **Cheat sheet / just recipes** in `tools/just/personal.just`, mirroring the
  Ghost ones: `alyssa-rs-deploy` (Phase 6) and nothing else until needed.
- **venari twin**: `tools/venari/alyssa-rs/` gets the compose file, the
  `Caddyfile`, and the README section, in Phase 6.

### Phase 1: bootstrap the repo

```sh
mkdir alyssa-rs && cd alyssa-rs
jj git init --colocate
# .gitignore FIRST (target/, node_modules/, dist/, .env, the impeccable block)
jj describe -m "Bootstrap alyssa-rs: ignore file, flake devShell, justfile"
ssh venari-git repo create alyssa-rs -p
jj git remote add venari venari-git:alyssa-rs
jj bookmark create main -r @
jj git push --remote venari --named main=@
```

Deliverables: `flake.nix` (devShell only; Topcoat's own `flake.nix` is the
template, plus `tailwindcss_4` exported as `TAILWIND_CLI` so `build.rs` never
downloads, `nodejs_22` for the pipeline, `cargo-zigbuild` for Phase 6),
`justfile` with a `ci` recipe that runs everything Phase 2 and 4 add,
`rust-toolchain.toml` (stable, >= 1.98 for topcoat 0.8.1), and
`cargo install topcoat-cli --locked` documented in the README as a
`~/.cargo/bin` install (rustup already owns that directory; whether nixpkgs
carries `topcoat-cli` is unverified from this sandbox, so check before
promoting it into the devShell).

The repo stays private on Soft Serve; the site being public does not require
the source to be. No GitHub mirror in v1: Soft Serve has no CI, so `just ci`
is the gate, the same position `just ci` holds in dotfiles. Revisit if a
second machine needs to build it.

### Phase 2: the content pipeline (Effect)

- `content/schema.ts`: `Schema.Struct` model (identity, summary, positions,
  projects, talks, education, links), `Schema.check` for the invariants,
  `Schema.TaggedError` for each failure class (`InvalidDateRange`,
  `DanglingProjectRef`, `MissingRequired`). Verified against the rc.117
  tarball: `FileSystem` is `effect/FileSystem`, the Node layer is
  `NodeFileSystem` from `@effect/platform-node@4.0.0-rc.117`, and the CLI
  module is `effect/unstable/cli` (`Command`, `Flag`, `Argument`). Any other
  name gets a typecheck before it goes in a commit; the #172 lesson.
- `content/pipeline.ts`: `validate` (decode `cv.ts`, print every error, exit
  1), `build` (encode to `cv.json`, stable key order so diffs are readable),
  `text` (the plaintext CV: 80 columns, no markup, the conservative register).
- Tests: vitest on the fixture; one negative test per tagged error.
- `just content` = build + text; `just content-check` = build to a temp file
  and diff against the committed one.

Exit criterion: `just content-check` green, `cv.json` committed, and the
plaintext CV reads correctly when pasted into a form.

### Phase 3: product truth, then the visual world (impeccable)

Run `/impeccable init`. The interview will ask about users, purpose,
positioning, constraints, and evidence; the answers are yours, but the plan
fixes these inputs so init does not have to rediscover them:

- Users: hiring managers and staff-plus engineers evaluating a candidate;
  recruiters skimming for fit in under a minute; peers who followed a talk or
  a repo link. Situation: arriving from a link, usually on a phone.
- Purpose: a CV that reads in one pass and a portfolio that shows the work
  (Rust, FFI, cross-platform SDKs) with evidence, not adjectives.
- Voice: from `~/.agents/persona-core.md` (direct, specific, no hedging), and
  the register stays conservative: the document is called a CV throughout.
- Evidence on hand: brag-doc entries (private; they become the project pages
  after a pass for what is public), talks (the `html-deck` outputs), public
  repositories, the effect-playground. Absences to record so nothing is
  invented: no testimonials, no metrics that are not already public.
- Constraints: WCAG 2.1 AA; `prefers-reduced-motion` honoured; no third-party
  scripts, no analytics beacons, fonts self-hosted; no phone number or street
  address anywhere in content; the contact path is an email link (v1).
- Stack: recorded as Topcoat 0.8.1 with Tailwind via the standalone CLI, so
  init knows the choice was made and does not offer one.
- Brand: no existing identity to preserve. The two anti-references above.

Then `/impeccable shape` for the surface set, and new-work for the visual
world, which writes `DESIGN.md` and the surface briefs. Modes per surface:
`/` is Experience (the work leads), `/cv` is Read (a document, structured
for one-pass comprehension), `/work/<slug>` is Experience, `/talks` is Read.
If new-work offers comp-first, take it: a comp before code is cheap here and
the `view!` port of a chosen comp is a bounded job.

Exit criterion: `PRODUCT.md`, `DESIGN.md`, and `.impeccable/surfaces/*.md`
committed, each in its own change; `styles.css` carries the tokens DESIGN.md
declares and nothing else yet.

### Phase 4: the site (Topcoat)

Per the `topcoat` skill: read the guides at the `Cargo.lock` version
(`~/.cargo/registry/src/*/topcoat-0.8.1/docs/`), starting with
`functions_not_middlewares.md`, before each area.

- `Cargo.toml`: `topcoat` with `tailwind`, `asset`, `sitemap`, maybe
  `icon-iconify`; the build-dependency copy with `default-features = false`
  (the coffee-shop demo is the reference). `[lints.rust] unsafe_code = "deny"`.
- `build.rs`: `BuildConfig::new().input("styles.css").executable_env("TAILWIND_CLI").render()`.
  Offline, reproducible, no GitHub download in a build script.
- `src/cv.rs`: serde structs mirroring the Schema; `include_str!("../content/cv.json")`
  parsed once into an `app_context` value registered in the one
  `Router::builder()` chain. Route tests request every route, which is the
  skill's "a green build says nothing about registration" rule made
  executable.
- Routes: `module_router!` for pages; `#[route(GET ...)]` for `/cv.json`
  (the same bytes as the file), `/cv.txt`, `/sitemap.xml` (the `Sitemap`
  response), `/robots.txt`.
- Fonts: committed `.woff2` under `static/fonts/` through `asset!`, not
  `fontsource_font!` with `host: Asset`, which downloads at bundle time. The
  licence file sits next to each font.
- Images: `asset!` for content-hashed URLs; portrait and project images
  optimised before commit (the repo, not the build, owns their size).
- `topcoat fmt --check`, `cargo clippy -D warnings`, `cargo test` in `just ci`.

Exit criterion: `topcoat dev` serves every surface with real content, all
route tests pass, and the crawl in Phase 5 produces a complete `dist/site/`.

### Phase 5: design passes and the mechanical gate

- `just crawl`: `wget --mirror --page-requisites` of `http://127.0.0.1:3000`
  into `dist/site/`. This is the static export, the impeccable live-mode
  fallback target, and the detector's input.
- `just design-check`: `impeccable detect http://127.0.0.1:3000/ .../cv ...`
  (rendered, Chrome) plus `impeccable detect styles.css dist/site/`
  (static). Wire it into `just ci` behind a Chrome-present guard so `ci` is
  still runnable on a machine without it, and say so in the output.
- The `.rs` experiment: `detector.extensions` with `{"ext": ".rs", "engine":
  "html"}` for one session. Keep it only if the findings are real; drop it and
  record why in `.impeccable/config.json`'s comment otherwise.
- Passes, in this order, each its own commit: `critique` (per surface),
  `audit`, `adapt` (the phone case from the users section), `harden` (long
  titles, missing images, empty sections when a list is short), `typeset`,
  `polish`. `bolder`/`quieter` only if critique asks for it. Every ignore goes
  through `impeccable hooks ignore-value` with a reason; never an inline
  waiver in `view!`.

Exit criterion: `just ci` green including `design-check`, and a
`.impeccable/critique/*.md` per surface committed.

### Phase 6: deploy to venari

Build on the laptop, ship a binary, as `just ghost-deploy` does:

```sh
cargo zigbuild --release --target x86_64-unknown-linux-musl
topcoat asset bundle   # then verify the bundle came from the linux binary
tar -C target -czf alyssa-rs.tgz x86_64-unknown-linux-musl/release/alyssa-rs assets/
scp alyssa-rs.tgz venari-root:/srv/alyssa-rs/build/
ssh venari-root 'cd /srv/alyssa-rs && docker compose build -q site && docker compose up -d'
```

Unverified until tried: that `topcoat asset bundle` scans a foreign-target
ELF on macOS (it scans the binary for embedded declarations; nothing in the
guide says the host must match), and that a musl static build of a
proc-macro-heavy Topcoat app goes through `cargo-zigbuild` cleanly. The
fallback is `docker buildx --platform linux/amd64` with a multi-stage
Dockerfile, slower under emulation but with no cross toolchain to keep.

On the box, `/srv/alyssa-rs/`:

- `site`: `alpine` + binary + `assets/`, `HOST=0.0.0.0 PORT=3000`, on an
  internal network only, no published ports, `mem_limit` sized after a first
  measurement (a Topcoat binary serving static content should sit well under
  the 128m Ghost's server gets; measure, do not assume).
- `caddy`: publishes `80` and `443`, `Caddyfile` with one site block for
  `alyssa.rs` and `www.alyssa.rs` reverse-proxying to `site:3000`, automatic
  TLS, a `caddy_data` volume for the certificates, access logs to stdout.
- Cloud firewall: open 80 and 443 to the world. This is the posture change.
  Mitigations: Caddy is the only process on those ports; the site container
  has no published ports and no volumes; `alyssa` stays out of the `docker`
  group; unattended upgrades are already on (`apt/52unattended-reboot`);
  Caddy's image is pinned by digest and bumped on purpose. Nothing stateful
  lives here, so the backup gap in the venari README does not grow: the repo
  is the source and `caddy_data` regenerates.
- DNS: `A`/`AAAA` for `alyssa.rs` and `www` to the box. The address is not in
  either repo, same rule as the ssh aliases. Where the zone is hosted is an
  open question below.

The compose file, `Caddyfile`, and a README section are twinned into
`tools/venari/alyssa-rs/` in dotfiles, and the `alyssa-rs-deploy` recipe goes
into `tools/just/personal.just`.

Exit criterion: `https://alyssa.rs/` serves from venari, `curl -sI` shows
Caddy's TLS and Topcoat's response, `just design-check` against the live URL
matches the local run, and a reboot of the box brings the site back without a
hand.

### Phase 7: later, and explicitly not now

- Contact form as a `#[procedure]` with `topcoat-mail` over SMTP; the auth
  check inside the procedure body, per the skill's "procedures are public
  endpoints" contract.
- PDF export of the CV from the pipeline (typst or a print stylesheet driven
  through headless Chrome; both are a pipeline step, neither touches Topcoat).
- Convex: no use in this plan. A CV site has no live data.
- Analytics: none. Caddy access logs on the box are enough to know the site is
  reached.

## Decisions that are yours

Each one feeds a specific phase; the plan proceeds on the default in bold if
you say nothing.

1. **Effect v4 rc (default) or v3** (Phase 2). Trade stated above.
2. **Caddy on venari with 80/443 opened (default), cloudflared, or a static
   host** (Phase 6). The default changes venari's posture; the others do not.
3. **Domain**: is `alyssa.rs` registered, and where is its zone hosted? Not
   checkable from here. Phase 6 is blocked on this and nothing else is.
4. **Content**: where the current CV text lives and which brag-doc entries are
   public enough for `/work`. Phase 3's evidence section needs the list, not
   the text.
5. **Fonts**: choosing them is new-work's job, but the constraint "self-hosted,
   permissive licence, committed to the repo" is set here; say if you want a
   commercial face, because that changes the licence handling.
6. **Chrome on the laptop** for the rendered detector (Phase 0). Yes/no.

## Unverified claims in this plan

- `topcoat-cli` availability in nixpkgs.
- `cargo-zigbuild` musl builds of a Topcoat app; `topcoat asset bundle` on a
  cross-compiled binary.
- Whether `view!` accepts an injected raw `<script>` (live mode), and whether
  the HTML analyzer produces signal on `.rs` files.
- Caddy's and the site's memory on the box; #173 measured Convex, nothing here.
- Everything about the domain.

Everything under "verified" was read from the pinned sources listed in the
frontmatter: the impeccable detector's extension list and its Chrome launcher,
the Topcoat 0.8.1 tailwind guide's `executable_env` and download behaviour,
the coffee-shop demo's crate layout, and the Effect rc.117 tarball's module
paths.

## Done means

- `just ci` green in the new repo, with `design-check` included on a machine
  that has Chrome.
- `https://alyssa.rs/`, `/cv`, `/cv.txt`, `/cv.json`, `/sitemap.xml` answer
  from venari and survive a reboot.
- `PRODUCT.md`, `DESIGN.md`, surface briefs, and a critique per surface are in
  the repo, each in the change that produced it.
- The dotfiles side carries the plugin, the venari twin, and the deploy recipe,
  and `CLAUDE.md` records whatever this build taught about running impeccable
  against a server-rendered Rust stack.
