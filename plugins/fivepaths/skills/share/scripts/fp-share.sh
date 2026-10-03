#!/usr/bin/env bash
# Publish documents to share.fivepaths.com from the command line.
#
#   fp-share.sh login   [--label "this computer"]      # authorise this computer once, in the browser
#   fp-share.sh publish --title "Q3 findings" --file report.html --to "a@x.com, *@y.com" [--notify [--message M] [--cc C] [--subject S]]
#   fp-share.sh version --share ABC123 --file report.html [--note "Second pass"] [--notify [--message M] [--cc C] [--subject S]]
#   fp-share.sh replace --share ABC123 --file report.html [--filename NAME]  # overwrite it in the latest version; never emails
#   fp-share.sh grant   --share ABC123 --to "b@x.com" [--notify [--message M] [--cc C] [--subject S]]
#   fp-share.sh notify  --share ABC123 [--message M] [--cc C] [--subject S] [--to "only@these.com"]
#   fp-share.sh show    --share ABC123                 # the share, its URL and its recipients (JSON)
#   fp-share.sh people  --query jun                    # addresses we have shared with that match
#   fp-share.sh list    [--query text]
#   fp-share.sh whoami | logout
#
# Nothing is emailed unless --notify is given (or the command is `notify`); `replace` never emails.
# Notifications go out from the address of the staff member who authorised this computer; the
# subject defaults to the share's title.
#
# Auth: a personal token minted by `login`, kept in $XDG_CONFIG_HOME/fivepaths/share-token
# (mode 600), the same file the MCP server's `claude mcp add` header reads and share-site.sh uses.
# Older installs kept it at fivepaths/share/token, which is still read. FP_SHARE_TOKEN or
# FPS_TOKEN in the environment overrides the file. Needs only curl and jq.
#
# Every call is https://share.fivepaths.com/api/cli/*, the admin API run as the token's owner;
# reference/api.md beside this skill documents the endpoints and the MCP server at /mcp.

set -euo pipefail

BASE="${FP_SHARE_BASE:-https://share.fivepaths.com}"
API="$BASE/api/cli"
MAX_BYTES=26214400
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/fivepaths"
TOKEN_FILE="${FPS_TOKEN_FILE:-$CONFIG_DIR/share-token}"
LEGACY_TOKEN_FILE="$CONFIG_DIR/share/token"

die() { printf 'fp-share: %s\n' "$*" >&2; exit 1; }
note() { printf '%s\n' "$*" >&2; }

need() { command -v "$1" >/dev/null 2>&1 || die "$1 is required but not installed."; }
need curl
need jq

LOGIN_HELP="Authorise this computer first:

  fp-share.sh login"

token() {
  if [ -n "${FP_SHARE_TOKEN:-}" ]; then printf '%s' "$FP_SHARE_TOKEN"; return; fi
  if [ -n "${FPS_TOKEN:-}" ]; then printf '%s' "$FPS_TOKEN"; return; fi
  if [ -s "$TOKEN_FILE" ]; then tr -d '[:space:]' < "$TOKEN_FILE"; return; fi
  if [ -s "$LEGACY_TOKEN_FILE" ]; then tr -d '[:space:]' < "$LEGACY_TOKEN_FILE"; return; fi
  die "no token for $BASE. $LOGIN_HELP"
}

save_token() {
  mkdir -p "$CONFIG_DIR"
  chmod 700 "$CONFIG_DIR"
  (umask 077; printf '%s\n' "$1" > "$TOKEN_FILE")
  chmod 600 "$TOKEN_FILE"
}

# request METHOD PATH [json-body] [--no-auth] : prints the JSON payload, dies on any failure.
TOKEN=""
request() {
  local method="$1" path="$2" body="${3:-}" auth="${4:-auth}"
  local args=(-sS -X "$method" "$API$path" -H "X-Requested-With: FivePathsShare" -w '\n%{http_code}')
  if [ "$auth" = auth ]; then
    [ -n "$TOKEN" ] || TOKEN="$(token)"
    args+=(-H "Authorization: Bearer $TOKEN")
  fi
  if [ -n "$body" ]; then args+=(-H 'Content-Type: application/json' -d "$body"); fi
  local out code payload
  out="$(curl "${args[@]}")" || die "could not reach $BASE ($method $path)."
  code="${out##*$'\n'}"; payload="${out%$'\n'*}"
  check "$code" "$payload" "$method $path"
  printf '%s' "$payload"
}

