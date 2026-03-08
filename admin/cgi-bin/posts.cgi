#!/bin/sh
# CGI: return manifest-all.json (all posts including drafts) for the admin UI.
# Protected by /admin/cgi-bin/.htpasswd — not directly accessible without credentials.

. /var/www/html/admin/cgi-bin/storage.sh

TMP_DIR="/tmp/blog-$$"
mkdir -p "$TMP_DIR"
trap 'rm -rf "$TMP_DIR"' EXIT

printf 'Content-Type: application/json\r\n'

storage_get "manifest-all.json" "$TMP_DIR/manifest-all.json" \
  || printf '[\n]\n' > "$TMP_DIR/manifest-all.json"

printf '\r\n'
cat "$TMP_DIR/manifest-all.json"
