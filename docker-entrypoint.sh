#!/bin/sh
# Container entrypoint.
# In S3 mode: performs an initial sync from S3, then starts a background loop
# that checks for changes every 10 minutes (using s3:ListBucket) and syncs
# only when the remote listing differs from the local cache.
# In local mode: no sync — the mounted directory is used directly.
# Passes all arguments through to exec (i.e. the CMD: httpd ...).

# Ensure CGI scripts are executable regardless of host filesystem permissions
chmod +x \
  /var/www/html/config.cgi \
  /var/www/html/admin/cgi-bin/save.cgi \
  /var/www/html/admin/cgi-bin/delete.cgi \
  /var/www/html/admin/cgi-bin/publish.cgi \
  /var/www/html/admin/cgi-bin/posts.cgi \
  /var/www/html/admin/cgi-bin/upload.cgi \
  /var/www/html/admin/cgi-bin/images.cgi \
  /var/www/html/admin/cgi-bin/delete-image.cgi \
  /var/www/html/admin/cgi-bin/storage.sh 2>/dev/null || true

if [ "${STORAGE:-s3}" = "s3" ]; then
  # Configure mc alias — points at MinIO in dev, AWS S3 in production
  _endpoint="${MINIO_ENDPOINT:-https://s3.${AWS_REGION:-us-east-1}.amazonaws.com}"
  mc alias set s3r "$_endpoint" "${AWS_ACCESS_KEY_ID}" "${AWS_SECRET_ACCESS_KEY}" \
    --api S3v4 >/dev/null 2>&1

  # Create bucket if using a local MinIO endpoint
  if [ -n "${MINIO_ENDPOINT:-}" ]; then
    mc mb "s3r/${AWS_BUCKET}" 2>/dev/null || true
  fi

  echo "[sync] Initial sync from S3..."
  /usr/local/bin/sync-posts.sh && echo "[sync] Done." || echo "[sync] Initial sync failed — starting anyway."

  # Background sync loop: check every 10 minutes
  (
    while true; do
      sleep 600
      /usr/local/bin/sync-posts.sh
    done
  ) &
fi

exec "$@"
