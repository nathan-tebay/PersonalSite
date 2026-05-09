#!/bin/sh
. /var/www/html/cgi-bin/session.sh
# CGI: load or save links.json.
# GET:  returns {"categories":[...],"links":[...]}
# POST: body is full JSON — saves to S3.

. /var/www/html/cgi-bin/common.sh
. /var/www/html/cgi-bin/storage.sh

emit_json_header

if [ "$REQUEST_METHOD" = "GET" ]; then
  printf '\r\n'
  if [ "$STORAGE" = "s3" ] && [ -n "${AWS_BUCKET:-}" ]; then
    _tmp_links="/tmp/links-$$.json"
    aws s3 cp "s3://${AWS_BUCKET}/links.json" "$_tmp_links" \
      --region "${AWS_REGION:-us-east-1}" \
      ${_aws_endpoint_arg} >/dev/null 2>&1 \
      && cat "$_tmp_links" \
      || printf '{"categories":[],"links":[]}\n'
    rm -f "$_tmp_links"
  elif [ -f "/tmp/www/links.json" ]; then
    cat "/tmp/www/links.json"
  else
    printf '{"categories":[],"links":[]}\n'
  fi
  exit 0
fi

if [ "$REQUEST_METHOD" != "POST" ]; then
  printf '\r\n{"error":"method not allowed"}\n'; exit 0
fi

# ── Rate limiting: max 15 saves per 60s per IP ────────────────────────
rate_limit_check "links_${REMOTE_ADDR}" 15 60 || emit_error "429 Too Many Requests" "rate limited"
# ──────────────────────────────────────────────────────────────────────

# ── CSRF verification ──────────────────────────────────────────────────
_verify_csrf || _fail_csrf
# ───────────────────────────────────────────────────────────────────────

POST_DATA=""
[ -n "$CONTENT_LENGTH" ] && POST_DATA=$(head -c "$CONTENT_LENGTH")

if [ -z "$POST_DATA" ]; then
  printf '\r\n{"error":"no data"}\n'; exit 0
fi

_tmp_links="/tmp/links-$$.json"
printf '%s\n' "$POST_DATA" > "$_tmp_links"

if [ "$STORAGE" = "s3" ] && [ -n "${AWS_BUCKET:-}" ]; then
  _out=$(aws s3 cp "$_tmp_links" "s3://${AWS_BUCKET}/links.json" \
    --content-type "application/json" \
    --region "${AWS_REGION:-us-east-1}" \
    ${_aws_endpoint_arg} 2>&1)
  _rc=$?
  echo "[links.cgi] aws s3 cp links.json rc=${_rc} out=${_out}" >&2
  rm -f "$_tmp_links"
  if [ "$_rc" != "0" ]; then
    printf '\r\n{"ok":false,"error":"s3 upload failed"}\n'
    exit 0
  fi
  cf_invalidate "/links.json"
else
  mv "$_tmp_links" "/tmp/www/links.json"
fi

printf '\r\n{"ok":true}\n'