check() {
  local code="$1" payload="$2" what="$3" msg
  msg="$(printf '%s' "$payload" | jq -r '.error // empty' 2>/dev/null || true)"
  case "$code" in
    200|201) ;;
    401) die "${msg:-not authorised}. $LOGIN_HELP" ;;
    403) die "${msg:-forbidden} ($what)" ;;
    429) die "${msg:-too many requests}. Wait a minute." ;;
    *) die "$what returned $code${msg:+: $msg}" ;;
  esac
  printf '%s' "$payload" | jq -e '.ok == true' >/dev/null 2>&1 || die "$what failed: ${msg:-unparseable response}"
}

json() { jq -cn "$@"; }
enc() { jq -rn --arg s "$1" '$s|@uri'; }

# The optional notification, shared by publish, version, grant and notify.
NOTIFY=false; MESSAGE=""; CC=""; SUBJECT=""
notify_body() {
  json --argjson n "$NOTIFY" --arg m "$MESSAGE" --arg c "$CC" --arg s "$SUBJECT" '{notify:$n, message:$m, cc:$c, subject:$s}'
}
notify_opts_check() {
  [ "$NOTIFY" = true ] || [ -z "$MESSAGE$CC$SUBJECT" ] || die "--message, --cc and --subject only make sense with --notify."
}
report_notified() {
  # report_notified JSON-with-.notified
  local n
  n="$(printf '%s' "$1" | jq -c '.notified // empty')"
  [ -n "$n" ] || return 0
  if [ "$NOTIFY" = true ]; then
    printf '%s' "$n" | jq -r '
      (if (.sent|length) > 0 then "notified: " + (.sent|join(", ")) else "notified: nobody (wildcards cannot be emailed)" end),
      (if (.cc|length) > 0 then "cc: " + (.cc|join(", ")) else empty end),
      (if (.failed|length) > 0 then "FAILED: " + (.failed|join(", ")) else empty end)' >&2
  else
    note "no email sent"
  fi
}

upload() {
  # upload SHARE_ID VERSION_ID|latest FILE [FILENAME] : prints the JSON payload
  local id="$1" vid="$2" file="$3" name="${4:-}"
  [ -f "$file" ] || die "no such file: $file"
  [ -n "$name" ] || name="$(basename "$file")"
  local size
  size="$(wc -c < "$file" | tr -d ' ')"
  [ "$size" -gt 0 ] || die "$file is empty."
  [ "$size" -le "$MAX_BYTES" ] || die "$file is $size bytes; the limit is $MAX_BYTES (25 MB)."
  [ -n "$TOKEN" ] || TOKEN="$(token)"
  local out code payload
  out="$(curl -sS -X PUT "$API/shares/$id/versions/$vid/files/$(enc "$name")" \
    -H "Authorization: Bearer $TOKEN" -H "X-Requested-With: FivePathsShare" \
    --data-binary "@$file" -w '\n%{http_code}')" || die "upload failed: $name"
  code="${out##*$'\n'}"; payload="${out%$'\n'*}"
  check "$code" "$payload" "upload $name"
  printf '%s' "$payload"
}

open_url() {
  if command -v open >/dev/null 2>&1; then open "$1" >/dev/null 2>&1 || true
  elif command -v xdg-open >/dev/null 2>&1; then xdg-open "$1" >/dev/null 2>&1 || true
  fi
}

# ---- commands ----

cmd_login() {
  local label=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --label) label="$2"; shift 2 ;;
      *) die "unknown option: $1" ;;
    esac
  done
  [ -n "$label" ] || label="$(hostname -s 2>/dev/null || hostname) ($(id -un))"
  local start code poll url interval expires
  start="$(request POST /login/start "$(json --arg l "$label" '{label:$l}')" none)"
  code="$(printf '%s' "$start" | jq -r .code)"
  poll="$(printf '%s' "$start" | jq -r .poll)"
  url="$(printf '%s' "$start" | jq -r .url)"
  interval="$(printf '%s' "$start" | jq -r '.interval // 3')"
  expires="$(printf '%s' "$start" | jq -r '.expires_in // 300')"
  # The Worker names its public address; when talking to a dev server, point the link there instead.
  case "$BASE" in https://share.fivepaths.com) ;; *) url="$BASE/admin/cli/approve?code=$code" ;; esac
  note "Approve this computer (\"$label\") in your browser:"
  note ""
  note "  $url"
  note ""
  note "Sign in as yourself if asked, check the computer's name, and choose Approve. Waiting..."
  open_url "$url"
  local waited=0 res status
  while [ "$waited" -lt "$expires" ]; do
    sleep "$interval"; waited=$((waited + interval))
    res="$(curl -sS -X POST "$API/login/poll" -H 'Content-Type: application/json' \
      -d "$(json --arg c "$code" --arg p "$poll" '{code:$c, poll:$p}')" 2>/dev/null || true)"
    status="$(printf '%s' "$res" | jq -r '.status // "error"' 2>/dev/null || echo error)"
    case "$status" in
      pending|error) ;;
      approved)
        save_token "$(printf '%s' "$res" | jq -r .token)"
        note "Authorised as $(printf '%s' "$res" | jq -r .email). Token saved to $TOKEN_FILE."
        return 0 ;;
      denied) die "refused in the browser. Nothing was authorised." ;;
      expired) die "the request expired before it was approved. Run login again." ;;
    esac
  done
  die "no approval within $expires seconds. Run login again."
}

