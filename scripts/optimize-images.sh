#!/bin/bash
# Optimize blog post images: resize to max 1200px, convert to WebP, upload to S3,
# update HTML references in the local blog-posts/ backup, re-upload HTML.
#
# Usage: ./scripts/optimize-images.sh [slug]
#   slug  — only process a single post (e.g. my-post-slug). Omit to process all.
set -euo pipefail

BUCKET="ntebay-personal-site"
REGION="us-east-1"
BACKUP="$(dirname "$0")/../blog-posts"
WORKDIR="/tmp/img-optimize-$$"
mkdir -p "$WORKDIR"
trap 'rm -rf "$WORKDIR"' EXIT

SLUG_FILTER="${1:-}"

echo "Downloading images from S3..."
if [ -n "$SLUG_FILTER" ]; then
  aws s3 sync "s3://$BUCKET/blog/posts/$SLUG_FILTER/" "$WORKDIR/$SLUG_FILTER/" \
    --exclude "*" --include "*.png" --include "*.jpg" --include "*.jpeg" \
    --region "$REGION"
else
  aws s3 sync "s3://$BUCKET/blog/posts/" "$WORKDIR/" \
    --exclude "*" --include "*.png" --include "*.jpg" --include "*.jpeg" \
    --region "$REGION"
fi

echo ""
echo "Converting to WebP (max 1200px, q85)..."
find "$WORKDIR" -type f \( -name "*.png" -o -name "*.jpg" -o -name "*.jpeg" \) | while read src; do
  dir=$(dirname "$src")
  base=$(basename "$src")
  stem="${base%.*}"
  out="$dir/${stem}.webp"
  magick "$src" -resize '1200x1200>' -quality 85 "$out"
  orig=$(wc -c < "$src")
  new=$(wc -c < "$out")
  echo "  $base → ${stem}.webp  ($(( (orig - new) * 100 / orig ))% smaller)"
done

echo ""
echo "Uploading WebP files..."
find "$WORKDIR" -name "*.webp" | while read f; do
  rel="${f#$WORKDIR/}"
  aws s3 cp "$f" "s3://$BUCKET/blog/posts/$rel" \
    --content-type image/webp --region "$REGION" --quiet
  echo "  uploaded: $rel"
done

echo ""
echo "Removing old source images from S3..."
find "$WORKDIR" -type f \( -name "*.png" -o -name "*.jpg" -o -name "*.jpeg" \) | while read f; do
  rel="${f#$WORKDIR/}"
  aws s3 rm "s3://$BUCKET/blog/posts/$rel" --region "$REGION" --quiet
  echo "  deleted: $rel"
done

echo ""
echo "Updating .png/.jpg/.jpeg → .webp refs in blog-posts/ HTML backup..."
find "$BACKUP" -name "*.html" -exec sed -i \
  -e 's/\.\(png\|jpg\|jpeg\)\b/.webp/g' {} \;

echo ""
echo "Re-uploading updated HTML to S3..."
if [ -n "$SLUG_FILTER" ]; then
  HTML_FILES=$(find "$BACKUP/$SLUG_FILTER" -name "*.html" 2>/dev/null || true)
else
  HTML_FILES=$(find "$BACKUP" -name "*.html")
fi
echo "$HTML_FILES" | while read f; do
  [ -z "$f" ] && continue
  slug=$(basename "$(dirname "$f")")
  fname=$(basename "$f")
  aws s3 cp "$f" "s3://$BUCKET/blog/posts/$slug/$fname" \
    --content-type text/html --region "$REGION" --quiet
  echo "  $slug/$fname"
done

echo ""
echo "Invalidating CloudFront..."
CF=$(aws cloudfront list-distributions \
  --query "DistributionList.Items[?Origins.Items[?DomainName.contains(@,'ntebay-personal-site')]].Id|[0]" \
  --output text 2>/dev/null || true)
if [ -n "$CF" ] && [ "$CF" != "None" ]; then
  aws cloudfront create-invalidation \
    --distribution-id "$CF" \
    --invalidation-batch "{\"Paths\":{\"Quantity\":1,\"Items\":[\"/blog/posts/*\"]},\"CallerReference\":\"opt-$(date +%s)\"}" \
    --region us-east-1 --output json | jq -r '"  status: " + .Invalidation.Status'
fi

echo ""
echo "Done."
