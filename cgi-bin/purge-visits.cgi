#!/bin/sh
# Admin-only: remove all visit records for a given IP from analytics JSONL files.
. /var/www/html/cgi-bin/session.sh
. /var/www/html/cgi-bin/common.sh

[ "$REQUEST_METHOD" != "POST" ] && emit_error "405 Method Not Allowed" "POST required"

_verify_csrf || _fail_csrf

CONTENT_LENGTH="${CONTENT_LENGTH:-0}"
POST_DATA=""
[ "$CONTENT_LENGTH" -gt 0 ] && POST_DATA=$(head -c "$CONTENT_LENGTH")

PURGE_IP=$(get_field "$POST_DATA" "ip")
[ -z "$PURGE_IP" ] && emit_error "400 Bad Request" "ip required"

emit_json_header
printf '\r\n'

STORAGE="${STORAGE:-s3}"
ANALYTICS_DIR="/tmp/analytics"
AWS_REGION="${AWS_REGION:-us-east-1}"

_ep=""
[ -n "${MINIO_ENDPOINT:-}" ] && _ep="--endpoint-url ${MINIO_ENDPOINT}"

je() { printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g; s/\t/ /g; s/[[:cntrl:]]//g'; }

_REMOVED=0

_purge_local_file() {
  local file="$1"
  [ -f "$file" ] || return 0
  local before after tmp
  before=$(wc -l < "$file")
  tmp="${file}.purge.$$"
  grep -v "\"ip\":\"$(je "$PURGE_IP")\"" "$file" > "$tmp" 2>/dev/null || true
  after=$(wc -l < "$tmp")
  mv "$tmp" "$file"
  _REMOVED=$((_REMOVED + before - after))
}

_purge_s3_file() {
  local fname="$1"
  local tmp="/tmp/purge-$$-${fname}"
  aws s3 cp "s3://${AWS_BUCKET}/analytics/${fname}" "$tmp" \
    --region "$AWS_REGION" ${_ep} >/dev/null 2>&1 || return 0
  local before after
  before=$(wc -l < "$tmp")
  grep -v "\"ip\":\"$(je "$PURGE_IP")\"" "$tmp" > "${tmp}.new" 2>/dev/null || true
  after=$(wc -l < "${tmp}.new")
  mv "${tmp}.new" "$tmp"
  _REMOVED=$((_REMOVED + before - after))
  aws s3 cp "$tmp" "s3://${AWS_BUCKET}/analytics/${fname}" \
    --content-type "application/x-ndjson" \
    --region "$AWS_REGION" ${_ep} >/dev/null 2>&1 || true
  mkdir -p "$ANALYTICS_DIR"
  cp "$tmp" "$ANALYTICS_DIR/$fname" 2>/dev/null || true
  rm -f "$tmp"
}

CURRENT_MONTH=$(date -u '+%Y-%m')
_year=$(date -u '+%Y')
_mon=$(printf '%d' "$(date -u '+%m')")
if [ "$_mon" = "1" ]; then
  PREV_MONTH="$((_year-1))-12"
else
  PREV_MONTH="${_year}-$(printf '%02d' $((_mon-1)))"
fi

if [ "$STORAGE" = "local" ]; then
  _purge_local_file "$ANALYTICS_DIR/${PREV_MONTH}.jsonl"
  _purge_local_file "$ANALYTICS_DIR/${CURRENT_MONTH}.jsonl"
else
  _purge_s3_file "${PREV_MONTH}.jsonl"
  _purge_s3_file "${CURRENT_MONTH}.jsonl"
fi

printf '{"ok":true,"removed":%d}\n' "$_REMOVED"
