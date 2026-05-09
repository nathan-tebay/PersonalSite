#!/bin/sh
. /var/www/html/cgi-bin/session.sh
# CGI: list images for a blog post slug.
# GET param: ?slug=<slug>
# Returns: {"images":["file1.jpg","file2.png",...]}

. /var/www/html/cgi-bin/common.sh
. /var/www/html/cgi-bin/storage.sh

emit_json_header

SLUG=$(printf '%s' "${QUERY_STRING}" | tr '&' '\n' | grep '^slug=' | head -1 | cut -d= -f2- | tr -cd 'a-z0-9-')

if [ -z "$SLUG" ]; then
  printf '\r\n{"error":"slug required"}\n'; exit 0
fi

images=""

if [ "$STORAGE" = "local" ]; then
  IMAGE_DIR="$LOCAL_DIR/$SLUG"
  if [ -d "$IMAGE_DIR" ]; then
    for f in "$IMAGE_DIR"/*; do
      [ -f "$f" ] || continue
      case "$f" in *.html) continue ;; esac
      filename=$(basename "$f")
      [ -z "$images" ] && images='"'"$filename"'"' \
                       || images="$images,"'"'"$filename"'"'
    done
  fi
else
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    filename=$(printf '%s' "$line" | awk '{print $NF}')
    [ -z "$filename" ] && continue
    case "$filename" in *.html) continue ;; esac
    [ -z "$images" ] && images='"'"$filename"'"' \
                     || images="$images,"'"'"$filename"'"'
  done <<EOF
$(aws s3 ls "${S3_PREFIX}/${SLUG}/" \
    --region "${AWS_REGION:-us-east-1}" \
    ${_aws_endpoint_arg} 2>/dev/null | grep -v ' PRE ')
EOF
fi

printf '\r\n{"images":[%s]}\n' "$images"
