#!/bin/sh
. /var/www/html/cgi-bin/session.sh
# CGI: upload an image for a blog post.
# POST fields: slug, filename, image_b64 or data (base64-encoded image)
# Content-Type: application/x-www-form-urlencoded

. /var/www/html/cgi-bin/common.sh
. /var/www/html/cgi-bin/storage.sh

TMP_DIR="/tmp/upload-$$"
mkdir -p "$TMP_DIR"
trap 'rm -rf "$TMP_DIR"' EXIT

emit_json_header

if [ "$REQUEST_METHOD" != "POST" ]; then
  printf '\r\n{"error":"method not allowed"}\n'; exit 0
fi

# ── Rate limiting: max 15 uploads per 60s per IP ──────────────────────
rate_limit_check "upload_${REMOTE_ADDR}" 15 60 || emit_error "429 Too Many Requests" "rate limited"
# ──────────────────────────────────────────────────────────────────────

# ── CSRF verification ──────────────────────────────────────────────────
_verify_csrf || _fail_csrf
# ───────────────────────────────────────────────────────────────────────

POST_DATA=""
[ -n "$CONTENT_LENGTH" ] && POST_DATA=$(head -c "$CONTENT_LENGTH")

SLUG=$(get_field "$POST_DATA" slug | tr -cd 'a-z0-9-')
FILENAME=$(get_field "$POST_DATA" filename | tr -cd 'a-zA-Z0-9._-')
IMAGEDATA=$(get_field "$POST_DATA" data)
[ -n "$IMAGEDATA" ] || IMAGEDATA=$(get_field "$POST_DATA" image_b64)

if [ -z "$SLUG" ] || [ -z "$FILENAME" ] || [ -z "$IMAGEDATA" ]; then
  printf '\r\n{"error":"slug, filename, and image data are required"}\n'; exit 0
fi

# ── Validate file extension (whitelist) ────────────────────────────────
_ext=$(printf '%s' "$FILENAME" | sed 's/.*\.//' | tr '[:upper:]' '[:lower:]')
case "$_ext" in
  jpg|jpeg|png|gif|webp|svg) ;;
  *) printf '\r\n{"error":"unsupported file type"}\n'; exit 0 ;;
esac
# ───────────────────────────────────────────────────────────────────────

# ── Decode base64 and check size (max 5MB) ────────────────────────────
printf '%s' "$IMAGEDATA" | base64 -d > "$TMP_DIR/image" 2>/dev/null || {
  printf '\r\n{"error":"invalid base64 data"}\n'; exit 0
}

_filesize=$(wc -c < "$TMP_DIR/image" 2>/dev/null || echo 0)
if [ "$_filesize" -gt 5242880 ]; then
  printf '\r\n{"error":"file too large (max 5MB)"}\n'; exit 0
fi
# ──────────────────────────────────────────────────────────────────────

# Determine content type from extension
case "$_ext" in
  jpg|jpeg) contenttype="image/jpeg" ;;
  png)      contenttype="image/png" ;;
  gif)      contenttype="image/gif" ;;
  webp)     contenttype="image/webp" ;;
  svg)      contenttype="image/svg+xml" ;;
  *)        contenttype="application/octet-stream" ;;
esac

storage_put "$SLUG/$FILENAME" "$TMP_DIR/image" "$contenttype" || {
  printf '\r\n{"error":"upload failed"}\n'; exit 0
}

printf '\r\n{"ok":true}\n'
