#!/bin/sh
# CGI: create or update a blog post.
# POST fields: slug, title, date, desc, content
# Posts live in per-slug directories:
#   blogs/<slug>/draft.html    — draft
#   blogs/<slug>/index.html   — published

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

# ── Update manifests ──────────────────────────────────────────────────────────

storage_get "manifest-all.json" "$TMP_DIR/manifest-all.json" \
  || printf '[\n]\n' > "$TMP_DIR/manifest-all.json"

storage_get "manifest.json" "$TMP_DIR/manifest.json" \
  || printf '[\n]\n' > "$TMP_DIR/manifest.json"

META_ALL=$(printf '{"slug":"%s","title":"%s","date":"%s","desc":"%s","published":%s,"wip":%s}' \
  "$SLUG" "$(json_escape "$TITLE")" "$DATE" "$(json_escape "$DESC")" "$PUBLISHED" "$WIP")

META_PUB=$(printf '{"slug":"%s","title":"%s","date":"%s","desc":"%s","wip":%s}' \
  "$SLUG" "$(json_escape "$TITLE")" "$DATE" "$(json_escape "$DESC")" "$WIP")

manifest_upsert "$TMP_DIR/manifest-all.json" "$SLUG" "$META_ALL"

# Published posts and WIP posts both appear in the public manifest
if [ "$PUBLISHED" = "true" ] || [ "$WIP" = "true" ]; then
  manifest_upsert "$TMP_DIR/manifest.json" "$SLUG" "$META_PUB"
else
  manifest_remove "$TMP_DIR/manifest.json" "$SLUG"
fi

storage_put "manifest-all.json" "$TMP_DIR/manifest-all.json" "application/json" || {
  printf '\r\n{"error":"manifest-all upload failed"}\n'; exit 0
}
storage_put "manifest.json" "$TMP_DIR/manifest.json" "application/json" || {
  printf '\r\n{"error":"manifest upload failed"}\n'; exit 0
}

printf '\r\n{"ok":true,"published":%s}\n' "$PUBLISHED"
