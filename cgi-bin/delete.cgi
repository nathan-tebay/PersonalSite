#!/bin/sh
. /var/www/html/cgi-bin/session.sh
# CGI: delete a blog post.
# POST field: slug

. /var/www/html/cgi-bin/common.sh
. /var/www/html/cgi-bin/storage.sh

TMP_DIR="/tmp/blog-del-$$"
mkdir -p "$TMP_DIR"
trap 'rm -rf "$TMP_DIR"' EXIT

emit_json_header

if [ "$REQUEST_METHOD" != "POST" ]; then
  printf '\r\n{"error":"method not allowed"}\n'; exit 0
fi

# ── Rate limiting: max 10 deletes per 60s per IP ───────────────────────
rate_limit_check "delete_${REMOTE_ADDR}" 10 60 || emit_error "429 Too Many Requests" "rate limited"
# ───────────────────────────────────────────────────────────────────────

# ── CSRF verification ──────────────────────────────────────────────────
_verify_csrf || _fail_csrf
# ───────────────────────────────────────────────────────────────────────

POST_DATA=""
[ -n "$CONTENT_LENGTH" ] && POST_DATA=$(head -c "$CONTENT_LENGTH")

SLUG=$(get_field "$POST_DATA" slug | tr -cd 'a-z0-9-')

if [ -z "$SLUG" ]; then
  printf '\r\n{"error":"slug is required"}\n'; exit 0
fi

# Delete the post directory (includes draft.html, index.html, images)
storage_rm_dir "$SLUG"

# ── Update manifests ────────────────────────────────────────────────────

storage_get "manifest-all.json" "$TMP_DIR/manifest-all.json" \
  || printf '[\n]\n' > "$TMP_DIR/manifest-all.json"

storage_get "manifest.json" "$TMP_DIR/manifest.json" \
  || printf '[\n]\n' > "$TMP_DIR/manifest.json"

# Remove entry from manifest by slug
remove_entry() {
  local file="$1" slug="$2"
  local tmp="$TMP_DIR/filter_$$_${RANDOM}"
  grep -v "\"slug\":\"$slug\"" "$file" > "$tmp" 2>/dev/null || true
  cp "$tmp" "$file"
  rm -f "$tmp"
}

remove_entry "$TMP_DIR/manifest-all.json" "$SLUG"
remove_entry "$TMP_DIR/manifest.json" "$SLUG"

storage_put "manifest-all.json" "$TMP_DIR/manifest-all.json" "application/json" || {
  printf '\r\n{"error":"manifest update failed"}\n'; exit 0
}

storage_put "manifest.json" "$TMP_DIR/manifest.json" "application/json" || {
  printf '\r\n{"error":"manifest update failed"}\n'; exit 0
}

printf '\r\n{"ok":true}\n'
