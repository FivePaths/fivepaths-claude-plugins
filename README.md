# FivePaths Claude Code plugins

The house plugin marketplace. One plugin so far, `fivepaths`, which carries
the `document` and `share` skills: write a FivePaths-branded document, put it
on share.fivepaths.com for named people, and, when asked, email them.

## Install

The marketplace is the private GitHub repository
`FivePaths/fivepaths-claude-plugins`, mirrored from `git.fivepaths.com`.
Claude Code fetches marketplaces from GitHub with your own git credentials, so
you need to be a member of the FivePaths GitHub organisation and signed in to
GitHub on the machine (`gh auth login`, or an SSH key). Then:

```bash
claude plugin marketplace add FivePaths/fivepaths-claude-plugins
claude plugin install fivepaths@fivepaths-plugins
```

Those also work as `/plugin marketplace add ...` and `/plugin install ...`
typed inside Claude Code in a terminal. In the desktop app use its plugin
browser, or the `claude plugin` command line. Restart the session afterwards
so the skills load.

Updates come with `claude plugin marketplace update fivepaths-plugins`, or on
their own once auto-update is on for the marketplace (the *Marketplaces* tab
of `/plugin`, or `"autoUpdate": true` in the settings below).

If you installed an earlier version from a clone, remove that first so the two
registrations do not collide:

```bash
claude plugin marketplace remove fivepaths-plugins
```

### If adding it fails

