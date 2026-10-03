---
name: share
description: Publish a document to share.fivepaths.com with access for named recipients, and optionally email them from the user's own address, entirely from the session through the Share API and MCP server, never the website. Use when asked to "share X with Y", "send X to Y", "send this to Jun", to deliver a report, summary, brief, findings, proposal or write-up to a client or colleague, to put a document on share.fivepaths.com, or to see, change or nudge the recipients of an existing share. Resolves first names to addresses from the project's contacts and from the portal's own history, and confirms before any email goes out.
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

None of it needs the Share website. The whole flow, from an HTML file on disk
to a link a client can open, runs from the session against
`https://share.fivepaths.com/api/cli` with a personal token, and follow-up
on a share can use the `fivepaths-share` MCP server when the session has it
connected. `$SKILL/reference/api.md` documents both: every endpoint a token
may call, the exact create, upload and publish sequence, the nine MCP tools,
and what neither route can do. Read it when a call fails in a way the script
does not explain, when you need a field the script does not print, or when you
are working without the script.

**Which route for what.** Publishing a report is always the HTTP API through
`fp-share.sh`: only it can upload a file, and the MCP server has no tool to
create a document share. Once a share exists, the MCP tools `get_share`,
`list_recipients`, `add_recipients`, `remove_recipient`, `notify_recipients`
and `list_shares` do the follow-up with no shell involved; `fp-share.sh
show`, `grant`, `notify` and `list` do the same when the server is not
connected. Both act as the same person and are logged the same way, so pick
whichever is at hand; never do the same step through both.

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
URL, then who was notified if anyone was. Under the hood that is three calls:
`POST /shares`, `PUT /shares/{id}/versions/{vid}/files/{name}`, and
`POST /shares/{id}/versions/{vid}/finalize`; `reference/api.md` shows them as
curl for the case where the script is not usable. `--subject` sets the email's
subject line; it defaults to the title.

Follow-up work on an existing share:

```bash
fp-share.sh grant   --share <id> --to "another@acme.com" [--notify --message "..."]   # add access; email only the newcomers if asked
fp-share.sh version --share <id> --file q3-findings.html --note "Second pass" [--notify --message "..."]
fp-share.sh replace --share <id> --file q3-findings.html   # fix the latest version in place; same version number, never emails
fp-share.sh notify  --share <id> --message "..." [--to "only@these.com"] [--cc "..."]  # email current recipients about what is already there
fp-share.sh show    --share <id>                 # the share, its URL and its recipients, as JSON
fp-share.sh list    --query "findings"
fp-share.sh people  --query jun
```

With the `fivepaths-share` MCP server connected, the same follow-up is
`get_share`, `list_recipients`, `add_recipients` (with `notify` and
`message` for the newcomers), `notify_recipients` and `list_shares`. A new
version of the document, or a correction to it, still goes through
`fp-share.sh version` or `replace`.

`version` publishes a new revision under the same link, so the URL already
handed out keeps working. Wildcard recipients cannot be emailed; `notify`
reaches only exact addresses and says so.

**`replace` or `version`.** Both keep the link. Choose by what readers should
see:

- **`replace`** for small corrections: a typo, a wrong figure, a broken link,
  a line the user calls "just a fix", or whenever they say "no new revision",
  "don't bump the version" or "just update it". It overwrites the file in the
  latest published version, keeps its number, and never emails. The local
  file's name must match the one in the version (`--filename` names it when
  it does not; `show` gives the share, and the error lists the version's
  files).
- **`version`** for substantive changes readers should see as a new version:
  new sections, revised findings or recommendations, anything a reader who
  already opened it ought to know changed, and whenever the user asks for a
  new version or wants recipients told. Its `--note` and `--notify` say what
  changed.

When it is unclear, ask; a needless new version is noise, a silent change
to findings someone has already read is worse. After a `replace`, report
the URL and that the version number is unchanged and nothing was sent.

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
`~/.config/fivepaths/share-token` (an older install's
`~/.config/fivepaths/share/token` is still read). Nothing else needs
installing beyond `curl` and `jq`. Tokens last 90 days; when the script
reports one as invalid or expired, run `login` again. `fp-share.sh logout`
revokes the token, and every token a person holds is listed under their name
in the admin.

The script says exactly this when the token is missing or expired, so run the
command and read the error rather than pre-checking. `FP_SHARE_TOKEN` or
`FPS_TOKEN` in the environment overrides the stored token.

The same token connects the MCP server, once per machine:

```bash
claude mcp add --transport http fivepaths-share https://share.fivepaths.com/mcp \
  --header "Authorization: Bearer $(cat ~/.config/fivepaths/share-token)"
```

Optional: the skill works without it. When the token is renewed, the
registration keeps the old header and starts answering 401, so remove and add
the server again. `reference/api.md` has the `.mcp.json` form for a project.

## Files

| Path under `$SKILL` | What |
|---|---|
| `scripts/fp-share.sh` | Login, publishing, granting, versioning, correcting the latest version in place, notifying, people lookup, listing, reading a share back |
| `reference/api.md` | The `/api/cli` endpoints a token may call, the publish sequence as curl, the MCP server and its nine tools, and what stays browser-only |
