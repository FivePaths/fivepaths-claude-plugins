# FivePaths Claude Code plugins

The house plugin marketplace. One plugin so far, `fivepaths`, which carries
the `share` skill.

## Install

```bash
/plugin marketplace add git@git.fivepaths.com:fivepaths/fivepaths-claude-plugins.git
/plugin install fivepaths@fivepaths-plugins
```

Both are typed in Claude Code, not a terminal. To work on the plugin locally,
point the marketplace at a clone instead:

```bash
/plugin marketplace add ~/Code/src/fivepaths-claude-plugins
```

Then one setup step per machine, in a terminal, so the publisher can reach
Cloudflare Access:

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

Teammates pick up a change with `/plugin marketplace update fivepaths-plugins`.

## House rules

Anything with the FivePaths name on it follows
[the writing rules](plugins/fivepaths/skills/share/reference/voice.md),
documentation here included. No em-dashes, plain words, no throat-clearing.
