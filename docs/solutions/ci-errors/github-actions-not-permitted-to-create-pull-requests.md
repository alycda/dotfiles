---
title: "The flake-update workflow validates the lockfile, then can't open its PR"
date: 2026-08-17
category: ci-errors
module: .github/workflows/update-flake-lock.yml
problem_type: config_error
component: tooling
severity: medium
symptoms:
  - "'Update flake.lock' workflow run fails at the 'Create pull request' step with '##[error]GitHub Actions is not permitted to create or approve pull requests. - https://docs.github.com/rest/pulls/pulls#create-a-pull-request'"
  - "Every earlier step is green: nix flake update, nix flake check --all-systems, eval-configurations.sh, and the branch push all succeed"
  - "The automation/flake-update branch exists on the remote and carries the updated flake.lock, but no PR is listed for it"
  - "Re-dispatching the workflow reproduces the failure identically — it is not transient"
root_cause: config_error
resolution_type: config_change
related_components:
  - development_workflow
  - documentation
tags:
  - github-actions
  - ci
  - flake-update
  - permissions
  - create-pull-request
  - workflow-dispatch
---

# The flake-update workflow validates the lockfile, then can't open its PR

## Problem

`update-flake-lock.yml` exists so a lockfile bump can be kicked off from
anywhere — including the GitHub mobile app — and arrive as an already-validated
PR. Its first real dispatch (run 32057380951, 2026-08-17) did every expensive
part of that correctly and then failed on the last inch:

```
##[group]Pushing pull request branch to 'origin/automation/flake-update'
[command]/usr/bin/git push --force-with-lease origin automation/flake-update:refs/heads/automation/flake-update
 * [new branch]      automation/flake-update -> automation/flake-update
##[endgroup]
##[group]Create or update the pull request
Attempting creation of pull request
##[error]GitHub Actions is not permitted to create or approve pull requests.
```

`nix flake update`, `nix flake check --all-systems`,
`.github/scripts/eval-configurations.sh`, `nix flake show`, the commit, and the
branch push had all already succeeded. Only the PR-creation API call was
refused.

## Root cause

Not a bug in the workflow, a token scope, or `peter-evans/create-pull-request`.
It is a repository setting: **Settings → Actions → General → Workflow
permissions → "Allow GitHub Actions to create and approve pull requests"**, and
it was off.

When that box is unticked, `POST /repos/{owner}/{repo}/pulls` is rejected for
*any* caller authenticating as `GITHUB_TOKEN`, regardless of the
`permissions: pull-requests: write` block in the workflow file. The workflow's
`permissions:` key can only ever narrow what the token may do; it cannot
re-grant something the repo setting has withdrawn. `gh pr create` fails the
same way for the same reason — swapping the action for the CLI is not a fix.

The setting exists at two levels, and the account level wins. If the per-repo
checkbox is greyed out, the corresponding switch is off under the account's own
Settings → Actions → General, and it must be enabled there first.

