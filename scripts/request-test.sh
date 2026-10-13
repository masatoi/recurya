#!/usr/bin/env bash
# scripts/request-test.sh --- Browserless HTTP request tests for the MPA + HTMX UI.
#
# A "request test" (a.k.a. functional test at the HTTP layer, like Rails
# request specs / Django's test client): it drives the running app the same way
# the browser does -- through the HTTP request/response cycle -- but WITHOUT a
# browser. It replays HTMX requests exactly (session cookie + CSRF token +
# `HX-Request: true`) and asserts on the returned HTML, both full pages and HTMX
# fragments. It also checks "both sides" of an HTMX wiring: the trigger's
# hx-target AND that the target element's id actually exists in the page.
#
# What this CAN verify: server-rendered HTML, HTMX wiring/contract, returned
# fragments, routing, session, CSRF, auth, data flow, multi-step flows.
# What it CANNOT verify (needs a browser/eyes): client-side JS behaviour
# (CodeMirror, buttons) and visual/CSS/layout correctness.
#
# Usage (server must be up; see docs/DEVELOPMENT.md):
#   ./scripts/request-test.sh
# Override the base URL with RT_BASE=http://host:port ./scripts/request-test.sh
#
# To verify a specific UI change, copy one of the check blocks at the bottom:
#   - GET the changed page, assert the elements / hx-* wiring (+ target ids).
#   - If it has an HTMX action, replay it with rt_hx_post and assert the fragment.
set -uo pipefail
BASE="${RT_BASE:-http://localhost:13000}"
CJ="$(mktemp)"     # cookie jar (session)
BODY="$(mktemp)"   # last response body (page or fragment)
trap 'rm -f "$CJ" "$BODY"' EXIT

PASS=0; FAIL=0
_ok()  { PASS=$((PASS+1)); printf '  \033[32mPASS\033[0m %s\n' "$1"; }
_bad() { FAIL=$((FAIL+1)); printf '  \033[31mFAIL\033[0m %s\n' "$1"; }

# --- HTTP primitives ---------------------------------------------------------

rt_reset_session() { : > "$CJ"; }   # start a fresh anonymous session

# rt_get PATH -> writes body to $BODY, echoes the HTTP status code.
rt_get() { curl -s -c "$CJ" -b "$CJ" -o "$BODY" -w '%{http_code}' "$BASE$1"; }

# rt_login -> log in via the dev OAuth stub (OAUTH_DEV_STUB), keeping the
# session cookie. Only needed for pages behind auth.
rt_login() { curl -s -c "$CJ" -b "$CJ" -L -o /dev/null "$BASE/auth/google/start"; }

# rt_csrf -> extract the _csrf_token value from the last GET body ($BODY).
rt_csrf() {
  tr '\n' ' ' < "$BODY" \
    | grep -oE 'name=_csrf_token[^>]*value=[^ >]+' \
    | grep -oE 'value=[^ >]+' | head -1 | cut -d= -f2
}

# rt_hx_post PATH [key=value ...] -> replay an HTMX POST. Sends HX-Request,
# the session cookie, the CSRF token (from the last GET), and each key=value
# field (URL-encoded; repeat a key like codes[] to send multiple values).
# Writes the returned fragment to $BODY, echoes the status code.
rt_hx_post() {
  local url="$1"; shift
  local token; token="$(rt_csrf)"
  local args=(-s -c "$CJ" -b "$CJ" -o "$BODY" -w '%{http_code}'
              -H 'HX-Request: true' --data-urlencode "_csrf_token=$token")
  local kv
  for kv in "$@"; do args+=(--data-urlencode "$kv"); done
  curl "${args[@]}" "$BASE$url"
}

# --- assertions (all operate on $BODY unless noted) --------------------------

rt_status()       { [ "$1" = "$2" ] && _ok "$3 (status $2)" || _bad "$3 (want $1, got $2)"; }
rt_contains()     { grep -qF -- "$1" "$BODY" && _ok "$2" || _bad "$2 (missing: $1)"; }
rt_not_contains() { grep -qF -- "$1" "$BODY" && _bad "$2 (unexpected: $1)" || _ok "$2"; }

# =============================================================================
# Checks. Add/adapt blocks here when a UI change lands.
# Run only when executed directly; `source scripts/request-test.sh` in another
# script to reuse the primitives (rt_get/rt_login/rt_csrf/rt_hx_post/rt_*)
# without running these checks.
# =============================================================================
[ "${BASH_SOURCE[0]}" = "${0}" ] || return 0

echo "request-test against $BASE"

echo "[public] GET /notebooks"
rt_status 200 "$(rt_get /notebooks)" "public notebooks listing renders"

echo "[404] unknown @handle"
rt_status 404 "$(rt_get /@no-such-user-xyz-000)" "unknown handle -> 404"
rt_contains "404" "404 page shows 404"

