# Step 2 — Render and Iterate

Produces `docs/c4/dashboard/` from `docs/c4/model.c4` and iterates with the user until they accept the model.

## Procedure

### 2.1 — Initial Build

```bash
bash ~/.claude/skills/c4-design/scripts/build-dashboard.sh "$PROJECT_ROOT"
```

The script:

1. Validates `docs/c4/model.c4` via `npx @likec4/cli validate`
2. Builds the static dashboard via `npx @likec4/cli build`
3. Outputs to `docs/c4/dashboard/`

If validation fails, surface the error to the user verbatim. Don't try to auto-fix DSL errors — the user needs to see the syntax issue.

### 2.2 — Surface to User

Tell the user:

> *"Dashboard built at `docs/c4/dashboard/index.html`. Open it (macOS: `open docs/c4/dashboard/index.html`; any OS: `python3 -m http.server -d docs/c4/dashboard 8000` then visit http://localhost:8000). Walk through each view (Context, Container, Components). Reply with: (a) `accept` if the model captures the design correctly, (b) specific edits if something is wrong, or (c) `add view <name>` to request a new view."*

### 2.3 — Iterate

For each round of feedback:

- **Edit:** make the requested change to `docs/c4/model.c4` only. Do not edit the built dashboard files — they will be overwritten on rebuild.
- **Rebuild:** rerun `scripts/build-dashboard.sh`.
- **Verify:** confirm the dashboard reflects the change. (If not, the DSL change probably didn't land where intended — re-read `model.c4` and double-check.)
- **Re-surface:** tell the user the change is live; ask for the next round of feedback or final acceptance.

Common iteration patterns:

| User says | DSL action |
|---|---|
| "The web app should also talk to the analytics service" | Add `web -> analytics 'Sends events'` |
| "Move the auth handler from API into its own container" | Promote `api.auth_handler` (component) to `auth` (container); add edges from web/mobile to auth, from auth to API |
| "Show me a view focused on the sync pipeline" | Add a new `view sync of <container>` block; rebuild |
| "The user persona is wrong" | Rename the actor's display string in the model; rebuild |
| "Add Stripe as an external dependency of the API" | Add `stripe = externalSystem 'Stripe'`; add `api -> stripe 'Charges, refunds'` |

### 2.4 — Acceptance

When the user replies `accept`:

- Confirm `docs/c4/model.c4` is the latest version that produced the accepted dashboard
- Confirm `docs/c4/dashboard/` exists and is non-empty
- (Optional) If the project uses git, suggest committing `docs/c4/model.c4` but adding `docs/c4/dashboard/` to `.gitignore` — the dashboard is a build artifact, not a source asset

## Output

- `docs/c4/dashboard/index.html` + supporting files (built by Likec4)
- `docs/c4/model.c4` (updated through the iteration)

## Verification

- `dashboard/index.html` opens and renders without console errors
- Each view defined in `model.c4` appears in the dashboard's sidebar/menu
- Every interview-output element (actors, containers, components, edges) is visible somewhere in the dashboard
- The user has replied `accept`

## Pitfalls

- **Editing the dashboard directly.** The dashboard is generated. Any edits will be wiped on the next `build-dashboard.sh` run. Always edit `model.c4`.
- **Skipping validation on each rebuild.** The build script validates first, but in a tight iteration loop it's tempting to skip. Don't — Likec4 silently produces a broken dashboard when the DSL has certain kinds of errors.
- **Letting the iteration drift into implementation specifics.** Pre-code C4 should answer "what does the system look like?", not "how does the auth handler hash passwords?". If feedback keeps drifting toward function-level detail, surface that and remind the user the model is structural, not algorithmic.
- **Over-iterating.** Three or four rounds is normal. Ten rounds usually means the upstream plan was thin and the user is using the C4 iteration to do design work that should have happened in `ce-plan`. Suggest stepping back to the plan if iteration drags.
- **`npx` cold-start latency.** First `npx @likec4/cli` invocation downloads the package; can take 30+ seconds. Subsequent runs are fast. Tell the user once if the first build feels slow.
