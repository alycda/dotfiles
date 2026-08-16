# Docs publish to HackMD, not Proof

When publishing, sharing, or handing off any document — a spec, plan, draft,
writeup, or review artifact — the destination is HackMD, via the `hackmd` MCP
server (`create_note` / `update_note`). Return the HackMD note URL as the
deliverable link.

The compound-engineering plugin defaults to Proof (Every's hosted service) for
this: its `ce-proof` skill publishes there, and its planning skills hand off
through it. That default is overridden here. `ce-proof` is hidden from the
model via `skillOverrides` in settings, so:

- If a skill or instruction says "publish to Proof" or "hand off via
  ce-proof", publish the same markdown to HackMD instead and say you did.
- `/ce-proof` remains user-invocable for **reading or commenting on Proof
  links other people share** — that is the only sanctioned use, and only when
  the user invokes it explicitly.

If the `hackmd` MCP server is unavailable (fresh sandbox, not yet
authenticated), say so and leave the document as a local markdown file. Do not
fall back to Proof or any other hosted service.
