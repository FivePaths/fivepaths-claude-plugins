#!/usr/bin/env bash
# Exercises fp-project.sh without a hub: the CI refusal, cache use and expiry,
# the stale-cache fallback, the multi-project refusal, and the working-tree
# guard. Run from anywhere: tests/test.sh
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="$HERE/../scripts/fp-project.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
export XDG_DATA_HOME="$TMP/data" XDG_CONFIG_HOME="$TMP/config"
export FP_HUB_URL="http://127.0.0.1:9" FP_HUB_TOKEN="test-token"   # port 9: nothing listens
unset CI
pass=0; fail=0
ok()   { pass=$((pass+1)); printf 'ok   %s\n' "$1"; }
bad()  { fail=$((fail+1)); printf 'FAIL %s\n%s\n' "$1" "${2:-}"; }
expect_rc() { # expect_rc NAME RC cmd...
  local name="$1" want="$2"; shift 2
  local out rc=0
  out="$("$@" 2>&1)" || rc=$?
  if [ "$rc" -eq "$want" ]; then ok "$name (rc $rc)"; else bad "$name: wanted rc $want, got $rc" "$out"; fi
  LAST="$out"
}

# A site-shaped git repo with a Pantheon origin.
REPO="$TMP/site"; git init -q "$REPO"; git -C "$REPO" remote add origin ssh://codeserver.dev.d79afa9e-0a79-4b72-bd59-f9c56344673f@codeserver.dev.d79afa9e-0a79-4b72-bd59-f9c56344673f.drush.in:2222/~/repository.git
cd "$REPO"

# 1. CI refusal comes before any network call or token check.
expect_rc "refuses with CI set" 3 env CI=1 FP_HUB_TOKEN= "$SCRIPT" resolve
grep -q "refusing to run with CI set" <<<"$LAST" || bad "CI message" "$LAST"

# 2. No cache and no hub: fails to reach the hub (rc 1), says so.
expect_rc "no cache, hub down" 1 "$SCRIPT" resolve
grep -q "could not reach" <<<"$LAST" || bad "unreachable message" "$LAST"

# 3. A fresh cache answers without the network.
KEY="pantheon-d79afa9e-0a79-4b72-bd59-f9c56344673f"
CACHE="$XDG_DATA_HOME/fivepaths/project/$KEY.json"
mkdir -p "$(dirname "$CACHE")"
one='{"remote":"x","normalised":{"kind":"pantheon","identifier":"d79afa9e-0a79-4b72-bd59-f9c56344673f"},"count":1,"projects":[{"project_id":"11111111-1111-1111-1111-111111111111","label":"SMART build","client":"SMART","status":"active","start":"2026-06-01","expected_end":"2027-03-31","context_repo":"project/smart","clone_url":"git@git.fivepaths.com:project/smart.git","repos":[],"links":[],"properties":[]}]}'
jq -cn --argjson r "$one" --argjson now "$(date +%s)" '{remote:"x",fetched_at:$now,resolution:$r}' > "$CACHE"
expect_rc "fresh cache is used" 0 "$SCRIPT" resolve
grep -q "using cached resolution" <<<"$LAST" || bad "cache note" "$LAST"
grep -q '"label": "SMART build"' <<<"$LAST" || bad "cache content" "$LAST"
expect_rc "path from cache" 0 "$SCRIPT" path
[ "$(tail -1 <<<"$LAST")" = "$XDG_DATA_HOME/fivepaths/project/smart" ] && ok "path is the XDG slug directory" || bad "path" "$LAST"

# 4. An expired cache asks the hub; with the hub down it falls back and says so.
jq -cn --argjson r "$one" --argjson then "$(( $(date +%s) - 90000 ))" '{remote:"x",fetched_at:$then,resolution:$r}' > "$CACHE"
expect_rc "expired cache re-resolves, falls back when hub is down" 0 "$SCRIPT" resolve
grep -q "stale cache" <<<"$LAST" || bad "stale note" "$LAST"
grep -qv "using cached resolution" <<<"$LAST" || bad "expired cache must not read as fresh" "$LAST"

# 5. --refresh ignores a fresh cache.
jq -cn --argjson r "$one" --argjson now "$(date +%s)" '{remote:"x",fetched_at:$now,resolution:$r}' > "$CACHE"
expect_rc "--refresh asks the hub" 0 "$SCRIPT" resolve --refresh
grep -q "stale cache" <<<"$LAST" || bad "--refresh should have tried the hub" "$LAST"

# 6. Two projects: refuses to choose, lists both, exit 4.
two="$(jq -c '.count=2 | .projects += [(.projects[0] | .label="SMART maintenance" | .project_id="22222222-2222-2222-2222-222222222222")]' <<<"$one")"
jq -cn --argjson r "$two" --argjson now "$(date +%s)" '{remote:"x",fetched_at:$now,resolution:$r}' > "$CACHE"
expect_rc "two projects refuse" 4 "$SCRIPT" path
grep -q "SMART maintenance" <<<"$LAST" && grep -q -- "--project" <<<"$LAST" || bad "lists both and names --project" "$LAST"

# 7. --project reads its own cache key.
PCACHE="$XDG_DATA_HOME/fivepaths/project/project-11111111-1111-1111-1111-111111111111.json"
jq -cn --argjson r "$one" --argjson now "$(date +%s)" '{remote:"project:1111",fetched_at:$now,resolution:$r}' > "$PCACHE"
expect_rc "--project uses its cache" 0 "$SCRIPT" path --project 11111111-1111-1111-1111-111111111111

# 8. fetch refuses when the data directory would sit inside the working tree.
expect_rc "refuses a data dir inside the working tree" 1 env XDG_DATA_HOME="$REPO/.local" "$SCRIPT" fetch --project 11111111-1111-1111-1111-111111111111
grep -q "inside the current working tree\|could not reach" <<<"$LAST" || bad "working-tree guard" "$LAST"

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
