#!/bin/sh
set -e

NETWORK=personalsite-dev
MINIO=personalsite-minio
SITE=personalsite
MINIO_USER=minioadmin
MINIO_PASS=minioadmin
ADMIN_TOKEN=008c70392e3abfbd0fa47bbc2ed96aa99bd49e159727fcba0f2e6abeb3a9d601  # Password123
BUCKET=ntebay-personal-site
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# ── Clean up existing containers ──────────────────────────────────────
podman rm -f "$MINIO" "$SITE" 2>/dev/null || true

# ── Ensure dev network exists ─────────────────────────────────────────
podman network exists "$NETWORK" 2>/dev/null || podman network create "$NETWORK"

# ── Build site image ──────────────────────────────────────────────────
podman build -f Dockerfile.dev -t personalsite-dev "$SCRIPT_DIR"

# ── Start MinIO ───────────────────────────────────────────────────────
podman run -d \
  --name "$MINIO" \
  --network "$NETWORK" \
  -p 9000:9000 \
  -p 9001:9001 \
  -e MINIO_ROOT_USER="$MINIO_USER" \
  -e MINIO_ROOT_PASSWORD="$MINIO_PASS" \
  quay.io/minio/minio server /data --console-address ":9001"

# ── Wait for MinIO to be ready ────────────────────────────────────────
printf 'Waiting for MinIO'
i=0
while [ $i -lt 30 ]; do
  if podman exec "$MINIO" wget -qO- http://localhost:9000/minio/health/live >/dev/null 2>&1; then
    break
  fi
  sleep 1
  printf '.'
  i=$((i + 1))
done
printf '\n'

# ── Create bucket via MinIO mc ────────────────────────────────────────
podman run --rm \
  --network "$NETWORK" \
  --entrypoint /bin/sh \
  quay.io/minio/mc \
  -c "mc alias set dev http://$MINIO:9000 $MINIO_USER $MINIO_PASS \
      && mc mb --ignore-existing dev/$BUCKET" 2>/dev/null || true

# ── Start site container (live-mounted, non-blocking) ─────────────────
podman run -d \
  --replace \
  --name "$SITE" \
  --network "$NETWORK" \
  -p 8888:8888 \
  -e STORAGE=local \
  -e AWS_ACCESS_KEY_ID="$MINIO_USER" \
  -e AWS_SECRET_ACCESS_KEY="$MINIO_PASS" \
  -e AWS_BUCKET="$BUCKET" \
  -e AWS_REGION=us-east-1 \
  -e MINIO_ENDPOINT="http://$MINIO:9000" \
  -e ADMIN_TOKEN="$ADMIN_TOKEN" \
  personalsite-dev

printf '\n'
printf '  Site:          http://personalsite.local\n'
printf '  MinIO API:     http://minio.local\n'
printf '  MinIO console: http://minio-console.local  (%s / %s)\n' "$MINIO_USER" "$MINIO_PASS"
printf '\n'
printf 'Stop:  podman rm -f %s %s\n' "$SITE" "$MINIO"
printf 'Logs:  podman logs -f %s\n' "$SITE"
