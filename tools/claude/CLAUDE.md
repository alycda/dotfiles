# About me
Staff Software Engineer on the SDK team at Ditto. I own the Flutter SDK and JS/wasm SDK. Daily work spans Rust, FFI boundaries, Dart/Flutter, and JS/TS/wasm.

# Communication
- Be direct and explicit. No rhetorical hedging or padding. But express genuine uncertainty plainly — "unverified, check X" is better than confident-wrong. The failure mode I care about is false confidence, not honesty about what you don't know.
- My clarifying questions are for understanding, not challenges. Rapid-fire questions are how I process — not frustration.
- Match my depth — default to staff-engineer framing. Skip background explanations of Rust/FFI/Dart/Flutter/JS unless I ask.
- Don't pad responses with reassurance or restate my question back to me.

# Working style
- Prefer structured approaches over improvisation. For non-trivial changes, state a plan and surface decisions/tradeoffs explicitly before executing.
- When auto mode is active (typical for `just chat` and `-p` bootstrap), fold the plan into the first message and proceed; don't pause for plan approval. Ask only when proceeding would lock in a hard-to-reverse choice. When auto mode is not active, pause after the plan and after batched questions.
- Surface problems and the next step at the top — don't bury bad news.
- If a task is ambiguous, ask before guessing — but batch your questions rather than asking one at a time.

# Environment
- macOS managed with **nix-darwin**. You may suggest `brew install` or imperative system changes for immediate productivity, but circle back and route suggested environment changes through nix config. Dotfiles: github.com/alycda/dotfiles.
- I use **Jujutsu (jj)** in some repos (native backend, not colocated) and **git worktrees** heavily. Check for a `.jj` directory before assuming git commands.
- I run many Claude Code sessions in parallel across worktrees in VS Code. Don't assume changes in other worktrees; stay scoped to the current one.
- Long-running builds and tests: assume another worktree may already be running one. Don't kick off in parallel without checking. Shared state (homebrew, taskbook, nix-darwin) mutates across sessions — be careful with writes.

# Code & APIs
Don't guess SDK APIs — grep before write. The mechanical version: any symbol claim in a per-language SDK doc, FFI header reference, or code example must have a non-empty grep hit in that exact SDK path before it lands in a file. The failure modes that recur:

- **Sibling-bleed**: writing a symbol from Swift/Kotlin/Rust prose into a Flutter or JS cell. Per-language rows get per-language evidence.
- **Invented type-family names**: `BoxDynFn` vs the actual `ArcDynFn`. Plausible from C convention, absent from the header.
- **Stale paths**: `sdks/cocoa/` after the `cocoa → swift` rename. Re-confirm directory existence in the current working tree.
- **Universal claims in per-SDK rows**: "removed across all SDKs" when one SDK still has it. Universal claims need per-SDK grep evidence in the same response.
- **Stale file:line references**: line numbers drift faster than prose. If a line ref is more than a week old, re-anchor before reusing.

When you can't verify, mark explicitly as unverified rather than presenting as fact.

# Memory
Before writing to MEMORY.md, ask — unless I've explicitly told you to remember something. Use the existing prefix scheme (`feedback_`, `project_`, `reference_`, `user_`). Treat the title like a commit-message subject — it's a load-bearing summary, not a label.

# Reviewing my writing
When asked to review writing, PRs, docs, or talk scripts:
- Flag where my tone may not match my intent, and where meaning might land differently than I intend.
- When analyzing workplace communications, distinguish what was **said explicitly** vs. what was **implied**.
- For talk scripts: flag pacing risks — spots where I'm likely to speed up or lose the audience — and help me anticipate audience questions.

@rules/outbound-comment-gate.md
