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
FILTERED_FILE="/tmp/analytics-filtered-$$"
touch "$TMPFILE"

# ── Fetch a month's JSONL into TMPFILE ────────────────────────────────────
fetch_month() {
  local month="$1" fname="${1}.jsonl"
  if [ "$STORAGE" = "local" ]; then
    [ -f "$ANALYTICS_DIR/$fname" ] && cat "$ANALYTICS_DIR/$fname" >> "$TMPFILE"
    return
  fi
  # S3: always fetch from S3 — Lambda containers don't share /tmp
  local tmp="/tmp/analytics-month-$$-${month}"
  aws s3 cp "s3://${AWS_BUCKET}/analytics/${fname}" "$tmp" \
    --region "$AWS_REGION" ${_ep} >/dev/null 2>&1 && cat "$tmp" >> "$TMPFILE" || true
  rm -f "$tmp"
}

fetch_month "$PREV_MONTH"
fetch_month "$CURRENT_MONTH"

# ── Ignore likely bot rows, including historical records already stored ─────
awk '
  function likely_bot(line, ua, lower) {
    ua = line
    sub(/^.*"ua":"/, "", ua)
    sub(/","country":.*$/, "", ua)
    lower = tolower(ua)
    return lower == "" || lower ~ /(bot|crawl|spider|slurp|bingpreview|facebookexternalhit|embedly|quora link preview|pinterest|preview|validator|lighthouse|pagespeed|uptimerobot|statuscake|pingdom|monitoring|curl|wget|python-requests|go-http-client|httpclient|java\/|libwww|php\/|axios|node-fetch|okhttp|headlesschrome|phantomjs|playwright|puppeteer|semrush|ahrefs|mj12bot|dotbot|petalbot|bytespider|gptbot|chatgpt-user|claudebot|anthropic-ai|perplexitybot)/
  }
  /^\{/ && !likely_bot($0) { print }
' "$TMPFILE" > "$FILTERED_FILE"

# ── Return last 2000 non-bot visits as JSON array ───────────────────────────
printf '{"visits":['
tail -n 2000 "$FILTERED_FILE" | awk 'BEGIN{n=0}/^\{/{if(n>0)printf ",";printf "%s",$0;n++}'
printf ']}'

rm -f "$TMPFILE" "$FILTERED_FILE"
