#!/bin/sh
# Sync blog posts from S3 to the local cache directory.
# Uses aws s3 sync to pull any changes from S3 to LOCAL_DIR.

. /var/www/html/cgi-bin/storage.sh   # sets S3_PREFIX, LOCAL_DIR, _aws_endpoint_arg

[ "$STORAGE" != "s3" ] && exit 0

mkdir -p "$LOCAL_DIR"

echo "[sync] Syncing from S3..."
aws s3 sync "${S3_PREFIX}/" "$LOCAL_DIR/" \
  --region "${AWS_REGION:-us-east-1}" \
  ${_aws_endpoint_arg} 2>&1 \
  && echo "[sync] Sync complete." \
  || echo "[sync] Sync failed."
