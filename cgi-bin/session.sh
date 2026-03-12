#!/bin/sh
# session.sh — source at the top of any admin CGI to enforce session auth.
# ADMIN_TOKEN must be set to SHA-256(password) — computed once offline:
#   printf 'yourpassword' | sha256sum | cut -d' ' -f1
# The token is never stored in plaintext; the env var holds only the hash.
# Redirects to the login page and exits if the cookie is absent or invalid.

_session_cookie() {
  printf '%s' "${HTTP_COOKIE:-}" \
    | tr ';' '\n' \
    | sed 's/^ *//' \
    | grep '^admin_session=' \
    | head -1 \
    | cut -d= -f2-
}

_token=$(_session_cookie)

if [ -z "$ADMIN_TOKEN" ] || [ "$_token" != "$ADMIN_TOKEN" ]; then
  printf 'Status: 302 Found\r\nLocation: /cgi-bin/login.cgi\r\n\r\n'
  exit 0
fi
