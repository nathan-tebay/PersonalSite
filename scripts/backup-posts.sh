#!/bin/bash
# Pull blog post HTML files from S3 into blog-posts/ for version tracking.
# Images are excluded (too large). Run from the repo root.
set -euo pipefail

BUCKET="ntebay-personal-site"
REGION="us-east-1"
DEST="${1:-blog-posts}"

mkdir -p "$DEST"

echo "Syncing blog post HTML from s3://$BUCKET/blog/posts/ -> $DEST/"
aws s3 sync "s3://$BUCKET/blog/posts/" "$DEST/" \
  --exclude "*" \
  --include "*.html" \
  --include "*.json" \
  --region "$REGION" \
  --delete

echo "Done. Posts in $DEST/:"
find "$DEST" -name "*.html" | sort
