# fivepaths

FivePaths house tooling for Claude Code.

| Skill | Invoke | Does |
|---|---|---|
| `share` | "share X with Y", or `/fivepaths:share` | Writes a document in the FivePaths design system, publishes it to share.fivepaths.com, and grants the named recipients access without emailing them |
| `project` | "get the project context", "what do we know about this client", or `/fivepaths:project` | Resolves the repository you are in to its client project through the support hub and clones the project's context repository to `~/.local/share/fivepaths/project/<slug>`; never writes to the site repository and refuses to run in CI |

Installation and per-machine setup are in the
[repository README](../../README.md). The skill's own procedure is in
[`skills/share/SKILL.md`](skills/share/SKILL.md) and
[`skills/project/SKILL.md`](skills/project/SKILL.md).
