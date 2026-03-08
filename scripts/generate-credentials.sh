#!/bin/sh
# set-htpasswd.sh — write admin/cgi-bin/.htpasswd with a SHA1 password hash.
# SHA1 ({SHA} prefix) is the format supported by BusyBox httpd on Alpine/musl.
#
# Usage:
#   ./scripts/set-htpasswd.sh <username> <password>
#
# Example:
#   ./scripts/set-htpasswd.sh ntebay mysecretpassword

if [ "$#" -ne 2 ]; then
  echo "Usage: $0 <username> <password>"
  exit 1
fi

podman run --rm -v ../:/password -e PASSWORD=$2 -e USERNAME=$1  personalsite-dev /bin/ash -c '
  HASH=$(httpd -m $PASSWORD)
  printf "/admin:%s:%s\n/cgi-bin:%s:%s\n" "$USERNAME" "$HASH" "$USERNAME" "$HASH" > /password/.credentials
'
echo "DONE"
