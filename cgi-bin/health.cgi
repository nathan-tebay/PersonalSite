#!/bin/sh
# Public health check — returns 200 OK with JSON status.
# Used by load balancers, health probes, and monitoring.
printf 'Content-Type: application/json\r\nStatus: 200 OK\r\n\r\n'
printf '{"status":"ok","ts":"%s","version":"1.0"}\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
