#!/bin/sh
# logout.cgi — clear the session cookie and redirect to the login page.
. /var/www/html/cgi-bin/common.sh

SECURE_FLAG=""
if [ "${HTTP_X_FORWARDED_PROTO:-}" = "https" ] || [ "${HTTPS:-}" = "on" ]; then
  SECURE_FLAG="; Secure"
fi
printf 'Status: 302 Found\r\n'
emit_security_headers
printf 'Set-Cookie: admin_session=; Path=/%s; SameSite=Strict; Max-Age=0; HttpOnly\r\n' "$SECURE_FLAG"
printf 'Set-Cookie: admin_ui=; Path=/; SameSite=Strict; Max-Age=0%s\r\n' "$SECURE_FLAG"
printf 'Set-Cookie: csrf_token=; Path=/; SameSite=Strict; Max-Age=0%s\r\n' "$SECURE_FLAG"
printf 'Set-Cookie: _session_ts=; Path=/; SameSite=Strict; Max-Age=0%s\r\n' "$SECURE_FLAG"
printf 'Location: /cgi-bin/login.cgi\r\n\r\n'