cmd_logout() {
  if [ -s "$TOKEN_FILE" ] || [ -n "${FP_SHARE_TOKEN:-}" ]; then
    request POST /logout >/dev/null 2>&1 || note "the token was already invalid on the server."
  fi
  rm -f "$TOKEN_FILE"
  note "Signed out; the token is revoked and removed from this computer."
}

cmd_whoami() {
  request GET /whoami | jq -r '"\(.email) (\(.name // "no name")) via \(.label); token expires \(.expires_at / 1000 | todate)"'
}

cmd_publish() {
  local title="" to="" name=""; local files=()
  while [ $# -gt 0 ]; do
    case "$1" in
      --title) title="$2"; shift 2 ;;
      --to|--recipients) to="$2"; shift 2 ;;
      --file) files+=("$2"); shift 2 ;;
      --filename) name="$2"; shift 2 ;;
      --notify) NOTIFY=true; shift ;;
      --message) MESSAGE="$2"; shift 2 ;;
      --cc) CC="$2"; shift 2 ;;
      --subject) SUBJECT="$2"; shift 2 ;;
      *) die "unknown option: $1" ;;
    esac
  done
  [ -n "$title" ] || die "--title is required."
  [ -n "$to" ] || die "--to is required (at least one recipient)."
  [ "${#files[@]}" -gt 0 ] || die "--file is required."
  [ "${#files[@]}" -eq 1 ] || [ -z "$name" ] || die "--filename applies to a single --file."
  notify_opts_check

  local created id vid f fin
  created="$(request POST /shares "$(json --arg t "$title" --arg r "$to" '{title:$t,recipients:$r}')")"
  id="$(printf '%s' "$created" | jq -r '.id')"
  vid="$(printf '%s' "$created" | jq -r '.version_id')"
  for f in "${files[@]}"; do upload "$id" "$vid" "$f" "$name" >/dev/null; done
  fin="$(request POST "/shares/$id/versions/$vid/finalize" "$(notify_body)")"
  printf '%s/%s\n' "$BASE" "$id"
  report_notified "$fin"
}

cmd_version() {
  local id="" note=""; local files=(); local name=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --share) id="$2"; shift 2 ;;
      --file) files+=("$2"); shift 2 ;;
      --filename) name="$2"; shift 2 ;;
      --note) note="$2"; shift 2 ;;
      --notify) NOTIFY=true; shift ;;
      --message) MESSAGE="$2"; shift 2 ;;
      --cc) CC="$2"; shift 2 ;;
      --subject) SUBJECT="$2"; shift 2 ;;
      *) die "unknown option: $1" ;;
    esac
  done
  [ -n "$id" ] || die "--share is required."
  [ "${#files[@]}" -gt 0 ] || die "--file is required."
  notify_opts_check
  local v vid f fin
  v="$(request POST "/shares/$id/versions" "$(json --arg n "$note" '{note:$n}')")"
  vid="$(printf '%s' "$v" | jq -r '.version_id')"
  for f in "${files[@]}"; do upload "$id" "$vid" "$f" "$name" >/dev/null; done
  fin="$(request POST "/shares/$id/versions/$vid/finalize" "$(notify_body)")"
  printf '%s/%s\n' "$BASE" "$id"
  report_notified "$fin"
}

# A correction, not a revision: the file already in the latest published version is overwritten in
# place, so the version number and the link stay and nobody is emailed. The name must match a file
# in that version (the local file's name unless --filename says otherwise).
cmd_replace() {
  local id="" file="" name=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --share) id="$2"; shift 2 ;;
      --file) [ -z "$file" ] || die "replace takes one --file."; file="$2"; shift 2 ;;
      --filename) name="$2"; shift 2 ;;
      *) die "unknown option: $1" ;;
    esac
  done
  [ -n "$id" ] || die "--share is required."
  [ -n "$file" ] || die "--file is required."
  local res
  res="$(upload "$id" latest "$file" "$name")"
  printf '%s' "$res" | jq -r '.url'
  printf '%s' "$res" | jq -r '"replaced \(.file.filename) in version \(.version_no) (\(.file.size) bytes); no email sent"' >&2
}

