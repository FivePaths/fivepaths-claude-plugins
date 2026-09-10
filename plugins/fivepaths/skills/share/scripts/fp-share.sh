#!/usr/bin/env bash
# Publish a document to share.fivepaths.com and grant access, without sending email.
#
# Every call here leaves notify off, so recipients get access and no message.
# Tell them the link yourself.
#
#   fp-share.sh publish --title "Q3 findings" --file report.html --to "a@x.com, *@y.com"
#   fp-share.sh grant   --share ABC123 --to "b@x.com"
#   fp-share.sh version --share ABC123 --file report.html --note "Second pass"
#   fp-share.sh list    [--query text]
#
# Auth: a Cloudflare Access token for share.fivepaths.com/admin. Either set
# FP_SHARE_ACCESS_TOKEN, or install cloudflared and sign in once.

set -euo pipefail

BASE="${FP_SHARE_BASE:-https://share.fivepaths.com}"
APP="$BASE/admin"
MAX_BYTES=26214400

die() { printf 'fp-share: %s\n' "$*" >&2; exit 1; }

need() { command -v "$1" >/dev/null 2>&1 || die "$1 is required but not installed."; }
need curl
need jq

token() {
  if [ -n "${FP_SHARE_ACCESS_TOKEN:-}" ]; then printf '%s' "$FP_SHARE_ACCESS_TOKEN"; return; fi
  command -v cloudflared >/dev/null 2>&1 || die \
"no Access token. Install the Cloudflare Access CLI and sign in once:

  brew install cloudflared
  cloudflared access login $APP

Then re-run. (Or export FP_SHARE_ACCESS_TOKEN with a valid token.)"
  local t
  t="$(cloudflared access token --app "$APP" 2>/dev/null || true)"
  case "$t" in
    ey*) printf '%s' "$t" ;;
    *) die "Access token expired or missing. Sign in again:

  cloudflared access login $APP" ;;
  esac
}

TOKEN=""
api() {
  # api METHOD PATH [json-body]
  local method="$1" path="$2" body="${3:-}"
  [ -n "$TOKEN" ] || TOKEN="$(token)"
  local args=(-sS -X "$method" "$BASE$path"
    -H "cf-access-jwt-assertion: $TOKEN"
    -H "X-Requested-With: FivePathsShare"
    -w '\n%{http_code}')
  if [ -n "$body" ]; then args+=(-H 'Content-Type: application/json' -d "$body"); fi
  local out code payload
  out="$(curl "${args[@]}")" || die "request failed: $method $path"
  code="${out##*$'\n'}"; payload="${out%$'\n'*}"
  check "$code" "$payload" "$method $path"
  printf '%s' "$payload"
}

check() {
  local code="$1" payload="$2" what="$3"
  case "$code" in
    200|201) ;;
    302|401|403)
      # Access bounces an unauthenticated API call to its login page.
      die "not authorised ($code) on $what. Sign in again:

  cloudflared access login $APP" ;;
    *)
      local msg
      msg="$(printf '%s' "$payload" | jq -r '.error // empty' 2>/dev/null || true)"
      die "$what returned $code${msg:+: $msg}" ;;
  esac
  printf '%s' "$payload" | jq -e '.ok == true' >/dev/null 2>&1 || {
    local msg
    msg="$(printf '%s' "$payload" | jq -r '.error // "unknown error"' 2>/dev/null || echo 'unparseable response')"
    die "$what failed: $msg"
  }
}

upload() {
  # upload SHARE_ID VERSION_ID FILE [FILENAME]
  local id="$1" vid="$2" file="$3" name="${4:-}"
  [ -f "$file" ] || die "no such file: $file"
  [ -n "$name" ] || name="$(basename "$file")"
  local size
  size="$(wc -c < "$file" | tr -d ' ')"
  [ "$size" -gt 0 ] || die "$file is empty."
  [ "$size" -le "$MAX_BYTES" ] || die "$file is $size bytes; the limit is $MAX_BYTES (25 MB)."
  [ -n "$TOKEN" ] || TOKEN="$(token)"
  local enc out code payload
  enc="$(jq -rn --arg s "$name" '$s|@uri')"
  out="$(curl -sS -X PUT "$BASE/api/admin/shares/$id/versions/$vid/files/$enc" \
    -H "cf-access-jwt-assertion: $TOKEN" \
    -H "X-Requested-With: FivePathsShare" \
    --data-binary "@$file" \
    -w '\n%{http_code}')" || die "upload failed: $name"
  code="${out##*$'\n'}"; payload="${out%$'\n'*}"
  check "$code" "$payload" "upload $name"
}

