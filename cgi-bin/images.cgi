#!/bin/sh
. /var/www/html/cgi-bin/session.sh
# CGI: list images for a blog post slug.
# GET param: ?slug=<slug>
# Returns: {"images":["file1.jpg","file2.png",...]}
# Reads from local cache (always in sync with S3 after upload).

. /var/www/html/cgi-bin/storage.sh

printf 'Content-Type: application/json\r\n'

SLUG=$(printf '%s' "${QUERY_STRING}" | tr '&' '\n' | grep '^slug=' | head -1 | cut -d= -f2- | tr -cd 'a-z0-9-')

if [ -z "$SLUG" ]; then
  printf '\r\n{"error":"slug required"}\n'; exit 0
fi

IMAGE_DIR="$LOCAL_DIR/$SLUG"
images=""

if [ -d "$IMAGE_DIR" ]; then
  for f in "$IMAGE_DIR"/*; do
    [ -f "$f" ] || continue
    case "$f" in *.html) continue ;; esac
    filename=$(basename "$f")
    if [ -z "$images" ]; then
      images='"'"$filename"'"'
    else
      images="$images,"'"'"$filename"'"'
    fi
  done
fi

printf '\r\n{"images":[%s]}\n' "$images"
