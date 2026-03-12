#!/bin/sh
. /var/www/html/cgi-bin/session.sh
# CGI: return manifest-all.json (all posts including drafts) for the admin UI.


. /var/www/html/cgi-bin/storage.sh

TMP_DIR="/tmp/blog-$$"
mkdir -p "$TMP_DIR"
trap 'rm -rf "$TMP_DIR"' EXIT

printf 'Content-Type: application/json\r\n'

storage_get "manifest-all.json" "$TMP_DIR/manifest-all.json" \
  || printf '[\n]\n' > "$TMP_DIR/manifest-all.json"

printf '\r\n'
cat "$TMP_DIR/manifest-all.json"
