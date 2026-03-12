#!/bin/sh
# logout.cgi — clear the session cookie and redirect to the login page.
SECURE_FLAG=""
if [ "${HTTP_X_FORWARDED_PROTO:-}" = "https" ] || [ "${HTTPS:-}" = "on" ]; then
  SECURE_FLAG="; Secure"
fi
printf 'Status: 302 Found\r\n'
printf 'Set-Cookie: admin_session=; Path=/%s; SameSite=Strict; Max-Age=0\r\n' "$SECURE_FLAG"
printf 'Location: /cgi-bin/login.cgi\r\n\r\n'