- **"its network source differs from the one declared for it in settings".**
  The marketplace is already declared as `fivepaths-plugins` in a settings
  file (yours, a project's, or managed settings) with the `github` form, and
  you tried to add it again by a different form, such as pasting the full
  `https://github.com/...` URL into the desktop app's plugin browser. There is
  nothing to add: the marketplace is registered, so install the plugin
  directly with `claude plugin install fivepaths@fivepaths-plugins`, or pick
  it from the list the browser already shows. If you do add it by hand, use
  the same `FivePaths/fivepaths-claude-plugins` shorthand everywhere.
- **A username prompt, "Repository not found", or "Permission denied".** The
  repository is private and Claude Code fetches it with git, using whatever
  credentials git has on that machine. Sign in with `gh auth login` and run
  `gh auth setup-git`, or add an SSH key to your GitHub account, and make sure
  the account is a member of the FivePaths organisation. The desktop app runs
  the same git, so the same credentials serve it.

### Rolling it out to everyone

Two ways, which combine.

**Managed settings** put the marketplace and the plugin on every machine the
file reaches, with no per-person steps. Install
[`managed-settings.example.json`](managed-settings.example.json) as:

| Platform | Path |
|---|---|
| macOS | `/Library/Application Support/ClaudeCode/managed-settings.json` |
| Linux | `/etc/claude-code/managed-settings.json` |
| Windows | `C:\Program Files\ClaudeCode\managed-settings.json` |

It registers the marketplace with auto-update on and enables the plugin.
Managed settings apply to the terminal and the desktop app alike. Writing that
file needs administrator rights, so this is the route for machines under
device management; on a personal laptop the same JSON can go in
`~/.claude/settings.json` instead.

**A project's `.claude/settings.json`** registers the marketplace and enables
the plugin for anyone who opens that project, which is the right place for
client repositories where documents get sent from. Paste the same two keys:

```json
{
  "extraKnownMarketplaces": {
    "fivepaths-plugins": {
      "source": { "source": "github", "repo": "FivePaths/fivepaths-claude-plugins" },
      "autoUpdate": true
    }
  },
  "enabledPlugins": { "fivepaths@fivepaths-plugins": true }
}
```

Either way each person still authorises their own computer once, because the
token has to be theirs:

### Authorise the computer

```bash
~/.claude/plugins/marketplaces/fivepaths-plugins/plugins/fivepaths/skills/share/scripts/fp-share.sh login
```

(Or ask Claude to run `fp-share.sh login`; the skill knows where it lives.)
It prints and opens a link at share.fivepaths.com. Sign in as yourself if
asked, check that the computer named on the page is the one you are sitting
at, and choose *Approve*. The script collects a personal token and keeps it
in `~/.config/fivepaths/share/token`. Nothing else is installed: no
`cloudflared`, no Cloudflare account on the machine, only `curl` and `jq`.

The token lasts 90 days and can only publish and notify; it cannot revoke or
delete a share. Every token you hold is listed under your name in the admin
at `https://share.fivepaths.com/admin/tokens`, where it can be revoked, and
`fp-share.sh logout` revokes the one on this computer.

## What is in it

### `document`

Say "turn this into a FivePaths document" or "write up the findings as a
branded page". The skill writes one self-contained HTML file in the
[cdn.fivepaths.com](https://cdn.fivepaths.com/microsite/v3/) design system,
from a Markdown, Word or PDF file, from work in the conversation, or from a
topic, and checks it in a browser. It carries its own copies of the markup
contract and the writing rules, so no other repository has to be checked out.
It publishes nothing.

### `share`

Say "share the Q3 findings with sam@acme.com" or "send this report to Jun".
The skill gets the document (running `document` first if what it has is not
already a branded HTML file), resolves the people, publishes to
[share.fivepaths.com](https://share.fivepaths.com), and grants them access.

Two verbs. *Share* grants access and emails nobody; you send the link
yourself. *Send* grants access and then emails each recipient from your own
address, with a message the skill drafts in your voice and shows you first.
No email leaves without your yes.

A first name becomes an address in this order: a `CONTACTS.md` file at the
project root (one line per person, `- Jun Park <jun@acme.com>, product lead
at Acme`), then the portal's own record of who we have shared with
(`fp-share.sh people --query jun`), then you. The skill never builds an
address out of a name and a domain.

Its publisher, `skills/share/scripts/fp-share.sh`, is a normal command-line
tool and works on its own:

```bash
fp-share.sh login
fp-share.sh publish --title "Q3 findings" --file report.html --to "sam@acme.com"
fp-share.sh publish --title "Q3 findings" --file report.html --to "sam@acme.com" --notify --message "Here it is." --cc "pm@fivepaths.com"
fp-share.sh grant   --share <id> --to "another@acme.com"
fp-share.sh version --share <id> --file report.html --note "Second pass"
fp-share.sh notify  --share <id> --message "The fares section changed."
fp-share.sh people  --query jun
fp-share.sh list    --query findings
fp-share.sh whoami
fp-share.sh logout
```

`FP_SHARE_BASE` points it at another deployment, such as a local `wrangler dev`
server, and `FP_SHARE_TOKEN` supplies a token without the file.

## Layout

```
.claude-plugin/marketplace.json     the marketplace, listing every plugin here
managed-settings.example.json       what an administrator installs to roll the plugin out
plugins/fivepaths/
  .claude-plugin/plugin.json        the plugin manifest and its version
  skills/document/
    SKILL.md                        how a document is written and checked
    reference/markup.md             the v3 markup contract
    reference/voice.md              the writing rules
    assets/template.html            a correct empty document
  skills/share/
    SKILL.md                        share or send: resolve, confirm, publish, report
    scripts/fp-share.sh             login, publishing, granting, versioning, notifying, people
```

## Adding a skill

Put it in `plugins/fivepaths/skills/<name>/SKILL.md` and raise the `version` in
both manifests. The description in the frontmatter is what decides whether
Claude reaches for the skill, so write it as the sentences a person would
actually say, not as a summary of the implementation.

Validate before committing, which catches a malformed manifest that would
otherwise fail silently at install time:

```bash
claude plugin validate .
claude plugin validate plugins/fivepaths
```

Push to `main` on GitHub; teammates pick the change up at the next
auto-update or with `claude plugin marketplace update fivepaths-plugins`.
Push to `git.fivepaths.com` as well, which stays the repository of record.

## House rules

Anything with the FivePaths name on it follows
[the writing rules](plugins/fivepaths/skills/document/reference/voice.md),
documentation here included. No em-dashes, plain words, no throat-clearing.
