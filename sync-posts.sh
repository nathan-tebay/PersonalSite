#!/bin/sh
# Sync blog posts from S3 to the local cache directory.
# Uses mc diff to check whether anything has changed before downloading.
# Exits silently (exit 0) if no changes are detected.

. /var/www/html/admin/cgi-bin/storage.sh   # sets MC_PREFIX, LOCAL_DIR

[ "$STORAGE" != "s3" ] && exit 0

mkdir -p "$LOCAL_DIR"

# ── Check for changes ─────────────────────────────────────────────────────────
if ! mc diff "$MC_PREFIX/" "$LOCAL_DIR/" 2>/dev/null | grep -q .; then
  exit 0  # nothing changed
fi

# ── Sync ─────────────────────────────────────────────────────────────────────
echo "[sync] Changes detected; syncing..."
mc mirror --overwrite --remove "$MC_PREFIX/" "$LOCAL_DIR/" >/dev/null 2>&1 \
  && echo "[sync] Sync complete." \
  || echo "[sync] Sync failed."