echo "[notebook] HTMX wiring both-sides (SICP notebook, seeded)"
rt_status 200 "$(rt_get /@recurya/sicp-1-1-1)" "SICP notebook page renders"
rt_contains 'hx-post="/@recurya/sicp-1-1-1/cells/1/run"' "cell 1 Run wired to its run endpoint"
rt_contains '#cell-1-result' "cell 1 targets #cell-1-result"
rt_contains 'id=cell-1-result' "target #cell-1-result exists in the page (both-sides)"
rt_contains 'id=csrf-form' "csrf-form present for hx-include"

echo "[htmx] replay cell-run and assert the result fragment"
rt_get /@recurya/sicp-1-1-1 >/dev/null   # refresh: session cookie + CSRF token
rt_status 200 "$(rt_hx_post /@recurya/sicp-1-1-1/cells/1/run 'codes[]=' 'codes[]=(+ 137 349)')" \
  "cell-run HTMX endpoint returns 200"
rt_contains "result-ok" "run fragment renders a result panel"
rt_contains "486" "run fragment shows the evaluated value (137+349=486)"
rt_contains "Fuel:" "run fragment shows the resource metrics line"

# rt_next_request_test_token_id -> id of the first "request-test" token row in
# the last-fetched /account page ($BODY), or empty.
rt_next_request_test_token_id() {
  tr '\n' ' ' < "$BODY" | sed 's/<tr>/\n<tr>/g' | grep 'request-test' | head -1 \
    | grep -oE 'tokens/[0-9]+/revoke' | grep -oE '[0-9]+' | head -1
}

echo "== /account API tokens (logged in via dev stub) =="
rt_reset_session; rt_login
# Self-cleaning: revoke leftover "request-test" tokens (e.g. from an aborted
# run) so this block never runs into the 10-active-token cap.
for _ in $(seq 1 12); do
  rt_get /account >/dev/null
  id="$(rt_next_request_test_token_id)"
  [ -n "$id" ] || break
  rt_hx_post "/account/tokens/$id/revoke" >/dev/null
done
rt_status 200 "$(rt_get /account)" "account page renders"
rt_contains 'hx-post="/account/tokens"' "token form posts via HTMX"
rt_contains '#api-tokens' "token form targets #api-tokens"
rt_contains 'id=api-tokens' "target #api-tokens exists (both-sides)"
rt_status 200 "$(rt_hx_post /account/tokens 'name=request-test')" "create token fragment"
rt_contains 'id=api-tokens' "fragment is the #api-tokens section"
grep -qE 'rcy_[0-9a-f]{64}' "$BODY" && _ok "fragment shows the new token once" \
  || _bad "fragment shows the new token once"
TOKEN="$(grep -oE 'rcy_[0-9a-f]{64}' "$BODY" | head -1)"
code=$(curl -s -o "$BODY" -w '%{http_code}' -H "Authorization: Bearer $TOKEN" "$BASE/api/v1/me")
rt_status 200 "$code" "the new token authenticates /api/v1/me"
rt_contains '"handle"' "/api/v1/me returns the handle"
# /api runs without the session middleware: no cookie is issued (and no
# sessions row written), even for an authenticated call.
if curl -s -D - -o /dev/null -H "Authorization: Bearer $TOKEN" "$BASE/api/v1/me" \
     | grep -qi '^set-cookie:'; then
  _bad "/api/v1/me sets no session cookie"
else
  _ok "/api/v1/me sets no session cookie"
fi
code=$( { printf '{"codes": ["'; head -c 1100000 /dev/zero | tr '\0' 'a'; printf '"]}'; } \
       | curl -s -o "$BODY" -w '%{http_code}' -X POST -H "Authorization: Bearer $TOKEN" \
              -H 'Content-Type: application/json' --data-binary @- \
              "$BASE/api/v1/notebooks/recurya/sicp-1-1-1/cells/0/run")
rt_status 413 "$code" "an API body over 1 MiB is refused"
rt_contains 'payload_too_large' "413 carries the payload_too_large code"
# Revoke the token this block issued and prove revocation end-to-end.
PREFIX="${TOKEN:0:12}"
rt_get /account >/dev/null
grep -qF "$PREFIX" "$BODY" && _ok "issued token is listed by its prefix" \
  || _bad "issued token is listed by its prefix"
id="$(rt_next_request_test_token_id)"
rt_status 200 "$(rt_hx_post "/account/tokens/$id/revoke")" "revoke token fragment"
rt_not_contains "$PREFIX" "revoke fragment no longer lists the token"
code=$(curl -s -o "$BODY" -w '%{http_code}' -H "Authorization: Bearer $TOKEN" "$BASE/api/v1/me")
rt_status 401 "$code" "the revoked token is rejected by /api/v1/me"

echo
echo "=== request-test: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ]
