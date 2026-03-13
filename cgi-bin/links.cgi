#!/bin/sh
. /var/www/html/cgi-bin/session.sh
# CGI: load or save links.json.
# GET:  returns {"categories":[...],"links":[...]}
# POST: body is full JSON — saves to local cache and S3.

. /var/www/html/cgi-bin/storage.sh

LOCAL_FILE="/tmp/www/links.json"

printf 'Content-Type: application/json\r\n'

if [ "$REQUEST_METHOD" = "GET" ]; then
  printf '\r\n'
  if [ -f "$LOCAL_FILE" ]; then
    cat "$LOCAL_FILE"
  elif [ "$STORAGE" = "s3" ] && [ -n "${AWS_BUCKET:-}" ]; then
    aws s3 cp "s3://${AWS_BUCKET}/links.json" "$LOCAL_FILE" \
      --region "${AWS_REGION:-us-east-1}" \
      ${_aws_endpoint_arg} >/dev/null 2>&1 \
      && cat "$LOCAL_FILE" \
      || printf '{"categories":[],"links":[]}\n'
  else
    printf '{"categories":[],"links":[]}\n'
  fi
  exit 0
fi

if [ "$REQUEST_METHOD" != "POST" ]; then
  printf '\r\n{"error":"method not allowed"}\n'; exit 0
fi

POST_DATA=""
[ -n "$CONTENT_LENGTH" ] && POST_DATA=$(head -c "$CONTENT_LENGTH")

if [ -z "$POST_DATA" ]; then
  printf '\r\n{"error":"no data"}\n'; exit 0
fi

printf '%s\n' "$POST_DATA" > "$LOCAL_FILE"

if [ "$STORAGE" = "s3" ] && [ -n "${AWS_BUCKET:-}" ]; then
  _out=$(aws s3 cp "$LOCAL_FILE" "s3://${AWS_BUCKET}/links.json" \
    --content-type "application/json" \
    --region "${AWS_REGION:-us-east-1}" \
    ${_aws_endpoint_arg} 2>&1)
  _rc=$?
  echo "[links.cgi] aws s3 cp links.json rc=${_rc} out=${_out}" >&2
  if [ "$_rc" != "0" ]; then
    printf '\r\n{"ok":false,"error":"s3 upload failed"}\n'
    exit 0
  fi
fi

printf '\r\n{"ok":true}\n'
