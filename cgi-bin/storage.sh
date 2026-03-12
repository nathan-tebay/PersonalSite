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
S3_PREFIX="s3://${AWS_BUCKET}/blogs"

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
    echo "[storage_put] aws s3 cp s3://${AWS_BUCKET}/blogs/${filename} rc=${_rc} out=${_out}" >&2
    [ "$_rc" = "0" ] || return 1
    # Mirror to local cache so the change is visible immediately
    mkdir -p "$(dirname "$LOCAL_DIR/$filename")"
    cp "$localfile" "$LOCAL_DIR/$filename" 2>/dev/null
  fi
}

# Download a file from storage to a local path. Returns non-zero on failure.
# Uses local cache when available to avoid redundant aws CLI invocations.
# storage_get <filename> <local_path>
storage_get() {
  local filename="$1" localfile="$2"
  if [ "$STORAGE" = "local" ]; then
    cp "$LOCAL_DIR/$filename" "$localfile" 2>/dev/null
  elif [ -f "$LOCAL_DIR/$filename" ]; then
    cp "$LOCAL_DIR/$filename" "$localfile"
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
    aws s3 rm "${S3_PREFIX}/${dir}" \
      --recursive \
      --region "${AWS_REGION:-us-east-1}" \
      ${_aws_endpoint_arg} >/dev/null 2>&1
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
    aws s3 mv "${S3_PREFIX}/${from}" "${S3_PREFIX}/${to}" \
      --region "${AWS_REGION:-us-east-1}" \
      ${_aws_endpoint_arg} >/dev/null 2>&1
    mkdir -p "$(dirname "$LOCAL_DIR/$to")"
    mv "$LOCAL_DIR/$from" "$LOCAL_DIR/$to" 2>/dev/null
  fi
}

# Return 0 if a file exists in storage, non-zero otherwise.
# storage_exists <filename>
storage_exists() {
  local filename="$1"
  [ -f "$LOCAL_DIR/$filename" ]
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
      local entry
      entry=$(printf '%s' "$line" | sed 's/^,*//')
      [ -z "$entry" ]    && continue
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
      local entry
      entry=$(printf '%s' "$line" | sed 's/^,*//')
      [ -z "$entry" ]    && continue
      case "$entry" in *'"slug":"'"$slug"'"'*) continue ;; esac
      [ "$first" = "1" ] && { printf '%s\n' "$entry"; first=0; } \
                         || printf ',%s\n' "$entry"
    done < "$file"
    [ "$first" = "1" ] && printf '%s\n' "$new_entry" \
                       || printf ',%s\n' "$new_entry"
    printf ']\n'
  } > "$tmp" && mv "$tmp" "$file"
}
