#!/bin/sh
# Container entrypoint.
# In S3 mode: performs a full initial sync from S3 before starting httpd so all
# content (manifests, post HTML, links) is available on the first request.
# A periodic background sync keeps content fresh every 10 minutes.
# In local mode: no sync — the mounted directory is used directly.

# /tmp is the only writable directory in Lambda.
# Copy the static web root there so httpd can serve blog/posts after writes.
cp -r /var/www/html/. /tmp/www/
mkdir -p /tmp/www/blog/posts

# Ensure CGI scripts are executable regardless of host filesystem permissions
chmod +x \
  /tmp/www/config.cgi \
  /tmp/www/cgi-bin/*.cgi \
  /tmp/www/cgi-bin/*.sh 2>/dev/null || true

if [ "${STORAGE:-s3}" = "s3" ]; then
  _region="${AWS_REGION:-us-east-1}"
  _endpoint_arg=""
  if [ -n "${MINIO_ENDPOINT:-}" ]; then
    _endpoint_arg="--endpoint-url ${MINIO_ENDPOINT}"
    # Create bucket if using a local MinIO endpoint (synchronous — needed before httpd)
    aws s3 mb "s3://${AWS_BUCKET}" --region "$_region" ${_endpoint_arg} 2>/dev/null || true
  fi

  # Full initial sync — runs synchronously so all content is ready before
  # the first request. links.json is fetched separately (not under blogs/).
  /usr/local/bin/sync-posts.sh
  aws s3 cp "s3://${AWS_BUCKET}/links.json" \
    /tmp/www/links.json \
    --region "$_region" ${_endpoint_arg} >/dev/null 2>&1 || true

  # Periodic refresh in the background.
  (
    while true; do
      sleep 600
      /usr/local/bin/sync-posts.sh
    done
  ) &
fi

exec "$@"
