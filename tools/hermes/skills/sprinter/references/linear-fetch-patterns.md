# Linear MCP Fetch Patterns

How sprinter queries Linear via the user's installed MCP server(s). Multiple-workspace handling, dependency-graph traversal, and rate-limit-aware patterns.

## Detecting available Linear MCPs

Run `hermes mcp list` (or check the agent's available tool inventory). Look for tool names matching `*_get_issue`, `*_list_issues`, etc. — the Linear MCP exposes these as `mcp__<server-id>__get_issue` style names.

If multiple Linear servers are present, each is typically configured against a different Linear workspace. The user might have:

- A primary work workspace (e.g., `linear.app/yourcompany`)
- A secondary or personal workspace

Either can be the right target for a given URL. Routing logic:

1. **URL-based routing** — Linear URLs follow the pattern `https://linear.app/<workspace-slug>/issue/<ID>`. Extract the workspace slug. If a configured MCP's workspace name matches, use that one.
2. **Probe both** — call `get_issue(id=ID)` on each configured Linear MCP. Use the one that returns successfully. Cache the result for the session.
3. **User override** — if `--linear-server <name>` is passed, use that explicitly.

## Fetching a parent ticket and its subissues

Single MCP call gets the parent:

```
get_issue(id="PROJ-3481")
```

Returns: `{id, title, description, estimate, labels, state, parentId, ...}`.

For subissues, the Linear MCP usually exposes either:
- `list_issues(parent_id="PROJ-3481")` — preferred, single call
- Or you traverse via the parent's `children` field if present in the get_issue response

If neither works, fall back to:
```
list_issues(filter={"parent": {"id": {"eq": "<parent-id>"}}})
```

## Fetching dependency graph

Linear issues have `relations` (or sometimes `relationships`) that include `blocks`, `blockedBy`, `relatesTo`, `duplicateOf`. Fetch via:

```
get_issue(id="PROJ-3482")  # returns issue with relations
# or
list_issues(filter={"id": {"in": [...]}}, include=["relations"])
```

The exact field name and traversal depend on the MCP's schema. Check the tool's parameter list at runtime — the MCP self-describes via JSON Schema.

## Handling estimates

Linear's `estimate` field is numeric (story points, typically Fibonacci-ish 1/2/3/5/8). Some workspaces use a different scale or skip estimates entirely. Sprinter treats:

- `estimate: null` or missing → unestimated, ask user
- `estimate: 0` → likely a placeholder, treat as unestimated
- `estimate: 1, 2` → small (batch candidate)
- `estimate: 3, 5, 8, 13...` → standalone sprint

## Handling labels for SDK target detection

Linear labels are typed objects, often with names like `area:flutter`, `area:jvm`, `sdk-flutter`, etc. The set of labels per workspace varies. Sprinter pattern-matches against common conventions (see `decomposition-heuristic.md` "SDK target detection") rather than hardcoding any specific label scheme.

If detection fails for a critical subissue, the manifest review step is the user's chance to correct. Don't try to be clever — defer to user judgement.

## Rate limit awareness

Fetching one parent + N subissues + their relations is roughly `1 + N + N` calls (worst case, one per subissue for relation expansion). For a parent with 10 subissues, that's ~21 API calls.

Linear's API rate limit is generous (~1500 req/hr authenticated), but sprinter should still:

- Batch list_issues calls when possible (`filter={"id": {"in": [...]}}`)
- Cache fetched issues for the session — re-querying the same issue ID twice is waste
- Surface the count to the user before fetching: "About to fetch 1 parent + 10 subissues from Linear. Proceed?" — gives the user a chance to abort if the parent is unexpectedly large

## Idempotency on re-fetch

If the user re-runs sprinter on the same parent ticket later (e.g., after subissues changed), the manifest might differ. Sprinter writes the manifest with a timestamp suffix in the filename so old manifests aren't overwritten. The user can diff manifests to see what changed.

## Failure modes

| Failure | Behavior |
|---|---|
| Linear MCP not configured | Refuse with: "No Linear MCP found. Configure via `hermes mcp add` first." |
| Parent ID not found in any MCP | "Ticket {id} not found in any configured Linear workspace. Check the URL or specify --linear-server." |
| Parent has no subissues, no description, no acceptance criteria | Surface to user: this is too vague to decompose; either add detail in Linear first or run sprint-planner directly with the user supplying intent. |
| Subissue has no estimate AND user didn't pass `--auto-skip-unestimated` | Inline `AskUserQuestion`: estimate, skip, or abort. |
| Cross-tree blocked-by (subissue blocked by something outside parent's subtree) | Warn user: this dependency cannot be honored as a kanban link. Surface as informational; user decides whether to proceed. |

## Worked example

Input: `https://linear.app/example/issue/PROJ-3481`

```
1. Detect MCPs: ["mcp__abc__", "mcp__xyz__"] — both Linear, different workspaces
2. URL slug "ditto" matches mcp__abc's workspace → route to abc
3. get_issue(id="PROJ-3481") via mcp__abc → parent: 
     {title: "User exceptions in callbacks crash as Ditto SIGABRT", 
      estimate: null, labels: ["area:ffi"], children: [PROJ-3482..3489]}
4. list_issues(parent="PROJ-3481") → 8 subissues
5. For each subissue, fetch with relations
6. Apply decomposition heuristic:
   - PROJ-3488 (estimate 3, "Rust audit") → standalone
   - PROJ-3489 (estimate 3, "C++ audit") → standalone
   - PROJ-3482..3487 (each estimate 2, per-SDK) → batch into one sprint
   - Discovered blocking edge: 3482..3487 each blockedBy 3488 (Rust audit must finish first)
7. Manifest:
     sprint-1: kitchen-sink-ffi-callback-contract  (3488 + 3489)
     sprint-2: per-sdk-callback-tests              (3482..3487)
       blocked_by: [sprint-1]
8. Show manifest to user → approve → create kanban tasks
```

That's the realistic shape for a typical SDK-team ticket family.
