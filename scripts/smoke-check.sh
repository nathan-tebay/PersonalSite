#!/usr/bin/env sh
set -eu

if [ "$#" -ne 1 ]; then
  echo "Usage: $0 https://tebay.dev" >&2
  exit 2
fi

BASE_URL="${1%/}"

check_url() {
  path="$1"
  url="$BASE_URL$path"
  code="$(curl -fsS -o /dev/null -w "%{http_code}" "$url")"
  if [ "$code" != "200" ]; then
    echo "Smoke check failed: $url returned $code" >&2
    exit 1
  fi
  echo "OK $path"
}

check_url "/index.html"
check_url "/blog.html"
check_url "/links.html"
check_url "/projects/autorejection.html"
check_url "/projects/dbfirstgrid.html"
check_url "/projects/flyfishinggame.html"
check_url "/projects/microphonecontroller.html"
check_url "/projects/whispertranscribe.html"
check_url "/projects/aiagents.html"
check_url "/projects/personalsite.html"
check_url "/blog/posts/manifest.json"
check_url "/links.json"
check_url "/admin/index.html"
