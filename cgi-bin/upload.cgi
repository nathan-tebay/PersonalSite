#!/bin/sh
. /var/www/html/cgi-bin/session.sh
# CGI: upload an image for a blog post.
# POST fields: slug, filename, image_b64 (base64-encoded image data)
# Stores to blogs/<slug>/<filename> and caches locally.
# Returns: {"ok":true,"url":"/blog/posts/<slug>/<filename>"}

. /var/www/html/cgi-bin/storage.sh

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

if [ "$STORAGE" = "s3" ] && [ -z "$AWS_BUCKET" ]; then
  printf '\r\n{"error":"AWS_BUCKET not set"}\n'; exit 0
fi

POST_DATA=""
[ -n "$CONTENT_LENGTH" ] && POST_DATA=$(head -c "$CONTENT_LENGTH")

SLUG=$(get_field "$POST_DATA" slug     | tr -cd 'a-z0-9-')
FILENAME=$(get_field "$POST_DATA" filename | tr -cd 'a-zA-Z0-9._-')
IMAGE_B64=$(get_field "$POST_DATA" image_b64)

if [ -z "$SLUG" ] || [ -z "$FILENAME" ] || [ -z "$IMAGE_B64" ]; then
  printf '\r\n{"error":"slug, filename, and image_b64 are required"}\n'; exit 0
fi

# Detect content type from extension
case "$FILENAME" in
  *.jpg|*.jpeg) CT="image/jpeg" ;;
  *.png)        CT="image/png"  ;;
  *.gif)        CT="image/gif"  ;;
  *.webp)       CT="image/webp" ;;
  *)            CT="application/octet-stream" ;;
esac

# Decode base64 image to temp file
printf '%s' "$IMAGE_B64" | base64 -d > "$TMP_DIR/$FILENAME" 2>/dev/null || {
  printf '\r\n{"error":"base64 decode failed"}\n'; exit 0
}

storage_put "$SLUG/$FILENAME" "$TMP_DIR/$FILENAME" "$CT" || {
  printf '\r\n{"error":"upload failed"}\n'; exit 0
}

printf '\r\n{"ok":true,"url":"/blog/posts/%s/%s"}\n' "$SLUG" "$FILENAME"
