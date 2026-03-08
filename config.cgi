#!/bin/sh
# Public CGI: returns the posts base URL for the frontend.
# Posts are always served from the local cache (/blog/posts/) regardless of
# storage backend — S3 is never accessed directly by the browser.
printf 'Content-Type: application/json\r\n\r\n'
if [ "${STORAGE:-s3}" = "local" ]; then
  printf '{"postsUrl":"/blog/posts","storage":"local"}\n'
else
  printf '{"postsUrl":"/blog/posts","storage":"s3"}\n'
fi
