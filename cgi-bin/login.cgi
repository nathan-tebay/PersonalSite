#!/bin/sh
# login.cgi — admin login.
# GET:  serve the login form.
# POST: validate password; on success set session cookie and redirect to /admin/.

. /var/www/html/cgi-bin/common.sh

# Append "; Secure" only when the request arrived over HTTPS.
SECURE_FLAG=""
if [ "${HTTP_X_FORWARDED_PROTO:-}" = "https" ] || [ "${HTTPS:-}" = "on" ]; then
  SECURE_FLAG="; Secure"
fi

ERROR=""

if [ "${REQUEST_METHOD}" = "POST" ]; then
  # ── Rate limiting: max 5 attempts per 300s per client IP ──────────────
  if ! rate_limit_check "login_${REMOTE_ADDR}" 5 300; then
    ERROR="Too many attempts. Please wait."
  fi
  # ─────────────────────────────────────────────────────────────────────

  if [ -z "$ERROR" ]; then
    body=$(head -c "${CONTENT_LENGTH:-0}")
    password=$(urldecode "$(printf '%s' "$body" | tr '&' '\n' | grep '^password=' | head -1 | cut -d= -f2-)")
    submitted=$(printf '%s' "$password" | sha256sum | cut -d' ' -f1)

    if [ -n "$ADMIN_TOKEN" ] && [ "$submitted" = "$ADMIN_TOKEN" ]; then
      # Generate signed session token: timestamp.nonce.sha256(ADMIN_TOKEN:nonce:timestamp)
      NONCE=$(od -An -tx1 -N16 /dev/urandom | tr -d ' \n')
      CSRF_TOKEN=$(od -An -tx1 -N16 /dev/urandom | tr -d ' \n')
      _NOW=$(date +%s)
      SIG=$(printf '%s:%s:%s' "$ADMIN_TOKEN" "$NONCE" "$_NOW" | sha256sum | cut -d' ' -f1)
      SESSION_TOKEN="${_NOW}.${NONCE}.${SIG}"
      printf 'Status: 302 Found\r\n'
      emit_security_headers
      printf 'Set-Cookie: admin_session=%s; Path=/; SameSite=Strict; HttpOnly%s\r\n' "$SESSION_TOKEN" "$SECURE_FLAG"
      printf 'Set-Cookie: admin_ui=1; Path=/; SameSite=Strict%s\r\n' "$SECURE_FLAG"
      printf 'Set-Cookie: csrf_token=%s; Path=/; SameSite=Strict%s\r\n' "$CSRF_TOKEN" "$SECURE_FLAG"
      printf 'Location: /admin/\r\n\r\n'
      exit 0
    fi

    ERROR="Invalid password."
  fi
fi

printf 'Content-Type: text/html\r\n'
emit_security_headers
printf '\r\n'
cat <<HTML
<!doctype html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>Admin Login — Tebay.dev</title>
  <style>
    *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      min-height: 100vh;
      display: flex;
      align-items: center;
      justify-content: center;
      background: #1a1f2e;
      font-family: monospace;
      color: #c9d1d9;
    }
    .card {
      background: #222736;
      border: 1px solid #2d3548;
      border-radius: 6px;
      padding: 2rem;
      width: 100%;
      max-width: 340px;
    }
    h1 { font-size: 1rem; margin-bottom: 1.5rem; color: #8b949e; letter-spacing: 0.05em; }
    label { display: block; font-size: 0.8rem; color: #8b949e; margin-bottom: 0.4rem; }
    input[type=password] {
      width: 100%;
      padding: 0.5rem 0.75rem;
      background: rgba(0,0,0,0.3);
      border: 1px solid #2d3548;
      border-radius: 4px;
      color: #c9d1d9;
      font-family: monospace;
      font-size: 0.9rem;
      margin-bottom: 1.25rem;
    }
    input[type=password]:focus { outline: none; border-color: #4a7c59; }
    button {
      width: 100%;
      padding: 0.5rem;
      background: #2d4a38;
      border: 1px solid #4a7c59;
      border-radius: 4px;
      color: #8ec49a;
      font-family: monospace;
      font-size: 0.9rem;
      cursor: pointer;
    }
    button:hover { background: #3a5e47; }
    .error { color: #f87171; font-size: 0.8rem; margin-bottom: 1rem; }
  </style>
</head>
<body>
  <div class="card">
    <h1>TEBAY.DEV / ADMIN</h1>
    $([ -n "$ERROR" ] && printf '<p class="error">%s</p>' "$ERROR")
    <form method="POST" action="/cgi-bin/login.cgi">
      <label for="password">Password</label>
      <input type="password" id="password" name="password" autofocus autocomplete="current-password" />
      <button type="submit">Sign in</button>
    </form>
  </div>
</body>
</html>
HTML
