#!/bin/sh
# session.sh — source at the top of any admin CGI to enforce session auth.
# Validates the admin_session cookie against a server-side session file in
# /tmp/sessions/. Login generates a random opaque token; ADMIN_TOKEN never
# leaves the server. Redirects to login if the token is absent, invalid, or
# expired.

_SESSION_COOKIE_NAME="admin_session"
_CSRF_COOKIE_NAME="csrf_token"
_CSRF_HEADER="HTTP_X_CSRF_TOKEN"

# Session timeout: 24 hours in seconds
_SESSION_TIMEOUT=86400

# ── Cookie parsing ─────────────────────────────────────────────────────

# Extract the value of a named cookie from HTTP_COOKIE.
# Usage: _get_cookie <name>
_get_cookie() {
  printf '%s' "${HTTP_COOKIE:-}" \
    | tr ';' '\n' \
    | sed 's/^ *//' \
    | grep "^${1}=" \
    | head -1 \
    | cut -d= -f2-
}

# Extract the value of a named cookie, returning empty string if not found.
# Usage: _get_cookie_safe <name>
_get_cookie_safe() {
  _get_cookie "$1" 2>/dev/null || printf ''
}

# ── CSRF helpers ───────────────────────────────────────────────────────

# Generate a random CSRF token (32 hex chars).
_generate_csrf() {
  od -An -tx1 -N16 /dev/urandom | tr -d ' \n'
}

# Verify CSRF token from X-CSRF-Token header matches the csrf_token cookie.
# Returns 0 on success, 1 on failure.
_verify_csrf() {
  _csrf_cookie=$(_get_cookie "$_CSRF_COOKIE_NAME")
  eval "_csrf_header=\${$_CSRF_HEADER:-}"
  if [ -z "$_csrf_cookie" ] || [ -z "$_csrf_header" ]; then
    return 1
  fi
  [ "$_csrf_cookie" = "$_csrf_header" ]
}

# Emit a 403 CSRF failure and exit.
# Relies on emit_security_headers from common.sh (always sourced before this is called).
_fail_csrf() {
  printf 'Content-Type: application/json\r\nStatus: 403 Forbidden\r\n'
  emit_security_headers
  printf '\r\n'
  printf '{"error":"CSRF token mismatch"}\n'
  exit 0
}

# ── Session verification ───────────────────────────────────────────────
_SESSION_DIR="/tmp/sessions"

_token=$(_get_cookie "$_SESSION_COOKIE_NAME")
_NOW=$(date +%s)

# Reject tokens that are not exactly 64 lowercase hex chars (prevents path traversal)
_token_len=$(printf '%s' "${_token}" | wc -c)
case "${_token}" in
  *[^0-9a-f]*|"") _token_len=0 ;;
esac

if [ "$_token_len" != 64 ] || [ ! -f "${_SESSION_DIR}/${_token}" ]; then
  printf 'Status: 302 Found\r\nLocation: /cgi-bin/login.cgi\r\n\r\n'
  exit 0
fi

_session_created=$(cat "${_SESSION_DIR}/${_token}" 2>/dev/null || echo 0)
_ELAPSED=$((_NOW - _session_created))

if [ "$_ELAPSED" -gt "$_SESSION_TIMEOUT" ]; then
  rm -f "${_SESSION_DIR}/${_token}"
  find "$_SESSION_DIR" -maxdepth 1 -type f -mmin +1440 -delete 2>/dev/null || true
  SECURE_FLAG=""
  if [ "${HTTP_X_FORWARDED_PROTO:-}" = "https" ] || [ "${HTTPS:-}" = "on" ]; then
    SECURE_FLAG="; Secure"
  fi
  printf 'Status: 302 Found\r\n'
  printf 'Set-Cookie: admin_session=; Path=/; SameSite=Strict; Max-Age=0; HttpOnly%s\r\n' "$SECURE_FLAG"
  printf 'Set-Cookie: admin_ui=; Path=/; SameSite=Strict; Max-Age=0%s\r\n' "$SECURE_FLAG"
  printf 'Set-Cookie: csrf_token=; Path=/; SameSite=Strict; Max-Age=0%s\r\n' "$SECURE_FLAG"
  printf 'Location: /cgi-bin/login.cgi?expired=1\r\n\r\n'
  exit 0
fi

# Sliding window: update session file if more than 1 hour has passed
if [ "$_ELAPSED" -gt 3600 ]; then
  echo "$_NOW" > "${_SESSION_DIR}/${_token}"
fi
