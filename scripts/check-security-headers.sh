#!/bin/bash
# Smoke test: verify security headers are present on key endpoints.
# Usage: ./scripts/check-security-headers.sh [BASE_URL]
# Example: ./scripts/check-security-headers.sh http://localhost:8888

BASE="${1:-http://localhost:8888}"
FAIL=0

check() {
  local path="$1" header="$2"
  if curl -sI "$BASE$path" | grep -qi "$header"; then
    printf 'OK   %s  %s\n' "$path" "$header"
  else
    printf 'FAIL %s  %s\n' "$path" "$header"
    FAIL=1
  fi
}

for path in / /admin/ /blog.html /links.html; do
  check "$path" "x-content-type-options: nosniff"
  check "$path" "x-frame-options: deny"
  check "$path" "content-security-policy:"
done

check /cgi-bin/login.cgi "x-content-type-options: nosniff"
check /cgi-bin/login.cgi "content-security-policy:"
check /.well-known/security.txt "contact:"

exit $FAIL
