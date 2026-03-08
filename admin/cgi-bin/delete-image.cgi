#!/bin/sh
# CGI: delete an image from a blog post's directory.
# POST fields: slug, filename
# Returns: {"ok":true}

. /var/www/html/admin/cgi-bin/storage.sh

TMP_DIR="/tmp/blog-$$"
mkdir -p "$TMP_DIR"
trap 'rm -rf "$TMP_DIR"' EXIT

urldecode() {
  printf '%b' "$(printf '%s' "$1" | sed 's/+/ /g; s/%/\\x/g')"
}

get_field() {
  local raw
  raw=$(printf '%s' "$1" | tr '&' '\n' | grep "^${2}=" | head -1 | cut -d= -f2-)
  urldecode "$raw"
}

printf 'Content-Type: application/json\r\n'

if [ "$REQUEST_METHOD" != "POST" ]; then
  printf '\r\n{"error":"method not allowed"}\n'; exit 0
fi

POST_DATA=""
[ -n "$CONTENT_LENGTH" ] && POST_DATA=$(head -c "$CONTENT_LENGTH")

SLUG=$(get_field "$POST_DATA" slug     | tr -cd 'a-z0-9-')
FILENAME=$(get_field "$POST_DATA" filename | tr -cd 'a-zA-Z0-9._-')

if [ -z "$SLUG" ] || [ -z "$FILENAME" ]; then
  printf '\r\n{"error":"slug and filename are required"}\n'; exit 0
fi

storage_rm "$SLUG/$FILENAME"

printf '\r\n{"ok":true}\n'
