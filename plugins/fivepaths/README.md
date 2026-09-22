# fivepaths

FivePaths house tooling for Claude Code.

| Skill | Invoke | Does |
|---|---|---|
| `document` | "write this up as a FivePaths document", or `/fivepaths:document` | Writes or converts content into one self-contained HTML file in the FivePaths design system |
| `share` | "share X with Y", "send X to Y", or `/fivepaths:share` | Publishes the document to share.fivepaths.com for named recipients through the Share API, emailing them from the user's address only when asked; follow-up (who is on it, add, remove, nudge) through the API or the `fivepaths-share` MCP server. Nothing needs the Share website |
| `project` | "get the project context", "what do we know about this client", or `/fivepaths:project` | Resolves the repository you are in to its client project through the support hub and clones the project's context repository to `~/.local/share/fivepaths/project/<slug>`; never writes to the site repository and refuses to run in CI |

Installation and per-machine setup are in the
[repository README](../../README.md). Each skill's own procedure is in
[`skills/document/SKILL.md`](skills/document/SKILL.md),
[`skills/share/SKILL.md`](skills/share/SKILL.md) and
[`skills/project/SKILL.md`](skills/project/SKILL.md). The Share API a token
may call and the MCP server's tools are documented in
[`skills/share/reference/api.md`](skills/share/reference/api.md).
