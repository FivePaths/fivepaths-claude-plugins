# The Share API and MCP server, for agents

Everything the `share` skill does goes through `https://share.fivepaths.com`
over HTTPS, authenticated by a **personal token** that a FivePaths staff member
minted by approving the computer once in their browser. The token acts as that
person: every share it creates and every email it sends is theirs, and it all
appears in the admin's Activity log under their name. Nothing here needs a
browser, Cloudflare Access tooling, or the admin site.

There are two ways in, and one report needs both or either:

| Route | What it can do | When to use it |
|---|---|---|
| **The command-line API**, `POST /api/cli/...`, wrapped by `fp-share.sh` | Create a document share, upload files, publish a version, rename, grant and remove access, notify, look up people, read a share back | **Publishing a report.** This is the only route that uploads a file. |
| **The MCP server**, `POST /mcp` | List shares, read one share and its recipients, add and remove recipients, notify, register a client website and print its gate configuration | Follow-up on a share that already exists, and website shares. It cannot create a document share or upload anything. |

Both run the same admin handlers with the same allowlist, so neither can do
more than the other except that only the HTTP API takes a file body. Whatever
route is taken, the same rules apply: revoking, archiving and deleting a share,
reading the log, and signing clients out are **not** possible with a token; they
stay in the browser at `https://share.fivepaths.com/admin`.

## The token

- **Minting.** `fp-share.sh login` runs the device-code flow: it asks
  `POST /api/cli/login/start` for a code, prints and opens
  `https://share.fivepaths.com/admin/cli/approve?code=...`, and polls
  `POST /api/cli/login/poll` until the staff member approves in the browser.
  The token starts `fps_` and lasts 90 days.
- **Where it lives.** `~/.config/fivepaths/share-token` (mode 600). Older
  installs kept it at `~/.config/fivepaths/share/token`; the script reads
  either. `FP_SHARE_TOKEN` or `FPS_TOKEN` in the environment overrides both.
- **Headers on every call.** `Authorization: Bearer fps_...`, and on every
  non-GET call `X-Requested-With: FivePathsShare`. Without the second header
  the answer is 403 `Missing X-Requested-With header.`
- **Checking it.** `GET /api/cli/whoami` returns `{ok, email, name, label,
  expires_at}`. A 401 means the token is missing, expired or revoked; the fix
  is `fp-share.sh login` again. Do not pre-check; call and read the error.
- **Revoking.** `POST /api/cli/logout` revokes the calling token
  (`fp-share.sh logout`). All of a person's tokens are listed and revokable at
  `https://share.fivepaths.com/admin/tokens`.

## Publishing a report over the HTTP API

This is the sequence `fp-share.sh publish` runs. Use the script when you can;
the raw calls are here so an agent without it, or one debugging a failure,
knows exactly what happens. `$T` is the token.

```bash
H=(-H "Authorization: Bearer $T" -H 'X-Requested-With: FivePathsShare')
B=https://share.fivepaths.com/api/cli

# 1. Create the share. Recipients are comma-separated addresses and *@domain wildcards; at least one.
curl -sS -X POST "$B/shares" "${H[@]}" -H 'Content-Type: application/json' \
  -d '{"title":"Q3 findings","recipients":"jun@acme.com, *@acme.com"}'
# {"ok":true,"id":"Cp5CwSfK4FFz","kind":"files","url":"https://share.fivepaths.com/Cp5CwSfK4FFz","version_id":"...","version_no":1}

# 2. Upload the file into the draft version. Raw body; the filename is the last path segment, URL-encoded.
curl -sS -X PUT "$B/shares/$ID/versions/$VID/files/q3-findings.html" "${H[@]}" --data-binary @q3-findings.html
# {"ok":true,"file":{"filename":"q3-findings.html","content_type":"text/html","size":48210,...}}

# 3. Publish. Nothing is emailed unless notify is true.
curl -sS -X POST "$B/shares/$ID/versions/$VID/finalize" "${H[@]}" -H 'Content-Type: application/json' \
  -d '{"notify":false,"message":"","cc":""}'
# {"ok":true,"url":"https://share.fivepaths.com/Cp5CwSfK4FFz","version_no":1,"notified":{"sent":[],"failed":[],"cc":[]}}
```

The link to hand out is `https://share.fivepaths.com/<id>`. A share holding
**one HTML file** renders that file in the viewer; a second file turns the share
into a download list, so a report is always one self-contained HTML file.

To notify at publish time, send `{"notify":true,"message":"...","cc":"...",
"subject":"..."}` to finalize. The email goes From and Reply-To the token
owner's address, the subject defaults to the share title, and `notified.sent`
lists who got it. Wildcard recipients cannot be emailed and are simply not in
`sent`.

### Everything a token may call

`/api/cli/<path>` is `/api/admin/<path>` run as the token's owner, for exactly
these. Anything else answers 403 `Not available from the command line.`

