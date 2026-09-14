---
name: share
description: Publish a document to share.fivepaths.com with access for named recipients, and optionally email them from the user's own address. Use when asked to "share X with Y", "send X to Y", "send this to Jun", to deliver a report, summary, brief, findings, proposal or write-up to a client or colleague, or to put a document on share.fivepaths.com. Resolves first names to addresses from the project's contacts and from the portal's own history, and confirms before any email goes out.
---

# Share or send a document

Two verbs, one pipeline.

- **Share X with Y**: publish X to share.fivepaths.com and grant Y access.
  **No email is sent.** Hand the link to the user; they pass it on.
- **Send X to Y** (also "email", "let them know", "notify"): the same, then
  email Y from the user's own address with the link and an optional message.

Read the request for which one it is. "Share it with Jun and let her know"
is a send. When it is not clear, share silently and say the notification is
one flag away; a silent share is easy to follow up, an email is not undone.

Everything this skill needs is bundled with it. `$SKILL` below is
`${CLAUDE_PLUGIN_ROOT}/skills/share`, and `fp-share.sh` is
`$SKILL/scripts/fp-share.sh`.

## 1. Get the document

X must be **one self-contained HTML file** in the FivePaths design system. If
it already is (the user points at such a file, or one was just produced),
use it. Otherwise invoke the `document` skill first, on the current file, on
the work in this conversation, or on the topic, and come back with its
output.

## 2. Resolve the recipients

Y must resolve to email addresses:

- An exact address: `sam@acme.com`
- A domain wildcard: `*@acme.com`, which admits **anyone** at that domain.
  Only when the user asks for it in those terms; never turn a company name
  into a wildcard on your own.

A first name or a role ("Jun", "the client", "Acme's PM") is resolved in this
order, stopping at the first unambiguous answer:

1. **The project.** Look for `CONTACTS.md` at the project root, then a
   *People* or *Contacts* section in `CLAUDE.md` or `README.md`. The
   convention is one line per person: `- Jun Park <jun@acme.com>, product
   lead at Acme`. Read the whole file: the same first name can appear twice.
2. **The portal.** `fp-share.sh people --query jun` lists the addresses we
   have already shared with that match, with the share each was last added
   to. A single match whose last share belongs to this client is the answer.
   Two matches, or a match from an unrelated client, is not.
3. **Ask.** Say what you found and what you would grant, and let the user
   choose. Never construct an address from a name and a domain.

When the project has no contacts file and you resolved the person from the
portal or from the user's answer, offer to add a `CONTACTS.md` line so the
next session does not have to ask.

## 3. Confirm before anything is emailed

Sharing silently may proceed once the recipients are resolved. Sending may
not: show the title, the exact recipient addresses, the CC list if any, and
the message, then wait for a yes. The email goes out From and Reply-To the
user's own address, and every recipient sees it, so this is the moment to
catch a wrong Jun.

Write the message in the user's voice, two or three plain sentences: what
the document is and what, if anything, they are asked to do with it. No
greeting line, no sign-off; the notification email carries the name.

## 4. Publish

```bash
# share: access only, nothing sent
"$SKILL/scripts/fp-share.sh" publish --title "Q3 findings" --file q3-findings.html --to "jun@acme.com"

# send: access, then one email per recipient from the user's address
"$SKILL/scripts/fp-share.sh" publish --title "Q3 findings" --file q3-findings.html --to "jun@acme.com" \
  --notify --message "Here are the Q3 findings we discussed. The fares section is the one to read first." --cc "pm@fivepaths.com"
```

It creates the share, uploads the file, publishes the version, and prints the
URL, then who was notified if anyone was.

Follow-up work on an existing share:

```bash
fp-share.sh grant   --share <id> --to "another@acme.com" [--notify --message "..."]   # add access; email only the newcomers if asked
fp-share.sh version --share <id> --file q3-findings.html --note "Second pass" [--notify --message "..."]
fp-share.sh notify  --share <id> --message "..." [--to "only@these.com"] [--cc "..."]  # email current recipients about what is already there
fp-share.sh list    --query "findings"
fp-share.sh people  --query jun
```

`version` publishes a new revision under the same link, so the URL already
handed out keeps working. Wildcard recipients cannot be emailed; `notify`
reaches only exact addresses and says so.

## 5. Report back

Give the URL, the title, and the exact recipients granted. If a wildcard was
used, name what it admits. If nothing was emailed, say so and that the user
sends the link themselves. If recipients were emailed, name them and repeat
the message that went out.

To undo: revoke the share, or remove a recipient, from its page in the admin
at `https://share.fivepaths.com/admin`. The command line cannot revoke or
delete, by design.

## Setup, once per computer

Publishing needs a personal token, which a FivePaths staff member gets by
approving this computer once in their browser:

```bash
"$SKILL/scripts/fp-share.sh" login
```

It prints and opens a link at share.fivepaths.com. The browser signs in
through Cloudflare Access as usual, shows the computer's name, and asks for
approval; the script collects the token and keeps it in
`~/.config/fivepaths/share/token`. Nothing else needs installing beyond
`curl` and `jq`. Tokens last 90 days; when the script reports one as invalid
or expired, run `login` again. `fp-share.sh logout` revokes the token, and
every token a person holds is listed under their name in the admin.

The script says exactly this when the token is missing or expired, so run the
command and read the error rather than pre-checking. `FP_SHARE_TOKEN` in the
environment overrides the stored token.

## Files

| Path under `$SKILL` | What |
|---|---|
| `scripts/fp-share.sh` | Login, publishing, granting, versioning, notifying, people lookup, listing |
