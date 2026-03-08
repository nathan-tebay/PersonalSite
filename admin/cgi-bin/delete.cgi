#!/bin/sh
# CGI: delete a blog post (draft or published), its images, and remove it from both manifests.
# POST fields: slug

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

# Check whether any post file exists
if ! storage_exists "$SLUG/index.html" && ! storage_exists "$SLUG/draft.html"; then
  printf '\r\n{"error":"post not found"}\n'; exit 0
fi

# Delete entire slug directory — post files + all images
storage_rm_dir "$SLUG"

# ── Update manifests ──────────────────────────────────────────────────────────

storage_get "manifest-all.json" "$TMP_DIR/manifest-all.json" \
  || printf '[\n]\n' > "$TMP_DIR/manifest-all.json"

storage_get "manifest.json" "$TMP_DIR/manifest.json" \
  || printf '[\n]\n' > "$TMP_DIR/manifest.json"

manifest_remove "$TMP_DIR/manifest-all.json" "$SLUG"
manifest_remove "$TMP_DIR/manifest.json"     "$SLUG"

storage_put "manifest-all.json" "$TMP_DIR/manifest-all.json" "application/json"
storage_put "manifest.json"     "$TMP_DIR/manifest.json"     "application/json"

printf '\r\n{"ok":true}\n'
