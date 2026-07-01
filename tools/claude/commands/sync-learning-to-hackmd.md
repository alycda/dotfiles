---
description: Mirror a docs/solutions learning to HackMD (create-or-update via the sidecar map)
argument-hint: <path-to-docs/solutions/*.md> [--public | --signed-in | --owner]
allowed-tools: Read, Write, Bash, ToolSearch, mcp__hackmd__create_note, mcp__hackmd__update_note, mcp__hackmd__get_note
---

# sync-learning-to-hackmd

Mirror one `docs/solutions/` learning to HackMD so it's reachable outside the
git tree (sibling folders like `experiments/`, or shared with teammates). The
markdown file stays canonical; HackMD is a **read-mostly mirror**. Re-running on
the same doc **updates the existing note in place** — it never creates a
duplicate — because the doc→note mapping is persisted in a sidecar map.

`$ARGUMENTS` = the path to a `docs/solutions/**/*.md` file (absolute or
relative), optionally followed by a read-permission flag (`--public` →
`guest`, `--signed-in` → `signed_in` (default), `--owner` → `owner`).

## Procedure

1. **Resolve the doc and the knowledge-store root.**
   - Take the first argument as the doc path; resolve it to an absolute path and confirm it exists and ends in `.md`. If it doesn't exist, stop and say so.
   - Find the knowledge-store root: walk up from the doc's directory to the nearest ancestor named `docs/solutions`. If none is found, default to `/Users/alyssaevans/Work/ditto-worktree/docs/solutions`.
   - Compute `REL` = the doc's path relative to that root (e.g. `tooling-decisions/foo-2026-06-24.md`). This is the map key.
   - Parse the optional permission flag; default `readPermission` is `signed_in`.

2. **Read the sidecar map** at `<root>/.hackmd-map.json`. If it doesn't exist, treat it as `{ "notes": {} }` (you'll create it on write). Look up `notes[REL]`.

3. **Build the note payload.**
   - `title` = the doc's first H1 (`# ...`), falling back to the filename stem.
   - `content` = a one-line mirror banner followed by the **verbatim** file content:

     ```
     > **Mirror for sharing / cross-folder reference.** Canonical copy lives in the knowledge store at `docs/solutions/<REL>`. Synced <YYYY-MM-DD> — edit the canonical copy and re-run /sync-learning-to-hackmd; treat this as read-mostly.

     ---

     <full file content>
     ```

     Use today's date (run `date +%F`). Do not edit the doc body; only prepend the banner.

4. **Create or update.**
   - **If `notes[REL]` exists** (has a `noteId`): load the tool with `ToolSearch` query `select:mcp__hackmd__update_note`, then call it with that `noteId`, the new `content`, and the `readPermission`. This is the in-place update.
   - **If not**: call `mcp__hackmd__create_note` with `title`, `content`, `readPermission`, `writePermission: owner`, `commentPermission: signed_in_users`. Capture the returned `id`, `shortId`, and `publishLink`.

5. **Write the map back.** Set `notes[REL]` to `{ noteId, shortId, publishLink, readPermission, lastSynced: <today> }` and write `<root>/.hackmd-map.json` (pretty-printed, preserving the `_note` key and other entries). On update, refresh `lastSynced` and `readPermission`; keep the existing ids.

6. **Report** the publish link, whether it was a create or an update, and the read permission.

## Notes

- Only mirror learnings that are genuinely worth sharing or cross-folder reuse — this is opt-in per doc, not an auto-push for every `/ce-compound` output.
- Publishing to HackMD puts the content on an external service. Default `signed_in` keeps it to authenticated HackMD users; pass `--public` only when a world-readable link is intended.
- The HackMD note id is stored in the sidecar map, **not** in the doc's frontmatter, so the ce-compound schema stays clean and the mapping survives doc renames (just update the key).
