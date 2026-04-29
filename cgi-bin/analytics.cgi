#!/bin/sh
# Admin-only analytics endpoint — returns visit data as JSON.
. /var/www/html/cgi-bin/session.sh
. /var/www/html/cgi-bin/common.sh

emit_json_header
printf '\r\n'

STORAGE="${STORAGE:-s3}"
ANALYTICS_DIR="/tmp/analytics"
AWS_REGION="${AWS_REGION:-us-east-1}"

_ep=""
[ -n "${MINIO_ENDPOINT:-}" ] && _ep="--endpoint-url ${MINIO_ENDPOINT}"

# ── Compute current and previous month ────────────────────────────────────
CURRENT_MONTH=$(date -u '+%Y-%m')
_year=$(date -u '+%Y')
_mon=$(printf '%d' "$(date -u '+%m')")
if [ "$_mon" = "1" ]; then
  PREV_MONTH="$((_year-1))-12"
else
  PREV_MONTH="${_year}-$(printf '%02d' $((_mon-1)))"
fi

TMPFILE="/tmp/analytics-all-$$"
touch "$TMPFILE"

# ── Fetch a month's JSONL into TMPFILE ────────────────────────────────────
fetch_month() {
  local month="$1" fname="${1}.jsonl"
  if [ "$STORAGE" = "local" ]; then
    [ -f "$ANALYTICS_DIR/$fname" ] && cat "$ANALYTICS_DIR/$fname" >> "$TMPFILE"
    return
  fi
  # S3: check local cache first (written by track.cgi), else fetch
  if [ -f "$ANALYTICS_DIR/$fname" ]; then
    cat "$ANALYTICS_DIR/$fname" >> "$TMPFILE"
  else
    local tmp="/tmp/analytics-month-$$-${month}"
    aws s3 cp "s3://${AWS_BUCKET}/analytics/${fname}" "$tmp" \
      --region "$AWS_REGION" ${_ep} >/dev/null 2>&1 && cat "$tmp" >> "$TMPFILE" || true
    rm -f "$tmp"
  fi
}

fetch_month "$PREV_MONTH"
fetch_month "$CURRENT_MONTH"

# ── Return last 2000 visits as JSON array ─────────────────────────────────
printf '{"visits":['
tail -n 2000 "$TMPFILE" | awk 'BEGIN{n=0}/^\{/{if(n>0)printf ",";printf "%s",$0;n++}'
printf ']}'

rm -f "$TMPFILE"