cmd_grant() {
  local id="" to=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --share) id="$2"; shift 2 ;;
      --to|--recipients) to="$2"; shift 2 ;;
      --notify) NOTIFY=true; shift ;;
      --message) MESSAGE="$2"; shift 2 ;;
      --cc) CC="$2"; shift 2 ;;
      --subject) SUBJECT="$2"; shift 2 ;;
      *) die "unknown option: $1" ;;
    esac
  done
  [ -n "$id" ] || die "--share is required."
  [ -n "$to" ] || die "--to is required."
  notify_opts_check
  local res
  res="$(request POST "/shares/$id/recipients" "$(json --arg r "$to" --argjson n "$NOTIFY" --arg m "$MESSAGE" --arg c "$CC" --arg s "$SUBJECT" '{recipients:$r, notify:$n, message:$m, cc:$c, subject:$s}')")"
  printf '%s' "$res" | jq -r '(.added[]?.pattern | "granted: \(.)"), (.skipped[]? | "already had access: \(.)")' >&2
  printf '%s/%s\n' "$BASE" "$id"
  report_notified "$res"
}

cmd_notify() {
  local id="" to=""
  NOTIFY=true
  while [ $# -gt 0 ]; do
    case "$1" in
      --share) id="$2"; shift 2 ;;
      --to|--recipients) to="$2"; shift 2 ;;
      --message) MESSAGE="$2"; shift 2 ;;
      --cc) CC="$2"; shift 2 ;;
      --subject) SUBJECT="$2"; shift 2 ;;
      *) die "unknown option: $1" ;;
    esac
  done
  [ -n "$id" ] || die "--share is required."
  local body res
  if [ -n "$to" ]; then
    body="$(json --arg m "$MESSAGE" --arg c "$CC" --arg s "$SUBJECT" --arg r "$to" '{message:$m, cc:$c, subject:$s, recipients: ($r | split(",") | map(ascii_downcase | gsub("^\\s+|\\s+$"; "")) | map(select(length > 0)))}')"
  else
    body="$(json --arg m "$MESSAGE" --arg c "$CC" --arg s "$SUBJECT" '{message:$m, cc:$c, subject:$s}')"
  fi
  res="$(request POST "/shares/$id/notify" "$body")"
  printf '%s/%s\n' "$BASE" "$id"
  report_notified "$res"
}

cmd_show() {
  local id=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --share) id="$2"; shift 2 ;;
      *) die "unknown option: $1" ;;
    esac
  done
  [ -n "$id" ] || die "--share is required."
  local share recips
  share="$(request GET "/shares/$id")"
  recips="$(request GET "/shares/$id/recipients")"
  jq -n --argjson s "$share" --argjson r "$recips" '{share: $s.share, recipients: $r.recipients}'
}

cmd_people() {
  local q=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --query|-q) q="$2"; shift 2 ;;
      *) die "unknown option: $1" ;;
    esac
  done
  [ "${#q}" -ge 2 ] || die "--query needs at least two characters."
  request GET "/people?q=$(enc "$q")" \
    | jq -r 'if (.people|length) == 0 then "no matches" else .people[] | "\(.email)\t\(.shares) share\(if .shares == 1 then "" else "s" end)\tlast: \(.last_share_title) (\(.last_share_id))" end'
}

cmd_list() {
  local q=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --query|-q) q="$2"; shift 2 ;;
      *) die "unknown option: $1" ;;
    esac
  done
  request GET "/shares?q=$(enc "$q")&archived=0" | jq -r '.shares[] | "\(.id)\t\(.title)"'
}

case "${1:-}" in
  login)   shift; cmd_login "$@" ;;
  logout)  shift; cmd_logout "$@" ;;
  whoami)  shift; cmd_whoami "$@" ;;
  publish) shift; cmd_publish "$@" ;;
  version) shift; cmd_version "$@" ;;
  replace) shift; cmd_replace "$@" ;;
  grant)   shift; cmd_grant "$@" ;;
  notify)  shift; cmd_notify "$@" ;;
  show)    shift; cmd_show "$@" ;;
  people)  shift; cmd_people "$@" ;;
  list)    shift; cmd_list "$@" ;;
  ''|-h|--help) awk 'NR>1 && /^#/ {sub(/^# ?/,""); print; next} NR>1 {exit}' "$0" ;;
  *) die "unknown command: $1" ;;
esac
