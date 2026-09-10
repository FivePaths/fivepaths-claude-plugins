---
name: share
description: Write a FivePaths-branded HTML document and publish it to share.fivepaths.com with access for named recipients, without emailing anyone. Use when asked to "share X with Y", to send a report, summary, brief, findings, proposal or write-up to a client or colleague, or to put a document on share.fivepaths.com. Builds the page to the cdn.fivepaths.com microsite v3 markup contract and the FivePaths writing rules.
---

# Share a document with someone

"Share X with Y" means: write X as a single self-contained HTML document in
the FivePaths design system, publish it to share.fivepaths.com, and grant Y
access. **No email is sent.** The recipient gets access; you hand the link to
whoever asked, and they pass it on.

Everything this skill needs is bundled with it. `$SKILL` below is
`${CLAUDE_PLUGIN_ROOT}/skills/share`.

## Resolve the request first

**X** is the content. It may be a topic to write up, a file to convert, or
work already in this conversation. If X does not exist yet, write it.

**Y** is one or more recipients, and it must resolve to email addresses:

- An exact address: `sam@acme.com`
- A domain wildcard: `*@acme.com`, which admits **anyone** at that domain

Ask before guessing. A company name ("share it with Acme") is not an address.
Never invent one from a person's name, and never turn a company name into a
wildcard on your own: say what you would grant and let the user confirm.

Stop and ask if the recipients are unresolved. Everything else has a sensible
default: derive the title from the document, and name the file after it.

## Write the document

Read `$SKILL/reference/markup.md` and `$SKILL/reference/voice.md` before
writing. Start from `$SKILL/assets/template.html`, a working skeleton with the
head, the skip link, the header and its theme toggle, and the footer already
correct. Copy it into the working directory; never edit the bundled copy.

It must be **one self-contained HTML file**. A share holding a single HTML
file renders in the browser; add a second file and the reader gets a list of
downloads instead. So inline the page-local CSS, reference images as absolute
`https://` URLs or `data:` URIs, and keep the whole file under 25 MB.

Two things the design system gives you for free, so do not rebuild them: the
colour scheme (light and dark, from tokens) and the responsive layout. Write
tokens, never literal colours.

Do not link back to share.fivepaths.com or to a sign-in page. The reader is
already inside the viewer, which supplies its own navigation.

## Check it before publishing

Open the file in the Browser pane and look at it. Confirm the layout holds at
a narrow width, both colour schemes read correctly, and the console is clean.
Fix what you find. A document a client will open is worth the look.

## Publish

```bash
"${CLAUDE_PLUGIN_ROOT}/skills/share/scripts/fp-share.sh" publish \
  --title "Q3 findings" --file report.html --to "sam@acme.com"
```

It creates the share, uploads the file, publishes the version, and prints the
URL. Recipients are added at creation and **no notification is sent at any
step**, which is the point.

Other commands, for follow-up work:

```bash
fp-share.sh grant   --share <id> --to "another@acme.com"   # add access, still silent
fp-share.sh version --share <id> --file report.html --note "Second pass"
fp-share.sh list    --query "findings"
```

`version` publishes a new revision under the same link, so the URL you already
handed out keeps working.

## Report back

Give the user the URL, the title, and the exact recipient list that was
granted. Say that no email went out and that they need to send the link
themselves. If a wildcard was used, name what it admits.

To undo: revoke the share, or remove a recipient, from its page in the admin
at `https://share.fivepaths.com/admin`.

## Setup, once per machine

Publishing needs a Cloudflare Access token for `share.fivepaths.com/admin`,
which means a FivePaths staff account. The script finds the token itself; a
teammate running this for the first time needs:

```bash
brew install cloudflared
cloudflared access login https://share.fivepaths.com/admin
```

That opens a browser once and caches a token the script reuses and refreshes.
On Linux, install `cloudflared` from Cloudflare's package repository instead
of Homebrew; the login step is the same.

The script tells the user exactly this if the token is missing or expired, so
run it and read the error rather than pre-checking. `FP_SHARE_ACCESS_TOKEN`
overrides the lookup if a token is supplied another way.

## Files

| Path under `$SKILL` | What |
|---|---|
| `reference/markup.md` | The v3 markup contract: bands, lists, figures, actions, colour |
| `reference/voice.md` | The writing rules, and the slop patterns to avoid |
| `assets/template.html` | A correct empty document to start from |
| `scripts/fp-share.sh` | Publishing, granting, versioning, listing |