| Method | Path | Body → result |
|---|---|---|
| GET | `/shares?q=&archived=&kind=` | → `{shares: [{id, title, kind, hostname, created_at, revoked_at, archived_at, recipient_count, view_count, ...}]}`. `archived=0` live only, `1` archived only; `kind=files`, `site` or `request` |
| POST | `/shares` | `{title, recipients}` → `{id, url, version_id, version_no}`. Also `{kind:"site", hostname, title, recipients}` for a client website → `{id, url, share_url}`, and `{kind:"request", title, notes, recipients}` for a file request |
| GET | `/shares/:id` | → `{share: {..., url}}` with counts and where a client opens it |
| PATCH | `/shares/:id` | `{title}` renames; `{hostname}` moves a website; `{notes}` changes a request's instructions |
| POST | `/shares/:id/versions` | `{note}` → `{version_id, version_no}`: a new draft under the same link |
| PUT | `/shares/:id/versions/:vid/files/:filename` | raw body, up to 25 MB, `Content-Length` required → `{file}` |
| DELETE | `/shares/:id/versions/:vid/files/:filename` | remove a draft file |
| DELETE | `/shares/:id/versions/:vid` | discard a draft |
| POST | `/shares/:id/versions/:vid/finalize` | `{notify, message, cc, subject}` → `{url, version_no, notified}` |
| GET | `/shares/:id/recipients` | → `{recipients: [{id, pattern, added_by, added_by_type, added_at}]}` |
| POST | `/shares/:id/recipients` | `{recipients, notify, message, cc, subject}` → `{added: [...], skipped: [...], notified}`; only the newcomers are emailed |
| DELETE | `/shares/:id/recipients/:rid` | remove one, by the `id` from the list |
| POST | `/shares/:id/notify` | `{message, cc, subject, recipients?}` → `{notified}`; `recipients` is an array of addresses already on the share, omit for everyone named |
| GET | `/shares/:id/gate` | a website's gate Worker config: `{wrangler, secret_command, checks}` |
| GET | `/people?q=` | `{people: [{email, shares, last_share_title, last_share_id}]}`; `q` is two characters or more |

Share ids are twelve characters from a base-58 alphabet. Every response is
JSON with `ok`; failures carry `error` with a sentence meant to be shown.
Status codes: 400 bad input, 401 token problem, 403 not allowed from the
command line or missing `X-Requested-With`, 404 no such share, 409 conflict
(a hostname in use, a version already published), 413 file too large, 429
too many login attempts.

## The MCP server

`https://share.fivepaths.com/mcp` speaks Streamable HTTP in its stateless form:
one `POST` per JSON-RPC message, no session id, no SSE stream. It takes the
same `fps_` token as a bearer header and offers nine tools, each of which is
one of the calls above run as the token's owner.

Connect Claude Code once per machine:

```bash
claude mcp add --transport http fivepaths-share https://share.fivepaths.com/mcp \
  --header "Authorization: Bearer $(cat ~/.config/fivepaths/share-token)"
```

Or in a project's `.mcp.json`, reading the token from the environment:

```json
{
  "mcpServers": {
    "fivepaths-share": {
      "type": "http",
      "url": "https://share.fivepaths.com/mcp",
      "headers": { "Authorization": "Bearer ${FPS_TOKEN}" }
    }
  }
}
```

The claude.ai connector list cannot register it: it has no header field and
expects OAuth, which the endpoint does not offer. A 404 from `/mcp` means the
deployment has `MCP_ENABLED` off; a 401 means the header is missing or the
token is dead.

| Tool | Arguments | Does |
|---|---|---|
| `list_shares` | `kind?`, `q?`, `archived?` | Shares newest first with id, title, kind, hostname, counts, revoked and archived flags |
| `get_share` | `id` | One share with its counts and the address a client opens |
| `list_recipients` | `id` | Who may open it, with the recipient id `remove_recipient` takes |
| `add_recipients` | `id`, `recipients`, `notify?`, `message?`, `cc?`, `subject?` | Grant access; skips and reports addresses already on it; emails only the newcomers when `notify` is true |
| `remove_recipient` | `id`, `recipient` | By address, wildcard or recipient id |
| `notify_recipients` | `id`, `message?`, `cc?`, `subject?`, `recipients?` | Email every named recipient, or only the listed ones, from the token owner's address |
| `create_site_share` | `hostname`, `title`, `recipients`, `notify?`, `message?`, `cc?`, `subject?` | Register a client website; the id is the gate Worker's `SITE_ID` |
| `set_site_hostname` | `id`, `hostname` | Move a website; the gate's route must follow |
| `gate_config` | `id` | The website's `wrangler.jsonc` fragment, the `GATE_SECRET` command and the curl checks |

When the `fivepaths-share` MCP server is connected in a session, prefer its
tools for the follow-up steps in the skill (who is on a share, adding someone,
sending a nudge) and `fp-share.sh` for anything that touches a file. When it
is not connected, `fp-share.sh` covers all of the same ground except the
website tools, which `scripts/share-site.sh` in the Share repository wraps.

## What is not possible from either route

Revoke, restore, archive, unarchive or delete a share; read or export the
Activity log; download what a client sent to a file request; list or end
client sessions; text alerts. Those are browser-only, behind the staff
sign-in at `https://share.fivepaths.com/admin`, by design: a token is a
publishing credential, not an administrator.
