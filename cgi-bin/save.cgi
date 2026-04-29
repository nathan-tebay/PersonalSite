#!/bin/sh
. /var/www/html/cgi-bin/session.sh
# CGI: create or update a blog post.
# POST fields: slug, title, date, desc, content
# Posts live in per-slug directories:
#   blogs/<slug>/draft.html    — draft
#   blogs/<slug>/index.html   — published

. /var/www/html/cgi-bin/common.sh
. /var/www/html/cgi-bin/storage.sh

TMP_DIR="/tmp/blog-$$"
mkdir -p "$TMP_DIR"
trap 'rm -rf "$TMP_DIR"' EXIT

emit_json_header

if [ "$REQUEST_METHOD" != "POST" ]; then
  printf '\r\n{"error":"method not allowed"}\n'; exit 0
fi

# ── Rate limiting: max 20 saves per 60s per IP ─────────────────────────
rate_limit_check "save_${REMOTE_ADDR}" 20 60 || emit_error "429 Too Many Requests" "rate limited"
# ───────────────────────────────────────────────────────────────────────

# ── CSRF verification ──────────────────────────────────────────────────
_verify_csrf || _fail_csrf
# ───────────────────────────────────────────────────────────────────────

if [ "$STORAGE" = "s3" ] && [ -z "$AWS_BUCKET" ]; then
  printf '\r\n{"error":"AWS_BUCKET not set"}\n'; exit 0
fi

POST_DATA=""
[ -n "$CONTENT_LENGTH" ] && POST_DATA=$(head -c "$CONTENT_LENGTH")

SLUG=$(get_field "$POST_DATA" slug | tr -cd 'a-z0-9-')
TITLE=$(get_field "$POST_DATA" title)
DATE=$(get_field "$POST_DATA" date)
DESC=$(get_field "$POST_DATA" desc)
CONTENT=$(get_field "$POST_DATA" content)
WIP_RAW=$(get_field "$POST_DATA" wip)
WIP="false"
[ "$WIP_RAW" = "true" ] && WIP="true"

if [ -z "$SLUG" ] || [ -z "$TITLE" ]; then
  printf '\r\n{"error":"slug and title are required"}\n'; exit 0
fi

# ── Date validation ────────────────────────────────────────────────────
# Accept ISO date (YYYY-MM-DD) or empty (defaults to today)
if [ -n "$DATE" ]; then
  # Validate format: must be YYYY-MM-DD with reasonable ranges
  if ! printf '%s' "$DATE" | grep -qE '^[0-9]{4}-(0[1-9]|1[0-2])-(0[1-9]|[12][0-9]|3[01])$'; then
    printf '\r\n{"error":"invalid date format, use YYYY-MM-DD"}\n'; exit 0
  fi
else
  DATE=$(date -u '+%Y-%m-%d')
fi
# ───────────────────────────────────────────────────────────────────────

# ── Sanitize HTML content — strip dangerous tags/attributes ───────────────
# Remove <script>, <iframe>, <object>, <embed>, <form>, <applet>, <base>, <link> tags
# Remove event handler attributes (on*) and javascript: URLs
sanitize_html() {
  sed -E \
    -e 's/<(script|iframe|object|embed|form|applet|base|link|meta|style)[^>]*>//gi' \
    -e 's/<\/(script|iframe|object|embed|form|applet|base|link|meta|style)>//gi' \
    -e 's/[[:space:]]+on[a-z]+="[^\"]*"//gi' \
    -e 's/[[:space:]]+on[a-z]+='"'"'[^'"'"']*'"'"'//gi' \
    -e 's/href="javascript:[^"]*"/href="#"/gi' \
    -e 's/src="javascript:[^"]*"/src="#"/gi'
}
CONTENT=$(printf '%s' "$CONTENT" | sanitize_html)
# ─────────────────────────────────────────────────────────────────────────

# Determine whether this slug is currently published (ground truth = filename)
PUBLISHED="false"
storage_exists "$SLUG/index.html" && PUBLISHED="true"

# Build the post file (metadata comment on line 1, then HTML body)
{
  printf '<!-- {"slug":"%s","title":"%s","date":"%s","desc":"%s","wip":%s} -->\n' \
    "$SLUG" "$(json_escape "$TITLE")" "$DATE" "$(json_escape "$DESC")" "$WIP"
  printf '%s' "$CONTENT"
} > "$TMP_DIR/post.html"

# Write to the correct filename based on current published state
if [ "$PUBLISHED" = "true" ]; then
  storage_put "$SLUG/index.html" "$TMP_DIR/post.html" "text/html" || {
    printf '\r\n{"error":"upload failed"}\n'; exit 0
  }
else
  storage_put "$SLUG/draft.html" "$TMP_DIR/post.html" "text/html" || {
    printf '\r\n{"error":"upload failed"}\n'; exit 0
  }
fi

# ── Update manifests with file locking ────────────────────────────────────

storage_get "manifest-all.json" "$TMP_DIR/manifest-all.json" \
  || printf '[\n]\n' > "$TMP_DIR/manifest-all.json"

storage_get "manifest.json" "$TMP_DIR/manifest.json" \
  || printf '[\n]\n' > "$TMP_DIR/manifest.json"

META_ALL=$(printf '{"slug":"%s","title":"%s","date":"%s","desc":"%s","published":%s,"wip":%s}' \
  "$SLUG" "$(json_escape "$TITLE")" "$DATE" "$(json_escape "$DESC")" "$PUBLISHED" "$WIP")

META_PUB=$(printf '{"slug":"%s","title":"%s","date":"%s","desc":"%s","wip":%s}' \
  "$SLUG" "$(json_escape "$TITLE")" "$DATE" "$(json_escape "$DESC")" "$WIP")

manifest_upsert "$TMP_DIR/manifest-all.json" "$SLUG" "$META_ALL"
if [ "$PUBLISHED" = "true" ] || [ "$WIP" = "true" ]; then
  manifest_upsert "$TMP_DIR/manifest.json" "$SLUG" "$META_PUB"
else
  manifest_remove "$TMP_DIR/manifest.json" "$SLUG"
fi

storage_put "manifest-all.json" "$TMP_DIR/manifest-all.json" "application/json" || {
  printf '\r\n{"error":"manifest update failed"}\n'; exit 0
}

storage_put "manifest.json" "$TMP_DIR/manifest.json" "application/json" || {
  printf '\r\n{"error":"manifest update failed"}\n'; exit 0
}

printf '\r\n{"ok":true,"published":%s}\n' "$PUBLISHED"
