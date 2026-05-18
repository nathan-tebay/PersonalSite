#!/bin/sh
# common.sh — shared CGI utilities. Source this from any CGI script.
# Provides: urldecode, get_field, emit_json_header, emit_error, emit_security_headers, rate_limit_check

# ── URL decoding ──────────────────────────────────────────────────────

# Safely decode percent-encoded strings without shell injection risks.
# Only interprets %XX as valid hex bytes; leaves invalid sequences intact.
# Uses perl when available (more reliable), falls back to awk.
urldecode() {
  if command -v perl >/dev/null 2>&1; then
    printf '%s' "$1" | perl -pe 's/\+/ /g; s/%([0-9a-fA-F]{2})/chr(hex($1))/ge'
  else
    printf '%s' "$1" | awk '
      function hexval(c) {
        c = tolower(c)
        return index("0123456789abcdef", c) - 1
      }
      {
        out = ""
        for (i = 1; i <= length($0); i++) {
          c = substr($0, i, 1)
          if (c == "+") {
            out = out " "
          } else if (c == "%" && i + 2 <= length($0) && substr($0, i + 1, 2) ~ /^[0-9A-Fa-f][0-9A-Fa-f]$/) {
            code = hexval(substr($0, i + 1, 1)) * 16 + hexval(substr($0, i + 2, 1))
            out = out sprintf("%c", code)
            i += 2
          } else {
            out = out c
          }
        }
        printf "%s", out
      }'
  fi
}

# ── Form field extraction ─────────────────────────────────────────────

# Extract a named field from an application/x-www-form-urlencoded body.
# Usage: get_field "<body>" "<field_name>"
get_field() {
  local raw
  raw=$(printf '%s' "$1" | tr '&' '\n' | grep "^${2}=" | head -1 | cut -d= -f2-)
  urldecode "$raw"
}

# ── HTTP helpers ──────────────────────────────────────────────────────

# Emit security headers (CSP, HSTS, X-Frame-Options, etc.)
# Usage: emit_security_headers
emit_security_headers() {
  printf 'X-Content-Type-Options: nosniff\r\n'
  printf 'X-Frame-Options: DENY\r\n'
  printf 'X-XSS-Protection: 1; mode=block\r\n'
  printf 'Referrer-Policy: strict-origin-when-cross-origin\r\n'
  printf 'Permissions-Policy: geolocation=(), microphone=(), camera=()\r\n'
  printf 'Content-Security-Policy: default-src '\''self'\''; script-src '\''self'\''; style-src '\''self'\'' '\''unsafe-inline'\''; img-src '\''self'\'' data: blob:; connect-src '\''self'\''; frame-ancestors '\''none'\''; base-uri '\''self'\''; form-action '\''self'\''; object-src '\''none'\''\r\n'
  if [ "${HTTP_X_FORWARDED_PROTO:-}" = "https" ] || [ "${HTTPS:-}" = "on" ]; then
    printf 'Strict-Transport-Security: max-age=31536000; includeSubDomains\r\n'
  fi
}

# Emit JSON content-type header with security headers (with optional status).
# Usage: emit_json_header [status_code]
emit_json_header() {
  printf 'Content-Type: application/json\r\n'
  printf 'Status: %s\r\n' "${1:-200 OK}"
  emit_security_headers
}

# Emit a JSON error response and exit.
# Usage: emit_error "<status>" "<message>"
emit_error() {
  printf 'Content-Type: application/json\r\nStatus: %s\r\n' "$1"
  emit_security_headers
  printf '\r\n'
  printf '{"error":"%s"}\n' "$2"
  exit 0
}

# ── Rate limiting ─────────────────────────────────────────────────────

# Generic rate limiter: max $RATE_LIMIT_COUNT attempts per $RATE_LIMIT_WINDOW seconds.
# Usage: rate_limit_check <identifier> <max_count> <window_seconds>
# Returns 0 (allowed) or 1 (blocked). Sets RATE_BLOCKED=1 if blocked.
rate_limit_cleanup() {
  find /tmp -maxdepth 1 -name 'rate_limit_*' -mmin +10 -delete 2>/dev/null || true
  find /tmp -maxdepth 1 -name 'login_rate_*' -mmin +5 -delete 2>/dev/null || true
  find /tmp -maxdepth 1 -name 'track_rate_*' -mmin +2 -delete 2>/dev/null || true
}

rate_limit_check() {
  local _rl_id="$1" _rl_limit="$2" _rl_window="$3"
  local _rl_file="/tmp/rate_limit_${_rl_id//[^a-z0-9]/_}"
  local _rl_now=$(date +%s)
  RATE_BLOCKED=0
  rate_limit_cleanup

  if [ -f "$_rl_file" ]; then
    local _rl_first=$(head -1 "$_rl_file" 2>/dev/null)
    local _rl_count=$(wc -l < "$_rl_file" 2>/dev/null)
    if [ "$((_rl_now - _rl_first))" -lt "$_rl_window" ] 2>/dev/null && [ "${_rl_count:-0}" -ge "$_rl_limit" ]; then
      RATE_BLOCKED=1
      return 1
    fi
    # Rotate: remove entries outside the window
    awk -v now="$_rl_now" -v window="$_rl_window" 'now - $1 < window { print }' "$_rl_file" > "${_rl_file}.tmp" 2>/dev/null
    mv "${_rl_file}.tmp" "$_rl_file" 2>/dev/null
  fi

  echo "$_rl_now" >> "$_rl_file" 2>/dev/null

  return 0
}