json() { jq -cn "$@"; }

cmd_publish() {
  local title="" to="" name=""; local files=()
  while [ $# -gt 0 ]; do
    case "$1" in
      --title) title="$2"; shift 2 ;;
      --to|--recipients) to="$2"; shift 2 ;;
      --file) files+=("$2"); shift 2 ;;
      --filename) name="$2"; shift 2 ;;
      *) die "unknown option: $1" ;;
    esac
  done
  [ -n "$title" ] || die "--title is required."
  [ -n "$to" ] || die "--to is required (at least one recipient)."
  [ "${#files[@]}" -gt 0 ] || die "--file is required."
  [ "${#files[@]}" -eq 1 ] || [ -z "$name" ] || die "--filename applies to a single --file."

  local created id vid
  created="$(api POST /api/admin/shares "$(json --arg t "$title" --arg r "$to" '{title:$t,recipients:$r}')")"
  id="$(printf '%s' "$created" | jq -r '.id')"
  vid="$(printf '%s' "$created" | jq -r '.version_id')"

  local f
  for f in "${files[@]}"; do upload "$id" "$vid" "$f" "$name"; done

  api POST "/api/admin/shares/$id/versions/$vid/finalize" '{"notify":false}' >/dev/null
  printf '%s/%s\n' "$BASE" "$id"
}

cmd_grant() {
  local id="" to=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --share) id="$2"; shift 2 ;;
      --to|--recipients) to="$2"; shift 2 ;;
      *) die "unknown option: $1" ;;
    esac
  done
  [ -n "$id" ] || die "--share is required."
  [ -n "$to" ] || die "--to is required."
  local res
  res="$(api POST "/api/admin/shares/$id/recipients" "$(json --arg r "$to" '{recipients:$r,notify:false}')")"
  printf '%s' "$res" | jq -r '(.added[]?.pattern | "granted: \(.)"), (.skipped[]? | "already had access: \(.)")'
  printf '%s/%s\n' "$BASE" "$id"
}

cmd_version() {
  local id="" note=""; local files=(); local name=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --share) id="$2"; shift 2 ;;
      --file) files+=("$2"); shift 2 ;;
      --filename) name="$2"; shift 2 ;;
      --note) note="$2"; shift 2 ;;
      *) die "unknown option: $1" ;;
    esac
  done
  [ -n "$id" ] || die "--share is required."
  [ "${#files[@]}" -gt 0 ] || die "--file is required."
  local v vid
  v="$(api POST "/api/admin/shares/$id/versions" "$(json --arg n "$note" '{note:$n}')")"
  vid="$(printf '%s' "$v" | jq -r '.version_id')"
  local f
  for f in "${files[@]}"; do upload "$id" "$vid" "$f" "$name"; done
  api POST "/api/admin/shares/$id/versions/$vid/finalize" '{"notify":false}' >/dev/null
  printf '%s/%s\n' "$BASE" "$id"
}

cmd_list() {
  local q=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --query|-q) q="$2"; shift 2 ;;
      *) die "unknown option: $1" ;;
    esac
  done
  api GET "/api/admin/shares?q=$(jq -rn --arg s "$q" '$s|@uri')&archived=0" \
    | jq -r '.shares[] | "\(.id)\t\(.title)"'
}

case "${1:-}" in
  publish) shift; cmd_publish "$@" ;;
  grant)   shift; cmd_grant "$@" ;;
  version) shift; cmd_version "$@" ;;
  list)    shift; cmd_list "$@" ;;
  ''|-h|--help) awk 'NR>1 && /^#/ {sub(/^# ?/,""); print; next} NR>1 {exit}' "$0" ;;
  *) die "unknown command: $1" ;;
esac
