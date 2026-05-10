#!/bin/sh
# Public beacon — log page visit (IP, geo, page, referrer, UA).
# Called via navigator.sendBeacon from every page load.

. /var/www/html/cgi-bin/common.sh

# ── Rate limiting: max 30 beacons per 60s per IP ───────────────────────
if ! rate_limit_check "track_${REMOTE_ADDR}" 30 60; then
  emit_json_header
  printf '\r\n{"ok":true}\n'
  exit 0
fi
# ──────────────────────────────────────────────────────────────────────

emit_json_header
printf '\r\n'

STORAGE="${STORAGE:-s3}"
ANALYTICS_DIR="/tmp/analytics"
AWS_REGION="${AWS_REGION:-us-east-1}"

POST_DATA=""
[ -n "$CONTENT_LENGTH" ] && POST_DATA=$(head -c "$CONTENT_LENGTH")

PAGE=$(get_field "$POST_DATA" page | cut -c1-200)
REF=$(get_field "$POST_DATA" ref | cut -c1-200)

# ── IP (honour proxy header from Lambda/CloudFront) ────────────────────────
IP="${HTTP_X_FORWARDED_FOR:-${REMOTE_ADDR:-}}"
IP=$(printf '%s' "$IP" | cut -d',' -f1 | tr -d ' ')
GEO_IP="$IP"  # keep full IP for geo lookup; truncate only for storage

# ── Timestamp / JSONL filename ────────────────────────────────────────────
TS=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
MONTH=$(date -u '+%Y-%m')
FILENAME="${MONTH}.jsonl"

# ── Geo lookup with caching (skip private/local IPs) ──────────────────────
COUNTRY="" CC="" REGION="" CITY=""
_priv=0
case "$GEO_IP" in
  127.*|10.*|192.168.*|::1|"") _priv=1 ;;
  172.*)
    _oct2=$(printf '%s' "$GEO_IP" | cut -d'.' -f2)
    [ "$_oct2" -ge 16 ] && [ "$_oct2" -le 31 ] && _priv=1 ;;
esac

if [ "$_priv" = "0" ] && [ -n "$GEO_IP" ]; then
  # Check geo cache first (valid for 1 hour, keyed on full IP)
  _GEO_CACHE="/tmp/geo_cache_${GEO_IP//[^a-z0-9._]/_}"
  _GEO_AGE=0
  _NOW=$(date +%s)
  if [ -f "$_GEO_CACHE" ]; then
    _GEO_TS=$(head -1 "$_GEO_CACHE" 2>/dev/null)
    _GEO_AGE=$((_NOW - _GEO_TS))
  fi

  if [ "$_GEO_AGE" -lt 3600 ] && [ -f "$_GEO_CACHE" ]; then
    # Use cached geo data
    COUNTRY=$(sed -n '2p' "$_GEO_CACHE")
    CC=$(sed -n '3p' "$_GEO_CACHE")
    REGION=$(sed -n '4p' "$_GEO_CACHE")
    CITY=$(sed -n '5p' "$_GEO_CACHE")
  else
    # Fresh geo lookup
    GEO=$(wget -q -O - --timeout=3 "http://ip-api.com/json/${GEO_IP}?fields=country,countryCode,regionName,city" 2>/dev/null || true)
    if [ -n "$GEO" ]; then
      COUNTRY=$(printf '%s' "$GEO" | grep -o '"country":"[^"]*"' | cut -d'"' -f4)
      CC=$(printf '%s' "$GEO" | grep -o '"countryCode":"[^"]*"' | cut -d'"' -f4)
      REGION=$(printf '%s' "$GEO" | grep -o '"regionName":"[^"]*"' | cut -d'"' -f4)
      CITY=$(printf '%s' "$GEO" | grep -o '"city":"[^"]*"' | cut -d'"' -f4)
      # Cache the result
      printf '%s\n%s\n%s\n%s\n%s\n' "$_NOW" "$COUNTRY" "$CC" "$REGION" "$CITY" > "$_GEO_CACHE"
    fi
  fi
fi

# ── Truncate IP for storage (last IPv4 octet → .x; last 80 bits of IPv6) ──
case "$IP" in
  *:*) IP=$(printf '%s' "$IP" | sed 's/:[^:]*:[^:]*:[^:]*:[^:]*:[^:]*$/::/') ;;
  *)   IP=$(printf '%s' "$IP" | sed 's/\.[0-9]*$/.x/') ;;
esac

# ── JSON-escape helper ────────────────────────────────────────────────────
je() { printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g; s/\t/ /g; s/[[:cntrl:]]//g'; }

ENTRY=$(printf '{"ts":"%s","ip":"%s","page":"%s","ref":"%s","ua":"%s","country":"%s","cc":"%s","region":"%s","city":"%s"}' \
  "$TS" "$(je "$IP")" "$(je "$PAGE")" "$(je "$REF")" "$(je "${HTTP_USER_AGENT:-}")" \
  "$(je "$COUNTRY")" "$(je "$CC")" "$(je "$REGION")" "$(je "$CITY")")

# ── Persist ────────────────────────────────────────────────────────────────
if [ "$STORAGE" = "local" ]; then
  mkdir -p "$ANALYTICS_DIR"
  printf '%s\n' "$ENTRY" >> "$ANALYTICS_DIR/$FILENAME"
else
  _ep=""
  [ -n "${MINIO_ENDPOINT:-}" ] && _ep="--endpoint-url ${MINIO_ENDPOINT}"
  TMPFILE="/tmp/track-$$"
  aws s3 cp "s3://${AWS_BUCKET}/analytics/${FILENAME}" "$TMPFILE" \
    --region "$AWS_REGION" ${_ep} >/dev/null 2>&1 || touch "$TMPFILE"
  printf '%s\n' "$ENTRY" >> "$TMPFILE"
  aws s3 cp "$TMPFILE" "s3://${AWS_BUCKET}/analytics/${FILENAME}" \
    --content-type "application/x-ndjson" \
    --region "$AWS_REGION" ${_ep} >/dev/null 2>&1 || true
  mkdir -p "$ANALYTICS_DIR"
  cp "$TMPFILE" "$ANALYTICS_DIR/$FILENAME" 2>/dev/null || true
  rm -f "$TMPFILE"
fi

printf '{"ok":true}\n'
