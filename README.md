# FivePaths Claude Code plugins

The house plugin marketplace. One plugin so far, `fivepaths`, which carries
the `share` skill.

## Install

Claude Code only accepts marketplaces from github.com, gitlab.com,
bitbucket.org and configured GitHub Enterprise hosts, so `git.fivepaths.com`
cannot be added by URL. Clone it and add the clone as a directory, which the
marketplace supports natively:

```bash
git clone git@git.fivepaths.com:fivepaths/fivepaths-claude-plugins.git \
  ~/Code/src/fivepaths-claude-plugins
claude plugin marketplace add ~/Code/src/fivepaths-claude-plugins
claude plugin install fivepaths@fivepaths-plugins
```

Those last two also work as `/plugin marketplace add ...` and
`/plugin install ...` typed inside Claude Code. Use the `claude plugin` command
line in the desktop app, where `/plugin` is unavailable. Restart the session
afterwards so the skill loads.

To pick up a change later:

```bash
git -C ~/Code/src/fivepaths-claude-plugins pull
claude plugin marketplace update fivepaths-plugins
```

Then one setup step per machine, so the publisher can reach Cloudflare Access:

```bash
brew install cloudflared
cloudflared access login https://share.fivepaths.com/admin
```

That opens a browser once and caches a token. It needs a FivePaths staff
account: Access rejects any token whose email is not `@fivepaths.com`, and
service tokens do not work because they carry no email claim. On Linux,
install `cloudflared` from Cloudflare's package repository; the login is the
same.

## What is in it

### `share`

Say "share the Q3 findings with sam@acme.com". The skill writes the document
as a single self-contained HTML file in the
[cdn.fivepaths.com](https://cdn.fivepaths.com/microsite/v3/) design system,
checks it in a browser, publishes it to
[share.fivepaths.com](https://share.fivepaths.com), and grants the named
people access.

Nothing is emailed. Recipients get access and you send the link yourself,
which is the behaviour the skill is built around. Access is revoked from the
admin at `https://share.fivepaths.com/admin`.

The skill carries its own copies of the markup contract and the writing rules,
so no other repository has to be checked out.

Its publisher, `skills/share/scripts/fp-share.sh`, is a normal command-line
tool and works on its own:

```bash
fp-share.sh publish --title "Q3 findings" --file report.html --to "sam@acme.com"
fp-share.sh grant   --share <id> --to "another@acme.com"
fp-share.sh version --share <id> --file report.html --note "Second pass"
fp-share.sh list    --query findings
```

## Layout

```
.claude-plugin/marketplace.json     the marketplace, listing every plugin here
plugins/fivepaths/
  .claude-plugin/plugin.json        the plugin manifest and its version
  skills/share/
    SKILL.md                        the procedure Claude follows
    reference/markup.md             the v3 markup contract
    reference/voice.md              the writing rules
    assets/template.html            a correct empty document
    scripts/fp-share.sh             the publisher
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

Teammates pick up a change with a `git pull` and a marketplace update, as
under Install.

## House rules

Anything with the FivePaths name on it follows
[the writing rules](plugins/fivepaths/skills/share/reference/voice.md),
documentation here included. No em-dashes, plain words, no throat-clearing.