This was a *known* precondition — the workflow header already named the setting
when it was written (PR #105) — but it had never been exercised, so the very
first dispatch spent ~2 minutes of nix evaluation before hitting it.

## Solution

**1. Tick the box.** [Settings → Actions →
General](https://github.com/alycda/dotfiles/settings/actions) → Workflow
permissions → *Allow GitHub Actions to create and approve pull requests*. This
is the actual fix and only a repo admin can do it — it is not reachable from
inside the workflow or from any agent session.

**2. Make the failure cheap and recoverable** (this repo's change). Three edits
to `update-flake-lock.yml`:

- `continue-on-error: true` on the `Create pull request` step. By the time this
  step can fail, the validated lockfile is *already pushed*. Aborting the job
  there discards the CI dispatch and leaves a mystery branch behind.
- The `Run CI checks on the update branch` step now triggers on a failed PR
  step too, guarded by `git ls-remote --exit-code --heads origin
  automation/flake-update`. The guard distinguishes "PR call failed but branch
  landed" (dispatch `nix.yml`, the branch deserves checks) from "failed before
  the push" (nothing to check). Its previous condition,
  `pull-request-operation != ''`, specifically skipped the failure case.
- A final `Verify the update PR is open` step asserts the invariant *"an update
  was produced and pushed, therefore an open PR exists for it"* via `gh pr list
  --head automation/flake-update --state open`. When none exists it writes the
  fix and a `compare/main...automation/flake-update?expand=1` link into
  `$GITHUB_STEP_SUMMARY`, then `exit 1` so the run is still honestly red.

Net effect: the run still fails, but it fails *saying what to click*, and the
validated update is one tap away from a PR instead of being thrown out.

## Why the check queries GitHub instead of reading `steps.pr`

The obvious version of that last step is `if: steps.pr.outcome == 'failure'`.
It is not enough, because a *second* path reaches "branch pushed, no PR" — and
this failure creates it.

`automation/flake-update` is now sitting on the remote carrying the validated
lockfile. Re-dispatch without fixing the setting and `create-pull-request`
finds the branch already identical to what it would push, reports
`pull-request-operation: none`, and **skips PR creation entirely** — it never
retries, so it never fails, so an `outcome == 'failure'` guard never fires. The
run goes green with no PR to review. The first failure would have quietly
disarmed the detector for every run after it.

Asking GitHub whether the PR exists is invariant-shaped rather than
mechanism-shaped, so it holds for both paths and for any future one. Two
adjacent traps if you do reach for step state:

- `outcome` vs `conclusion`. `continue-on-error` is exactly what makes these
  diverge: `outcome` is the raw result (`failure`), `conclusion` is that result
  *after* `continue-on-error` is applied (`success`). `conclusion` is the value
  that no longer records the failure.
- An empty `steps.pr.outputs.*` is not the same as `'none'`. A failed step
  produces empty outputs, so the old `pull-request-operation != ''` guard on
  the CI-dispatch step read failure as "nothing to do" and skipped the checks.

## Prevention

1. **A workflow precondition that lives only in a comment is not configured.**
   The header documented this setting from day one and it still fired on the
   first dispatch. If a step depends on repo state no other step can establish,
   either verify it early or make its failure self-describing — a comment
   nobody reads until the run is already red buys nothing.

2. **Order steps so cheap failures precede expensive ones.** This job burned
   the full `nix flake check --all-systems` + config-eval runtime before
   reaching the step that was always going to fail. A genuine preflight is not
   possible here (reading `GET /repos/{owner}/{repo}/actions/permissions/workflow`
   needs admin scope, which `GITHUB_TOKEN` never has), which is exactly why the
   graceful-degradation path above is the substitute.

3. **`permissions:` in a workflow only narrows.** `pull-requests: write` looks
   like a grant and reads like one. It is a ceiling, and repo/org settings sit
   above it. When an Actions permission error contradicts the `permissions:`
   block, look outside the file.

4. **Distinguish "the work failed" from "the last step failed".** Anything that
   pushes a branch, uploads an artifact, or otherwise produces a durable result
   before its final publish step should say so on failure. Half-completed work
   that announces itself is resumable; half-completed work that dies silently
   gets redone from scratch.

5. **Assert the invariant, not the mechanism.** "Did the step that creates the
   PR fail?" and "is there a PR?" look interchangeable until the durable side
   effect of one failure makes the next run skip that step altogether. Check
   for the outcome you actually require — especially in an idempotent workflow,
   where leftover state from a failed run changes what the next run even
   attempts.

## Related

- PR #105 — added the workflow; header already listed this setting as a
  requirement.
- `CLAUDE.md` § "Flake input updates: `update-flake-lock.yml`" — the same
  requirement, and the `GITHUB_TOKEN` anti-recursion rule that shapes the rest
  of the workflow.
- The anti-recursion rule (GITHUB_TOKEN-created PRs don't fire `pull_request`
  workflows) is a *different* GITHUB_TOKEN restriction than this one, and both
  apply to this workflow. Don't conflate them: that one is worked around inside
  the workflow via `workflow_dispatch`; this one cannot be.
