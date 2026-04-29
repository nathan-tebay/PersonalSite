#!/bin/sh
# session.sh — source at the top of any admin CGI to enforce session auth.
# ADMIN_TOKEN must be set to SHA-256(password) — computed once offline:
#   printf 'yourpassword' | sha256sum | cut -d' ' -f1
# The token is never stored in plaintext; the env var holds only the hash.
# Redirects to the login page and exits if the cookie is absent or invalid.

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
_fail_csrf() {
  printf 'Content-Type: application/json\r\nStatus: 403 Forbidden\r\n'
  printf 'X-Content-Type-Options: nosniff\r\n'
  printf 'X-Frame-Options: DENY\r\n'
  printf 'X-XSS-Protection: 1; mode=block\r\n'
  printf 'Referrer-Policy: strict-origin-when-cross-origin\r\n'
  printf 'Permissions-Policy: geolocation=(), microphone=(), camera=()\r\n'
  printf 'Content-Security-Policy: default-src '\''self'\''; frame-ancestors none\r\n'
  printf '\r\n'
  printf '{"error":"CSRF token mismatch"}\n'
  exit 0
}

# ── Session verification ───────────────────────────────────────────────

_token=$(_get_cookie "$_SESSION_COOKIE_NAME")

if [ -z "$ADMIN_TOKEN" ] || [ "$_token" != "$ADMIN_TOKEN" ]; then
  printf 'Status: 302 Found\r\nLocation: /cgi-bin/login.cgi\r\n\r\n'
  exit 0
fi

# ── Session timeout check ──────────────────────────────────────────────
# We embed the session creation timestamp in a second cookie (_session_ts)
# so that timeouts work reliably even across container restarts or Lambda
# cold starts where /tmp is ephemeral.
_SESSION_TS_COOKIE="_session_ts"
_session_ts=$(_get_cookie_safe "$_SESSION_TS_COOKIE")
_NOW=$(date +%s)

if [ -n "$_session_ts" ] && [ "$_session_ts" -gt 0 ] 2>/dev/null; then
  _ELAPSED=$((_NOW - _session_ts))
  if [ "$_ELAPSED" -gt "$_SESSION_TIMEOUT" ]; then
    # Session expired — clear cookies and redirect to login
    SECURE_FLAG=""
    if [ "${HTTP_X_FORWARDED_PROTO:-}" = "https" ] || [ "${HTTPS:-}" = "on" ]; then
      SECURE_FLAG="; Secure"
    fi
    printf 'Status: 302 Found\r\n'
    printf 'Set-Cookie: admin_session=; Path=/%s; SameSite=Strict; Max-Age=0; HttpOnly\r\n' "$SECURE_FLAG"
    printf 'Set-Cookie: csrf_token=; Path=/; SameSite=Strict; Max-Age=0%s\r\n' "$SECURE_FLAG"
    printf 'Set-Cookie: _session_ts=; Path=/; SameSite=Strict; Max-Age=0%s\r\n' "$SECURE_FLAG"
    printf 'Location: /cgi-bin/login.cgi?expired=1\r\n\r\n'
    exit 0
  fi
  # Sliding window: refresh timestamp if more than 1 hour has passed
  if [ "$_ELAPSED" -gt 3600 ]; then
    export _SESSION_TS_REFRESH="$_NOW"
  fi
else
  # First request without timestamp cookie — this is an older session;
  # we allow it but note that login.cgi should set _session_ts going forward.
  export _SESSION_TS_REFRESH="$_NOW"
fi
