#!/bin/sh
# Storage abstraction — source this from CGI scripts.
# Set STORAGE=local for local filesystem (dev), STORAGE=s3 (default) for AWS S3.
#
# Local mode: posts are read/written from LOCAL_DIR.
# S3 mode:    posts are read/written via AWS CLI (handles Lambda STS credentials
#             automatically via the standard AWS credential chain).
#
# Storage layout (both local and S3 mirror each other):
#   blogs/manifest.json          — public post list
#   blogs/manifest-all.json      — admin post list (includes drafts)
#   blogs/<slug>/draft.html      — draft post
#   blogs/<slug>/index.html      — published post
#   blogs/<slug>/<image>         — uploaded images for that post

STORAGE="${STORAGE:-s3}"
LOCAL_DIR="/tmp/www/blog/posts"

# S3 prefix for blog content
S3_PREFIX="s3://${AWS_BUCKET}/blog/posts"

# AWS CLI endpoint override for local MinIO dev
_aws_endpoint_arg=""
if [ -n "${MINIO_ENDPOINT:-}" ]; then
  _aws_endpoint_arg="--endpoint-url ${MINIO_ENDPOINT}"
fi

# ── Storage operations ────────────────────────────────────────────────────────

# Upload a local file to storage under filename (may include subdirectory).
# storage_put <filename> <local_path> [content-type]
storage_put() {
  local filename="$1" localfile="$2" contenttype="${3:-text/html}"
  if [ "$STORAGE" = "local" ]; then
    mkdir -p "$(dirname "$LOCAL_DIR/$filename")"
    cp "$localfile" "$LOCAL_DIR/$filename"
  else
    _out=$(aws s3 cp "$localfile" "${S3_PREFIX}/${filename}" \
      --content-type "$contenttype" \
      --region "${AWS_REGION:-us-east-1}" \
      ${_aws_endpoint_arg} 2>&1)
    _rc=$?
    echo "[storage_put] aws s3 cp s3://${AWS_BUCKET}/blog/posts/${filename} rc=${_rc} out=${_out}" >&2
    [ "$_rc" = "0" ] || return 1
  fi
}

# Download a file from storage to a local path. Returns non-zero on failure.
# Uses local cache when available to avoid redundant aws CLI invocations.
# storage_get <filename> <local_path>
storage_get() {
  local filename="$1" localfile="$2"
  if [ "$STORAGE" = "local" ]; then
    cp "$LOCAL_DIR/$filename" "$localfile" 2>/dev/null
  else
    aws s3 cp "${S3_PREFIX}/${filename}" "$localfile" \
      --region "${AWS_REGION:-us-east-1}" \
      ${_aws_endpoint_arg} >/dev/null 2>&1
  fi
}

# Delete a file from storage.
# storage_rm <filename>
storage_rm() {
  local filename="$1"
  if [ "$STORAGE" = "local" ]; then
    rm -f "$LOCAL_DIR/$filename"
  else
    aws s3 rm "${S3_PREFIX}/${filename}" \
      --region "${AWS_REGION:-us-east-1}" \
      ${_aws_endpoint_arg} >/dev/null 2>&1
  fi
}

# Delete an entire directory from storage (post dir including images).
# storage_rm_dir <dir>
storage_rm_dir() {
  local dir="$1"
  if [ "$STORAGE" = "local" ]; then
    rm -rf "$LOCAL_DIR/$dir"
  else
    aws s3 rm "${S3_PREFIX}/${dir}" \
      --recursive \
      --region "${AWS_REGION:-us-east-1}" \
      ${_aws_endpoint_arg} >/dev/null 2>&1
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
    aws s3 mv "${S3_PREFIX}/${from}" "${S3_PREFIX}/${to}" \
      --region "${AWS_REGION:-us-east-1}" \
      ${_aws_endpoint_arg} >/dev/null 2>&1
  fi
}

# Return 0 if a file exists in storage, non-zero otherwise.
# storage_exists <filename>
storage_exists() {
  local filename="$1"
  if [ "$STORAGE" = "local" ]; then
    [ -f "$LOCAL_DIR/$filename" ]
  else
    aws s3 ls "${S3_PREFIX}/${filename}" \
      --region "${AWS_REGION:-us-east-1}" \
      ${_aws_endpoint_arg} >/dev/null 2>&1
  fi
}

