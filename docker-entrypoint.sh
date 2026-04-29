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

# ── httpd config with MIME types and caching ─────────────────────────────────
# busybox httpd does not support Cache-Control headers natively. In production
# CloudFront provides caching (TTL 1 year for versioned assets, 1 hour for HTML).
# We add a lightweight CGI wrapper that serves static assets with proper headers.
# For dev, we generate a cache-static.cgi that proxies static files with headers.
cat > /tmp/www/cgi-bin/cache-static.cgi <<'CGIEOF'
#!/bin/sh
# Lightweight static file server that adds Cache-Control headers.
# Called via: /cgi-bin/cache-static.cgi?path=/assets/style.css
. /var/www/html/cgi-bin/common.sh
QUERY_STRING="${QUERY_STRING:-}"
PATH_PARAM=$(get_field "$QUERY_STRING" path)
# Security: only serve from /tmp/www, no directory traversal
# Strip leading slashes, reject .. components, and ensure path starts with allowed prefix
PATH_PARAM=$(printf '%s' "$PATH_PARAM" | sed 's|^\(/*\)|/|')
case "$PATH_PARAM" in
  *..*) printf 'Status: 403 Forbidden\r\nContent-Type: text/plain\r\n\r\nForbidden'; exit 1 ;;
  /assets/*|/blog/posts/*|/*.html|/*.json|/*.xml|/*.svg|/*.png|/*.webp|/*.mp4|/*.css|/*.js) ;;
  *) printf 'Status: 403 Forbidden\r\nContent-Type: text/plain\r\n\r\nForbidden'; exit 1 ;;
esac
REAL_PATH="/tmp/www${PATH_PARAM}"
# Double-check resolved path is still under /tmp/www
case "$REAL_PATH" in
  /tmp/www/*) ;;
  *) printf 'Status: 403 Forbidden\r\nContent-Type: text/plain\r\n\r\nForbidden'; exit 1 ;;
esac
if [ ! -f "$REAL_PATH" ]; then
  printf 'Status: 404 Not Found\r\nContent-Type: text/plain\r\n\r\nNot Found'; exit 1
fi
# Determine content type and cache duration based on extension
case "$PATH_PARAM" in
  *.css|*.js|*.png|*.svg|*.webp|*.mp4) CACHE_MAX_AGE="31536000" ;;  # 1 year for static assets
  *.html) CACHE_MAX_AGE="3600" ;;                                   # 1 hour for HTML
  *.json|*.xml) CACHE_MAX_AGE="300" ;;                              # 5 min for data files
  *) CACHE_MAX_AGE="3600" ;;
esac
# Detect content type
case "$PATH_PARAM" in
  *.css) CT="text/css" ;; *.js) CT="application/javascript" ;;
  *.png) CT="image/png" ;; *.svg) CT="image/svg+xml" ;;
  *.webp) CT="image/webp" ;; *.mp4) CT="video/mp4" ;;
  *.html) CT="text/html" ;; *.json) CT="application/json" ;;
  *.xml) CT="application/xml" ;; *) CT="application/octet-stream" ;;
esac
printf "Content-Type: %s\r\nCache-Control: public, max-age=%s, s-max-age=%s\r\nVary: Accept-Encoding\r\n" "$CT" "$CACHE_MAX_AGE" "$CACHE_MAX_AGE"
emit_security_headers
printf '\r\n'
cat "$REAL_PATH"
CGIEOF
chmod +x /tmp/www/cgi-bin/cache-static.cgi

printf '.webp:image/webp\n.mp4:video/mp4\n.svg:image/svg+xml\n.json:application/json\n.xml:application/xml\n.css:text/css\n.js:application/javascript\n' > /etc/httpd.conf

exec "$@"
