#!/bin/sh
. /var/www/html/cgi-bin/session.sh
# CGI: upload an image for a blog post.
# Query params: slug, filename
# Body: raw binary image data

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

# Read slug and filename from query string (no POST body parsing needed)
SLUG=$(printf '%s' "${QUERY_STRING}" | tr '&' '\n' | grep '^slug=' | head -1 | cut -d= -f2- | tr -cd 'a-z0-9-')
_raw_filename=$(printf '%s' "${QUERY_STRING}" | tr '&' '\n' | grep '^filename=' | head -1 | cut -d= -f2-)
FILENAME=$(urldecode "$_raw_filename" | tr -cd 'a-zA-Z0-9._-')

if [ -z "$SLUG" ] || [ -z "$FILENAME" ]; then
  printf '\r\n{"error":"slug and filename are required"}\n'; exit 0
fi

# ── Validate file extension (whitelist) ────────────────────────────────
_ext=$(printf '%s' "$FILENAME" | sed 's/.*\.//' | tr '[:upper:]' '[:lower:]')
case "$_ext" in
  jpg|jpeg|png|gif|webp|svg) ;;
  *) printf '\r\n{"error":"unsupported file type"}\n'; exit 0 ;;
esac
# ───────────────────────────────────────────────────────────────────────

# ── Read raw binary body directly to file — no shell variable ─────────
if [ -n "$CONTENT_LENGTH" ] && [ "$CONTENT_LENGTH" -gt 0 ] 2>/dev/null; then
  head -c "$CONTENT_LENGTH" > "$TMP_DIR/image"
else
  cat > "$TMP_DIR/image"
fi

_filesize=$(wc -c < "$TMP_DIR/image" 2>/dev/null || echo 0)
if [ "$_filesize" -gt 5242880 ]; then
  printf '\r\n{"error":"file too large (max 5MB)"}\n'; exit 0
fi
if [ "$_filesize" -eq 0 ]; then
  printf '\r\n{"error":"empty file"}\n'; exit 0
fi
# ──────────────────────────────────────────────────────────────────────

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
