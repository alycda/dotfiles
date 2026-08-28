# Outbound message gate

Before any tool call that posts a comment, review, status update, PR/issue body, or
otherwise user-visible message on ANY external surface, show me the rendered body and
the destination (PR/issue/thread/channel/recipient), then wait for my explicit approval
before sending.

This rule is destination-scoped, not tool-scoped, and platform-agnostic. It covers at
minimum:

- GitHub via any path: `gh pr comment`, `gh pr review`, `gh issue comment`,
  `gh pr create`, `gh api … -X POST` / `-X PATCH` against any `/comments`, `/replies`,
  `/reviews`, or `/issues/.../comments` endpoint
- Linear via MCP: any `save_comment`, `save_status_update`, `save_customer_need`, or
  other tool whose effect creates or edits a visible message
- Slack via MCP or any other path: `slack_send_message` and equivalents
- Email, and any future surface (new MCP server, web tool, etc.) that posts
  user-visible messages anywhere

How to apply:

- An explicit instruction like "ping X" or "reply to Y" authorizes the **act**, not the
  unseen **content** — still show the body first.
- For a batch of replies, show all bodies upfront — one approval covers the batch.
- Replies to my own bot account don't qualify; this is about messages visible to others.
- The rule applies even when permission settings would auto-allow the specific tool —
  the destination matters, not the path taken to get there.
