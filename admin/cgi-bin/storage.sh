#!/bin/sh
# Storage abstraction — source this from CGI scripts.
# Set STORAGE=local for local filesystem (dev), STORAGE=s3 (default) for AWS S3.
#
# Local mode: posts are read/written from LOCAL_DIR (mounted at run time).
# S3 mode:    posts are read/written via mc (mc alias "s3r" configured at
#             container start by docker-entrypoint.sh).
#
# Storage layout (both local and S3 mirror each other):
#   blogs/manifest.json          — public post list
#   blogs/manifest-all.json      — admin post list (includes drafts)
#   blogs/<slug>/draft.html      — draft post
#   blogs/<slug>/index.html      — published post
#   blogs/<slug>/<image>         — uploaded images for that post

STORAGE="${STORAGE:-s3}"
LOCAL_DIR="/var/www/html/blog/posts"

# mc path prefix: s3r/<bucket>/blogs
MC_PREFIX="s3r/${AWS_BUCKET}/blogs"

# ── Storage operations ────────────────────────────────────────────────────────

# Upload a local file to storage under filename (may include subdirectory).
# storage_put <filename> <local_path> [content-type]
storage_put() {
  local filename="$1" localfile="$2" contenttype="${3:-text/html}"
  if [ "$STORAGE" = "local" ]; then
    mkdir -p "$(dirname "$LOCAL_DIR/$filename")"
    cp "$localfile" "$LOCAL_DIR/$filename"
  else
    mc cp --attr "Content-Type=$contenttype" "$localfile" "$MC_PREFIX/$filename" >/dev/null 2>&1
    # Mirror to local cache so the change is visible immediately
    mkdir -p "$(dirname "$LOCAL_DIR/$filename")"
    cp "$localfile" "$LOCAL_DIR/$filename" 2>/dev/null
  fi
}

# Download a file from storage to a local path. Returns non-zero on failure.
# storage_get <filename> <local_path>
storage_get() {
  local filename="$1" localfile="$2"
  if [ "$STORAGE" = "local" ]; then
    cp "$LOCAL_DIR/$filename" "$localfile" 2>/dev/null
  else
    mc cp "$MC_PREFIX/$filename" "$localfile" >/dev/null 2>&1
  fi
}

# Delete a file from storage.
# storage_rm <filename>
storage_rm() {
  local filename="$1"
  if [ "$STORAGE" = "local" ]; then
    rm -f "$LOCAL_DIR/$filename"
  else
    mc rm "$MC_PREFIX/$filename" >/dev/null 2>&1
    rm -f "$LOCAL_DIR/$filename"
  fi
}

# Delete an entire directory from storage (post dir including images).
# storage_rm_dir <dir>
storage_rm_dir() {
  local dir="$1"
  if [ "$STORAGE" = "local" ]; then
    rm -rf "$LOCAL_DIR/$dir"
  else
    mc rm --recursive --force "$MC_PREFIX/$dir" >/dev/null 2>&1
    rm -rf "$LOCAL_DIR/$dir"
  fi
}

# Move/rename a file within storage.
# storage_mv <from_filename> <to_filename>
storage_mv() {
  local from="$1" to="$2"
  if [ "$STORAGE" = "local" ]; then
    mkdir -p "$(dirname "$LOCAL_DIR/$to")"
    mv "$LOCAL_DIR/$from" "$LOCAL_DIR/$to" 2>/dev/null
  else
    mc mv "$MC_PREFIX/$from" "$MC_PREFIX/$to" >/dev/null 2>&1
    mkdir -p "$(dirname "$LOCAL_DIR/$to")"
    mv "$LOCAL_DIR/$from" "$LOCAL_DIR/$to" 2>/dev/null
  fi
}

# Return 0 if a file exists in storage, non-zero otherwise.
# storage_exists <filename>
storage_exists() {
  local filename="$1"
  if [ "$STORAGE" = "local" ]; then
    [ -f "$LOCAL_DIR/$filename" ]
  else
    mc ls "$MC_PREFIX/$filename" >/dev/null 2>&1
  fi
}

# ── JSON helpers ──────────────────────────────────────────────────────────────

# Escape backslashes and double-quotes for embedding in a JSON string.
json_escape() {
  printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

# ── Manifest helpers (operate on local temp files) ────────────────────────────
#
# Manifest line format — one JSON object per line, no trailing commas:
#   [
#   {"slug":"hello","title":"Hello","date":"2024-01-01","desc":"..."}
#   ,{"slug":"world","title":"World","date":"2024-01-02","desc":"..."}
#   ]

# Remove the entry matching <slug> from a local manifest file (in-place).
# manifest_remove <file> <slug>
manifest_remove() {
  local file="$1" slug="$2" tmp="${1}.tmp"
  local first=1
  {
    printf '[\n'
    while IFS= read -r line; do
      [ "$line" = "[" ]  && continue
      [ "$line" = "]" ]  && continue
      [ -z "$line" ]     && continue
      local entry="${line#,}"
      case "$entry" in *'"slug":"'"$slug"'"'*) continue ;; esac
      [ "$first" = "1" ] && { printf '%s\n' "$entry"; first=0; } \
                         || printf ',%s\n' "$entry"
    done < "$file"
    printf ']\n'
  } > "$tmp" && mv "$tmp" "$file"
}

# Add or replace the entry matching <slug> in a local manifest file (in-place).
# manifest_upsert <file> <slug> <json_entry>
manifest_upsert() {
  local file="$1" slug="$2" new_entry="$3" tmp="${1}.tmp"
  local first=1
  {
    printf '[\n'
    while IFS= read -r line; do
      [ "$line" = "[" ]  && continue
      [ "$line" = "]" ]  && continue
      [ -z "$line" ]     && continue
      local entry="${line#,}"
      case "$entry" in *'"slug":"'"$slug"'"'*) continue ;; esac
      [ "$first" = "1" ] && { printf '%s\n' "$entry"; first=0; } \
                         || printf ',%s\n' "$entry"
    done < "$file"
    [ "$first" = "1" ] && printf '%s\n' "$new_entry" \
                       || printf ',%s\n' "$new_entry"
    printf ']\n'
  } > "$tmp" && mv "$tmp" "$file"
}
