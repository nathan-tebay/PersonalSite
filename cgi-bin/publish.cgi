#!/bin/sh
. /var/www/html/cgi-bin/session.sh
# CGI: publish or unpublish a blog post.
# POST field: slug

. /var/www/html/cgi-bin/common.sh
. /var/www/html/cgi-bin/storage.sh

TMP_DIR="/tmp/blog-pub-$$"
mkdir -p "$TMP_DIR"
trap 'rm -rf "$TMP_DIR"' EXIT

emit_json_header

if [ "$REQUEST_METHOD" != "POST" ]; then
  printf '\r\n{"error":"method not allowed"}\n'; exit 0
fi

# ── Rate limiting: max 10 publishes per 60s per IP ─────────────────────
rate_limit_check "publish_${REMOTE_ADDR}" 10 60 || emit_error "429 Too Many Requests" "rate limited"
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

storage_get "manifest-all.json" "$TMP_DIR/manifest-all.json" \
  || printf '[\n]\n' > "$TMP_DIR/manifest-all.json"
storage_get "manifest.json" "$TMP_DIR/manifest.json" \
  || printf '[\n]\n' > "$TMP_DIR/manifest.json"

manifest_entry() {
  jq -c --arg slug "$SLUG" '.[] | select(.slug == $slug)' "$TMP_DIR/manifest-all.json" 2>/dev/null | head -1
}

write_manifest_all_state() {
  local published="$1" wip="$2"
  jq --arg slug "$SLUG" --argjson published "$published" --argjson wip "$wip" \
    'map(if .slug == $slug then .published = $published | .wip = $wip else . end)' \
    "$TMP_DIR/manifest-all.json" > "$TMP_DIR/manifest-all-next.json" \
    && mv "$TMP_DIR/manifest-all-next.json" "$TMP_DIR/manifest-all.json"
}

# Determine current state
IS_PUBLISHED="false"
storage_exists "$SLUG/index.html" && IS_PUBLISHED="true"
if [ "$IS_PUBLISHED" != "true" ] && ! storage_exists "$SLUG/draft.html"; then
  printf '\r\n{"error":"post not found"}\n'; exit 0
fi

if [ "$IS_PUBLISHED" = "true" ]; then
  _entry=$(manifest_entry)
  if [ -z "$_entry" ]; then
    printf '\r\n{"error":"manifest entry not found"}\n'; exit 0
  fi

  # Unpublish: move index.html -> draft.html
  storage_mv "$SLUG/index.html" "$SLUG/draft.html" || {
    printf '\r\n{"error":"rename failed"}\n'; exit 0
  }

  _wip=$(printf '%s' "$_entry" | jq -r '.wip // false' 2>/dev/null)
  [ "$_wip" = "true" ] || _wip="false"
  write_manifest_all_state false "$_wip" || {
    printf '\r\n{"error":"manifest update failed"}\n'; exit 0
  }

  _public_entry=$(manifest_entry | jq -c 'del(.published)' 2>/dev/null)
  if [ "$_wip" = "true" ] && [ -n "$_public_entry" ]; then
    manifest_upsert "$TMP_DIR/manifest.json" "$SLUG" "$_public_entry"
  else
    manifest_remove "$TMP_DIR/manifest.json" "$SLUG"
  fi

  storage_put "manifest-all.json" "$TMP_DIR/manifest-all.json" "application/json" || {
    printf '\r\n{"error":"manifest update failed"}\n'; exit 0
  }
  storage_put "manifest.json" "$TMP_DIR/manifest.json" "application/json" || {
    printf '\r\n{"error":"manifest update failed"}\n'; exit 0
  }
  printf '\r\n{"ok":true,"published":false}\n'
else
  _entry=$(manifest_entry)
  if [ -z "$_entry" ]; then
    printf '\r\n{"error":"manifest entry not found"}\n'; exit 0
  fi

  # Publish: move draft.html -> index.html
  storage_mv "$SLUG/draft.html" "$SLUG/index.html" || {
    printf '\r\n{"error":"rename failed"}\n'; exit 0
  }

  write_manifest_all_state true false || {
    printf '\r\n{"error":"manifest update failed"}\n'; exit 0
  }
  _public_entry=$(manifest_entry | jq -c 'del(.published)' 2>/dev/null)
  if [ -n "$_public_entry" ]; then
    manifest_upsert "$TMP_DIR/manifest.json" "$SLUG" "$_public_entry"
  fi

  storage_put "manifest-all.json" "$TMP_DIR/manifest-all.json" "application/json" || {
    printf '\r\n{"error":"manifest update failed"}\n'; exit 0
  }
  storage_put "manifest.json" "$TMP_DIR/manifest.json" "application/json" || {
    printf '\r\n{"error":"manifest update failed"}\n'; exit 0
  }
  printf '\r\n{"ok":true,"published":true}\n'
fi
