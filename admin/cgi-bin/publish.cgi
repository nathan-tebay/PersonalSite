#!/bin/sh
# CGI: toggle the published state of a post by renaming its file.
# POST fields: slug
# Returns: {"ok":true,"published":true|false}
# Draft:     blogs/<slug>/draft.html
# Published: blogs/<slug>/index.html

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

if [ "$STORAGE" = "s3" ] && [ -z "$AWS_BUCKET" ]; then
  printf '\r\n{"error":"AWS_BUCKET not set"}\n'; exit 0
fi

POST_DATA=""
[ -n "$CONTENT_LENGTH" ] && POST_DATA=$(head -c "$CONTENT_LENGTH")

SLUG=$(get_field "$POST_DATA" slug | tr -cd 'a-z0-9-')

if [ -z "$SLUG" ]; then
  printf '\r\n{"error":"slug required"}\n'; exit 0
fi

# Determine current state by checking which filename exists
if storage_exists "$SLUG/index.html"; then
  # Currently published → unpublish (rename to draft)
  storage_mv "$SLUG/index.html" "$SLUG/draft.html" || {
    printf '\r\n{"error":"rename failed"}\n'; exit 0
  }
  NEW_PUBLISHED="false"
elif storage_exists "$SLUG/draft.html"; then
  # Currently draft → publish (rename to published)
  storage_mv "$SLUG/draft.html" "$SLUG/index.html" || {
    printf '\r\n{"error":"rename failed"}\n'; exit 0
  }
  NEW_PUBLISHED="true"
else
  printf '\r\n{"error":"post not found"}\n'; exit 0
fi

OLD_PUBLISHED="true"
[ "$NEW_PUBLISHED" = "true" ] && OLD_PUBLISHED="false"

# ── Update manifests ──────────────────────────────────────────────────────────

storage_get "manifest-all.json" "$TMP_DIR/manifest-all.json" \
  || printf '[\n]\n' > "$TMP_DIR/manifest-all.json"

storage_get "manifest.json" "$TMP_DIR/manifest.json" \
  || printf '[\n]\n' > "$TMP_DIR/manifest.json"

# Flip the published field in manifest-all (each entry is one line)
sed "/\"slug\":\"$SLUG\"/s/\"published\":$OLD_PUBLISHED/\"published\":$NEW_PUBLISHED/" \
  "$TMP_DIR/manifest-all.json" > "$TMP_DIR/manifest-all.tmp" \
  && mv "$TMP_DIR/manifest-all.tmp" "$TMP_DIR/manifest-all.json"

if [ "$NEW_PUBLISHED" = "true" ]; then
  # Add to public manifest: strip the "published" field from the all-manifest entry
  PUB_ENTRY=$(grep '"slug":"'"$SLUG"'"' "$TMP_DIR/manifest-all.json" \
    | sed 's/,"published":[a-z]*//')
  manifest_upsert "$TMP_DIR/manifest.json" "$SLUG" "$PUB_ENTRY"
else
  manifest_remove "$TMP_DIR/manifest.json" "$SLUG"
fi

storage_put "manifest-all.json" "$TMP_DIR/manifest-all.json" "application/json"
storage_put "manifest.json"     "$TMP_DIR/manifest.json"     "application/json"

printf '\r\n{"ok":true,"published":%s}\n' "$NEW_PUBLISHED"
