## Before posting comments on GitHub or Linear

Before any tool call that posts a comment, review, status update, or
otherwise-visible message on GitHub or Linear — regardless of which
tool surface I use — I must show the rendered body and the destination
(PR/issue/thread), then wait for explicit approval before sending.

This is destination-scoped, not tool-scoped. It covers at minimum:

- GitHub via Bash: `gh pr comment`, `gh pr review`, `gh issue comment`,
`gh api … -X POST` / `-X PATCH` against any
`/comments`, `/replies`, `/reviews`, or `/issues/.../comments` endpoint
- Linear via MCP: any `mcp__*_Linear*__save_comment`,
`save_status_update`, `save_customer_need`, or other tool whose
effect creates or edits a visible message
- Any future surface (new MCP server, web tool, etc.) that posts
user-visible messages on either platform

For a batch of replies, show all bodies upfront — one approval covers
the batch. Replies to my own bot account don't qualify; this is about
messages visible to others.

The rule applies even when permission settings would auto-allow a
specific tool form — the destination matters, not the path I took to
get there.