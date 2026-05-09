#!/bin/sh
. /var/www/html/cgi-bin/session.sh
# CGI: delete an image from a blog post.
# POST fields: slug, filename

. /var/www/html/cgi-bin/common.sh
. /var/www/html/cgi-bin/storage.sh

emit_json_header

if [ "$REQUEST_METHOD" != "POST" ]; then
  printf '\r\n{"error":"method not allowed"}\n'; exit 0
fi

# ── Rate limiting: max 10 deletes per 60s per IP ──────────────────────
rate_limit_check "delimg_${REMOTE_ADDR}" 10 60 || emit_error "429 Too Many Requests" "rate limited"
# ──────────────────────────────────────────────────────────────────────

# ── CSRF verification ──────────────────────────────────────────────────
_verify_csrf || _fail_csrf
# ───────────────────────────────────────────────────────────────────────

POST_DATA=""
[ -n "$CONTENT_LENGTH" ] && POST_DATA=$(head -c "$CONTENT_LENGTH")

SLUG=$(get_field "$POST_DATA" slug | tr -cd 'a-z0-9-')
FILENAME=$(get_field "$POST_DATA" filename | tr -cd 'a-zA-Z0-9._-')

if [ -z "$SLUG" ] || [ -z "$FILENAME" ]; then
  printf '\r\n{"error":"slug and filename are required"}\n'; exit 0
fi

storage_rm "$SLUG/$FILENAME"
cf_invalidate "/blog/posts/$SLUG/$FILENAME"

printf '\r\n{"ok":true}\n'
