#!/usr/bin/env bash
# scripts/cli-e2e.sh --- End-to-end check of the recurya CLI against the dev server.
#
# Logs in through the dev OAuth stub, issues an API token on /account, creates
# a private draft notebook with a gated solution, then drives the CLI:
# login -> pull -> run (fail) -> edit -> run (pass, solution unlocked) ->
# status, and finally checks the browser page shows the unlocked solution.
# The client is downloaded from $BASE/static/recurya (the real distribution
# path); needs python3, not qlot.
# Needs the dev server (OAUTH_DEV_STUB on) and a stub user with a real handle.
# The "cli-e2e" token it issues is revoked at the end (and leftovers from
# aborted runs are revoked at the start); the draft notebook is kept as dev data.
set -uo pipefail
cd "$(dirname "$0")/.."
source scripts/request-test.sh >/dev/null   # rt_* primitives only
PASS=0; FAIL=0
ROOT="$(pwd)"
WORK="$(mktemp -d)"; export RECURYA_CONFIG_DIR="$WORK/config"
trap 'rm -rf "$WORK" "$CJ" "$BODY"' EXIT

# id of the first "cli-e2e" token row in the last-fetched /account page.
e2e_token_id() {
  tr '\n' ' ' < "$BODY" | sed 's/<tr>/\n<tr>/g' | grep 'cli-e2e' | head -1 \
    | grep -oE 'tokens/[0-9]+/revoke' | grep -oE '[0-9]+' | head -1
}
e2e_revoke_all() {
  local id
  for _ in $(seq 1 12); do
    rt_get /account >/dev/null
    id="$(e2e_token_id)"
    [ -n "$id" ] || break
    rt_hx_post "/account/tokens/$id/revoke" >/dev/null
  done
}

curl -fsS "$BASE/static/recurya" -o "$WORK/recurya" \
  && _ok "downloaded the client from $BASE/static/recurya" \
  || { _bad "downloaded the client from $BASE/static/recurya"; exit 1; }
chmod +x "$WORK/recurya"
cmp -s "$WORK/recurya" "$ROOT/resources/static/recurya" \
  && _ok "served client is identical to resources/static/recurya" \
  || { _bad "served client is identical to resources/static/recurya"; exit 1; }
CLI=("$WORK/recurya")
SLUG="cli-e2e-$(date +%s)"

echo "== setup: token and notebook =="
rt_reset_session; rt_login
e2e_revoke_all
rt_get /account >/dev/null
rt_hx_post /account/tokens 'name=cli-e2e' >/dev/null
TOKEN="$(grep -oE 'rcy_[0-9a-f]{64}' "$BODY" | head -1)"
[ -n "$TOKEN" ] && _ok "issued a token" || { _bad "issued a token"; exit 1; }
HANDLE="$(curl -s -H "Authorization: Bearer $TOKEN" "$BASE/api/v1/me" \
          | grep -oE '"handle":"[^"]+"' | cut -d'"' -f4)"
case "$HANDLE" in u-*|"") _bad "stub user has a real handle (got '$HANDLE')"; exit 1;; esac
rt_get /dashboard/notebooks/new >/dev/null
BODY_MD=$'===prose===\nCLI e2e\n\n===exercise: q===\n; replace with 3\n\n===expect===\n3\n\n===solution-locked: ans===\n(SECRET-ANSWER)'
rt_hx_post /dashboard/notebooks "title=CLI e2e" "slug=$SLUG" "summary=" \
  "body=$BODY_MD" "status=draft" "visibility=private" >/dev/null
echo "  notebook: @$HANDLE/$SLUG"
code=$(curl -s -o /dev/null -w '%{http_code}' -H "Authorization: Bearer $TOKEN" \
       "$BASE/api/v1/notebooks/$HANDLE/$SLUG")
rt_status 200 "$code" "owner can read the draft through the API"

echo "== CLI flow =="
cd "$WORK"
"${CLI[@]}" login --server "$BASE" --token "$TOKEN" && _ok "login" || _bad "login"
"${CLI[@]}" pull "@$HANDLE/$SLUG" nb && _ok "pull" || _bad "pull"
[ -f nb/01-exercise.wl ] && _ok "exercise file written" || _bad "exercise file written"
[ ! -f nb/02-solution.wl ] && _ok "locked solution not written" || _bad "locked solution not written"
grep -q "locked" nb/README.md && _ok "README marks the locked solution" || _bad "README marks the locked solution"
cd nb
"${CLI[@]}" run 01; [ $? -eq 1 ] && _ok "unedited exercise fails (exit 1)" || _bad "unedited exercise fails (exit 1)"
echo "3" > 01-exercise.wl
"${CLI[@]}" run 01; [ $? -eq 0 ] && _ok "edited exercise passes (exit 0)" || _bad "edited exercise passes (exit 0)"
grep -q "SECRET-ANSWER" 02-solution.wl && _ok "solution file unlocked" || _bad "solution file unlocked"
"${CLI[@]}" status | grep -q "passed" && _ok "status shows passed" || _bad "status shows passed"
cd "$ROOT"

echo "== browser side =="
rt_status 200 "$(rt_get "/@$HANDLE/$SLUG")" "notebook page renders for the owner"
rt_contains "SECRET-ANSWER" "page shows the solution unlocked by the CLI run"

echo "== cleanup =="
e2e_revoke_all
rt_get /account >/dev/null
[ -z "$(e2e_token_id)" ] && _ok "cli-e2e token revoked" || _bad "cli-e2e token revoked"

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
