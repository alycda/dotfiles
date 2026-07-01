# CLI Setup for Mode B (Cross-Provider Research)

Mode B of Step 1.5 dispatches the research brief to two sibling CLIs in addition to a Claude Agent worker:

- `codex` — OpenAI's coding CLI
- `gemini` — Google's Gemini CLI

This file documents the one-time install + auth so Mode B works on first run. The same CLIs are used by `sprint-planner`, `sprint-retrospective`, and `sprint-execute`, so if those skills work end-to-end already, you're done — Mode B will work too.

## Verify Current State

Before installing, check whether they're already on PATH:

```bash
command -v codex && codex --version
command -v gemini && gemini --version
```

If both print a version, skip to [Verified Non-Interactive Invocations](#verified-non-interactive-invocations) and confirm the worker-mode flags still work.

## Install

**codex** — see https://github.com/openai/codex for the current install instructions. On macOS the Homebrew route works:

```bash
brew install codex
```

**gemini** — see https://github.com/google-gemini/gemini-cli for current instructions. On macOS:

```bash
brew install gemini-cli
```

Both CLIs are also available via their respective official installers / npm packages — vendor docs are the source of truth, and these versions move quickly.

## Authenticate

**codex** logs in on first run (browser-based OpenAI account flow):

```bash
codex login
```

**gemini** uses either browser-based Google account auth or an API key:

```bash
gemini  # interactive login the first time
# OR
export GEMINI_API_KEY="your-key"
```

## Verified Non-Interactive Invocations

These flags are the only way to use the CLIs as workers (without per-tool-call approval prompts). They have been verified by `sprint-planner` and are reused here — do not second-guess them:

- **codex**: `codex exec --dangerously-bypass-approvals-and-sandbox "<prompt>"`
- **gemini**: `gemini -y -p "<prompt>"`
- **claude** (sibling, for reference): `claude -p --permission-mode acceptEdits "<prompt>"`

Smoke-test each:

```bash
codex exec --dangerously-bypass-approvals-and-sandbox "Print the string OK and exit."
gemini -y -p "Print the string OK and exit."
```

If both return promptly with `OK` (or similar), Mode B will work.

## Mode B Orchestration Shape

The researcher skill orchestrates the three workers in one parent turn — the Claude worker dispatched via the Agent tool, codex and gemini dispatched via parallel Bash calls:

```bash
# cwd must be the project root so worker file writes land correctly.
cd "$PROJECT_ROOT"

# Workers write to their own file via their file-write tools.
codex exec --dangerously-bypass-approvals-and-sandbox "$WORKER_PROMPT_CODEX" 2>&1 | tee logs/codex-worker.log &
gemini -y -p "$WORKER_PROMPT_GEMINI" 2>&1 | tee logs/gemini-worker.log &
# Claude worker is the Agent({...}) call placed in the same orchestrator turn.
wait
```

`$WORKER_PROMPT_CODEX` and `$WORKER_PROMPT_GEMINI` both contain the prompt template from `prompt-1.5-execute-research.md` §1.5.4, with `<NAME>` substituted to `codex` / `gemini` respectively.

## Troubleshooting

- **`codex: command not found` / `gemini: command not found`** — installer didn't update PATH. Restart your shell or add the install bin directory to PATH manually. On Homebrew macOS this is usually `/opt/homebrew/bin`.
- **Auth errors mid-run** — the worker stderr will surface the auth error. Re-auth and re-run the single failing worker; Mode B's orchestrator should preserve the two successful files.
- **Codex refuses certain topics** — this is provider-side policy, not a skill bug. Surface to the user.
- **Gemini rate limits** — Gemini's free tier has per-day quotas. Switch to API-key auth with a paid project if you hit them regularly.
- **Worker writes to wrong directory** — codex and gemini both write relative to their cwd. The parent orchestrator must `cd $PROJECT_ROOT` before spawning workers, or include an absolute path in the worker prompt.

## Why Sibling CLIs Instead of Direct API Calls?

The CLIs handle auth, sandboxing, model selection, browsing/grounding, and file I/O in their own runtime. Calling the underlying APIs directly would require re-implementing all of that. The CLI-via-Bash pattern is also what `sprint-planner`, `sprint-retrospective`, and `sprint-execute` use — keeping it consistent makes the toolchain easier to reason about and means any improvement to one of those skills (better error handling, retry logic, etc.) can be ported into this one with minimal effort.

## Reference

For the original (Hermes-based) profile setup this file replaces, see the ancestor skill at `~/.hermes/skills/research/researcher/references/hermes-profile-setup.md`. That version configures Hermes profiles instead of sibling CLIs; the design intent is identical — orchestrate workers across multiple providers — but the mechanism is different.