# Invalidate CloudFront paths after a write. No-op when CF_DIST_ID is unset.
# cf_invalidate <path> [<path> ...]
cf_invalidate() {
  [ -n "${CF_DIST_ID:-}" ] || return 0
  # Build JSON path list from all arguments
  _cf_items=""
  for _p in "$@"; do
    [ -n "$_cf_items" ] && _cf_items="${_cf_items},"
    _cf_items="${_cf_items}\"${_p}\""
  done
  _cf_qty=$#
  _cf_ref="inv-$$-$(date +%s)"
  aws cloudfront create-invalidation \
    --distribution-id "$CF_DIST_ID" \
    --invalidation-batch "{\"Paths\":{\"Quantity\":${_cf_qty},\"Items\":[${_cf_items}]},\"CallerReference\":\"${_cf_ref}\"}" \
    --region "${AWS_REGION:-us-east-1}" >/dev/null 2>&1 || true
}

# ── File locking (for manifest read-modify-write safety) ──────────────────────
#
# Simple advisory lock using /tmp lock files. Prevents concurrent CGI scripts
# from corrupting manifests when two requests hit simultaneously.
#
# _acquire_lock <lock_name> — blocks until lock acquired (max 10s)
_acquire_lock() {
  local _lock_file="/tmp/storage_lock_$1"
  local _tries=0
  while ! mkdir "$_lock_file" 2>/dev/null; do
    _tries=$((_tries + 1))
    [ "$_tries" -gt 100 ] && return 1  # timeout after ~10s
    sleep 0.1
  done
  # Store PID for debugging
  echo "$$" > "$_lock_file/pid"
}

# _release_lock <lock_name> — releases previously acquired lock
_release_lock() {
  local _lock_file="/tmp/storage_lock_$1"
  rm -rf "$_lock_file"
}

# ── JSON helpers ──────────────────────────────────────────────────────────────

# Escape a string for safe embedding in a JSON value.
# Handles backslashes, double quotes, newlines, tabs, and control characters.
json_escape() {
  if command -v jq >/dev/null 2>&1; then
    printf '%s' "$1" | jq -Rs . | sed 's/^"//; s/"$//' | tr -d '\n'
  elif command -v perl >/dev/null 2>&1; then
    printf '%s' "$1" | perl -pe '
      s/\\/\\\\/g;
      s/"/\\"/g;
      s/\n/\\n/g;
      s/\r/\\r/g;
      s/\t/\\t/g;
      s/([\x00-\x08\x0b\x0c\x0e-\x1f])/sprintf("\\u%04x", ord($1))/eg;
    '
  else
    printf '%s' "$1" | awk '
      {
        if (NR > 1) printf "\\n"
        for (i = 1; i <= length($0); i++) {
          c = substr($0, i, 1)
          if (c == "\\") printf "\\\\"
          else if (c == "\"") printf "\\\""
          else if (c == "\t") printf "\\t"
          else printf "%s", c
        }
      }'
  fi
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
  local file="$1" slug="$2" tmp="${1}.tmp" etmp="${1}.entries.tmp"
  local first=1
  if ! jq -c --arg slug "$slug" '.[] | select(.slug != $slug)' "$file" 2>/dev/null > "$etmp"; then
    local _sz; _sz=$(wc -c < "$file" 2>/dev/null || echo 0)
    [ "$_sz" -gt 4 ] && { rm -f "$etmp"; return 1; }
    > "$etmp"
  fi
  {
    printf '[\n'
    while IFS= read -r entry; do
      [ "$first" = "1" ] && { printf '%s\n' "$entry"; first=0; } \
                         || printf ',%s\n' "$entry"
    done < "$etmp"
    printf ']\n'
  } > "$tmp" && mv "$tmp" "$file"
  rm -f "$etmp"
}

# Add or replace the entry matching <slug> in a local manifest file (in-place).
# manifest_upsert <file> <slug> <json_entry>
manifest_upsert() {
  local file="$1" slug="$2" new_entry="$3" tmp="${1}.tmp" etmp="${1}.entries.tmp"
  local first=1
  if ! jq -c --arg slug "$slug" '.[] | select(.slug != $slug)' "$file" 2>/dev/null > "$etmp"; then
    local _sz; _sz=$(wc -c < "$file" 2>/dev/null || echo 0)
    [ "$_sz" -gt 4 ] && { rm -f "$etmp"; return 1; }
    > "$etmp"
  fi
  {
    printf '[\n'
    while IFS= read -r entry; do
      [ "$first" = "1" ] && { printf '%s\n' "$entry"; first=0; } \
                         || printf ',%s\n' "$entry"
    done < "$etmp"
    [ "$first" = "1" ] && printf '%s\n' "$new_entry" \
                       || printf ',%s\n' "$new_entry"
    printf ']\n'
  } > "$tmp" && mv "$tmp" "$file"
  rm -f "$etmp"
}
