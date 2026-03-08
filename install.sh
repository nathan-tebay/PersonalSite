#!/usr/bin/env bash
# install.sh — PersonalSite setup and launcher
#
# Usage:
#   ./install.sh           # interactive: prompts for mode (dev or prod)
#   ./install.sh dev       # local development mode (MinIO S3-compatible, port 8888)
#   ./install.sh prod      # production mode (AWS S3, port 8080)
#   ./install.sh --help
#
# Prerequisites: Podman must be installed and available in PATH.
#
# Dev mode starts two containers on a shared 'personalsite-dev' network:
#   - personalsite-minio  MinIO S3-compatible object store (ports 9000/9001)
#   - personalsite        The site itself (port 8888)
# No AWS credentials are required for dev mode; MinIO uses minioadmin/minioadmin.
# The 'blog-posts' bucket is created automatically via the MinIO mc client.
#
# For production mode, AWS credentials and a bucket/access-point must be
# provided via environment variables before running this script.

set -euo pipefail

# ── Colour helpers ────────────────────────────────────────────────────────────

RESET='\033[0m'
BOLD='\033[1m'
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'

info()    { printf "${BLUE}[INFO]${RESET}  %s\n"    "$*"; }
success() { printf "${GREEN}[OK]${RESET}    %s\n"   "$*"; }
warn()    { printf "${YELLOW}[WARN]${RESET}  %s\n"  "$*"; }
error()   { printf "${RED}[ERROR]${RESET} %s\n"     "$*" >&2; }
step()    { printf "\n${BOLD}${CYAN}==> %s${RESET}\n" "$*"; }
die()     { error "$*"; exit 1; }

# ── Trap for clean failure messages ──────────────────────────────────────────

trap 'error "Script failed at line $LINENO. See output above for details."' ERR

# ── Resolve the project root (directory containing this script) ───────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Help ─────────────────────────────────────────────────────────────────────

usage() {
  cat <<EOF

${BOLD}PersonalSite — install / launch script${RESET}

  ${BOLD}Usage:${RESET}
    $(basename "$0") [dev|prod|--help]

  ${BOLD}Modes:${RESET}
    dev     Build and run the dev image with a local MinIO S3 store (port 8888).
            Starts two containers on the 'personalsite-dev' network:
              personalsite-minio  — MinIO (API :9000, console :9001)
              personalsite        — the site (port 8888)
            The 'blog-posts' bucket is created automatically via mc.
            The project directory is mounted live; HTML/CSS/JS changes are
            visible immediately without a rebuild.
            No AWS credentials required — MinIO uses minioadmin/minioadmin.

    prod    Build and run the production image (STORAGE=s3, port 8080).
            Requires AWS credentials and a bucket or access-point ARN.

  ${BOLD}Environment variables (prod mode only):${RESET}
    AWS_REGION              AWS region                     (default: us-east-1)
    AWS_ACCESS_KEY_ID       AWS access key
    AWS_SECRET_ACCESS_KEY   AWS secret key
    AWS_BUCKET              S3 bucket name
    AWS_ACCESS_POINT_ARN    S3 access point ARN (takes priority over AWS_BUCKET)

EOF
}

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  usage
  exit 0
fi

# ── Platform / architecture detection ────────────────────────────────────────

step "Detecting platform"

OS="$(uname -s)"
ARCH="$(uname -m)"
info "OS: ${OS}, Architecture: ${ARCH}"

case "$OS" in
  Linux)  PLATFORM="linux"  ;;
  Darwin) PLATFORM="macos"  ;;
  *)      die "Unsupported operating system: ${OS}" ;;
esac

# ── Dependency check: Podman ──────────────────────────────────────────────────

step "Checking dependencies"

check_command() {
  local cmd="$1"
  local install_hint="${2:-}"
  if command -v "$cmd" &>/dev/null; then
    success "${cmd} found: $(command -v "$cmd")"
  else
    error "${cmd} is not installed or not in PATH."
    if [[ -n "$install_hint" ]]; then
      warn "  Install hint: ${install_hint}"
    fi
    die "Missing required dependency: ${cmd}"
  fi
}

if [[ "$PLATFORM" == "macos" ]]; then
  PODMAN_HINT="brew install podman  (then: podman machine init && podman machine start)"
else
  PODMAN_HINT="sudo dnf install podman   # Fedora/RHEL
    sudo apt install podman               # Debian/Ubuntu
    See: https://podman.io/getting-started/installation"
fi

check_command podman "$PODMAN_HINT"

# Verify the Podman socket / machine is reachable (non-fatal — containers can
# still be built even if the service isn't running; warn and continue).
if ! podman info &>/dev/null; then
  warn "Podman is installed but 'podman info' failed."
  if [[ "$PLATFORM" == "macos" ]]; then
    warn "  You may need to start the Podman machine:"
    warn "    podman machine init   (first time only)"
    warn "    podman machine start"
  else
    warn "  Ensure the Podman socket is available (rootless: no extra setup needed on most distros)."
  fi
fi

# ── Mode selection ────────────────────────────────────────────────────────────

MODE="${1:-}"

if [[ -z "$MODE" ]]; then
  printf "\n${BOLD}Which mode would you like to run?${RESET}\n"
  printf "  1) ${CYAN}dev${RESET}   — local development (MinIO, no AWS required, live reload, port 8888)\n"
  printf "  2) ${CYAN}prod${RESET}  — production build  (S3 storage, port 8080)\n"
  printf "\nEnter choice [1/2] or type 'dev'/'prod': "
  read -r CHOICE
  case "$CHOICE" in
    1|dev)  MODE="dev"  ;;
    2|prod) MODE="prod" ;;
    *) die "Invalid choice '${CHOICE}'. Pass 'dev' or 'prod' as an argument." ;;
  esac
fi

case "$MODE" in
  dev|prod) ;;
  *) die "Unknown mode '${MODE}'. Use 'dev' or 'prod'." ;;
esac

info "Selected mode: ${BOLD}${MODE}${RESET}"

# ── Validate project structure ────────────────────────────────────────────────

step "Validating project structure"

REQUIRED_FILES=(
  "Dockerfile.dev"
  "Dockerfile"
  "docker-entrypoint.sh"
  "sync-posts.sh"
  "config.cgi"
  "admin/cgi-bin/save.cgi"
  "admin/cgi-bin/delete.cgi"
  "admin/cgi-bin/publish.cgi"
  "admin/cgi-bin/posts.cgi"
  "admin/cgi-bin/storage.sh"
)

for f in "${REQUIRED_FILES[@]}"; do
  if [[ -f "${SCRIPT_DIR}/${f}" ]]; then
    success "Found: ${f}"
  else
    warn "Missing expected file: ${f}"
  fi
done

# ── Credentials file check (required for the httpd basic-auth config) ─────────

step "Checking credentials file"

# The dev Dockerfile uses .credentials; the prod Dockerfile uses .crendential
# (a typo in the prod Dockerfile — both are checked here).
CREDS_FILE=""
if [[ -f "${SCRIPT_DIR}/.credentials" ]]; then
  CREDS_FILE=".credentials"
  success "Found credentials file: .credentials"
elif [[ -f "${SCRIPT_DIR}/.crendential" ]]; then
  CREDS_FILE=".crendential"
  success "Found credentials file: .crendential (note: typo in prod Dockerfile — see note below)"
else
  warn "No credentials file found (.credentials or .crendential)."
  warn "The admin panel (/admin) uses HTTP Basic Auth backed by this file."
  warn "The busybox httpd format is:"
  warn "  /admin:username:MD5-or-SHA1-hashed-password"
  warn ""
  warn "To generate one with an MD5 hash (requires openssl or htpasswd):"
  warn "  printf '/admin:myuser:%s\n' \"\$(openssl passwd -apr1 'mypassword')\" > .credentials"
  warn ""
  if [[ "$MODE" == "prod" ]]; then
    die "A credentials file is required to build the production image. Create .credentials first."
  else
    warn "Continuing without a credentials file — the admin area will be unprotected in dev mode."
    warn "Consider creating .credentials before running in production."
  fi
fi

# ── Dev mode setup and launch ─────────────────────────────────────────────────

# Constants for dev mode
DEV_NETWORK="personalsite-dev"
DEV_MINIO_CONTAINER="personalsite-minio"
DEV_SITE_CONTAINER="personalsite"
DEV_MINIO_USER="minioadmin"
DEV_MINIO_PASS="minioadmin"
DEV_BUCKET="blog-posts"

run_dev() {
  step "Setting up development environment"

  # Pull required images up front so any network errors are caught early
  step "Pulling MinIO images"
  info "Pulling quay.io/minio/minio ..."
  podman pull quay.io/minio/minio
  success "quay.io/minio/minio pulled."

  info "Pulling quay.io/minio/mc ..."
  podman pull quay.io/minio/mc
  success "quay.io/minio/mc pulled."

  # Ensure the shared dev network exists
  step "Ensuring Podman network: ${DEV_NETWORK}"
  if podman network exists "${DEV_NETWORK}" 2>/dev/null; then
    success "Network '${DEV_NETWORK}' already exists."
  else
    info "Creating network '${DEV_NETWORK}'..."
    podman network create "${DEV_NETWORK}"
    success "Network '${DEV_NETWORK}' created."
  fi

  step "Building development container image"
  info "Image tag: personalsite-dev"
  info "Dockerfile: Dockerfile.dev"

  podman build \
    -f "${SCRIPT_DIR}/Dockerfile.dev" \
    -t personalsite-dev \
    "${SCRIPT_DIR}"

  success "Development image built successfully."

  # Stop any existing containers with the same names (idempotent)
  step "Stopping any existing dev containers"
  for cname in "${DEV_MINIO_CONTAINER}" "${DEV_SITE_CONTAINER}"; do
    if podman container exists "${cname}" 2>/dev/null; then
      info "Removing existing container '${cname}'..."
      podman rm -f "${cname}"
    fi
  done

  # Start MinIO
  step "Starting MinIO container"
  info "Container: ${DEV_MINIO_CONTAINER}"
  info "  API port:     9000 -> http://localhost:9000"
  info "  Console port: 9001 -> http://localhost:9001"
  info "  Credentials:  ${DEV_MINIO_USER} / ${DEV_MINIO_PASS}"

  podman run -d \
    --name "${DEV_MINIO_CONTAINER}" \
    --network "${DEV_NETWORK}" \
    -p 9000:9000 \
    -p 9001:9001 \
    -e "MINIO_ROOT_USER=${DEV_MINIO_USER}" \
    -e "MINIO_ROOT_PASSWORD=${DEV_MINIO_PASS}" \
    quay.io/minio/minio server /data --console-address ":9001"

  # Poll MinIO health endpoint (up to 30 seconds)
  info "Waiting for MinIO to become ready..."
  printf "  "
  i=0
  while [[ $i -lt 30 ]]; do
    if podman exec "${DEV_MINIO_CONTAINER}" \
        wget -qO- http://localhost:9000/minio/health/live &>/dev/null; then
      printf "\n"
      break
    fi
    sleep 1
    printf "."
    i=$((i + 1))
  done

  if [[ $i -eq 30 ]]; then
    die "MinIO did not become healthy within 30 seconds. Check: podman logs ${DEV_MINIO_CONTAINER}"
  fi

  success "MinIO is ready."

  # Create the bucket via the mc client (run-and-remove)
  step "Creating bucket '${DEV_BUCKET}' via mc"
  info "Running mc in a temporary container on '${DEV_NETWORK}'..."

  podman run --rm \
    --network "${DEV_NETWORK}" \
    --entrypoint /bin/sh \
    quay.io/minio/mc \
    -c "mc alias set dev http://${DEV_MINIO_CONTAINER}:9000 \
          ${DEV_MINIO_USER} ${DEV_MINIO_PASS} \
        && mc mb --ignore-existing dev/${DEV_BUCKET}" 2>/dev/null || true

  success "Bucket '${DEV_BUCKET}' is ready."

  # Start the site container
  step "Starting site container"
  info "Container: ${DEV_SITE_CONTAINER}"
  info "  Port:         8888 -> http://localhost:8888"
  info "  Storage mode: s3 (backed by local MinIO)"
  info "  S3 endpoint:  http://${DEV_MINIO_CONTAINER}:9000"
  info "  Bucket:       ${DEV_BUCKET}"
  info "  Live mount:   project directory is mounted as the web root"
  info "  HTML/CSS/JS changes take effect immediately (no rebuild needed)"

  podman run -d \
    --name "${DEV_SITE_CONTAINER}" \
    --network "${DEV_NETWORK}" \
    -p 8888:8888 \
    -e "STORAGE=s3" \
    -e "AWS_ACCESS_KEY_ID=${DEV_MINIO_USER}" \
    -e "AWS_SECRET_ACCESS_KEY=${DEV_MINIO_PASS}" \
    -e "AWS_BUCKET=${DEV_BUCKET}" \
    -e "AWS_REGION=us-east-1" \
    -e "MINIO_ENDPOINT=http://${DEV_MINIO_CONTAINER}:9000" \
    -v "${SCRIPT_DIR}:/var/www/html:Z" \
    personalsite-dev

  # Brief pause to let the container start before checking
  sleep 1

  if podman container exists "${DEV_SITE_CONTAINER}" 2>/dev/null; then
    success "Container '${DEV_SITE_CONTAINER}' is running."
  else
    warn "Container may have exited immediately — check output above."
    warn "  podman logs ${DEV_SITE_CONTAINER}"
  fi

  if podman container exists "${DEV_MINIO_CONTAINER}" 2>/dev/null; then
    success "Container '${DEV_MINIO_CONTAINER}' is running."
  else
    warn "MinIO container may have stopped — check: podman logs ${DEV_MINIO_CONTAINER}"
  fi

  print_dev_summary
}

# ── Prod mode setup and launch ────────────────────────────────────────────────

run_prod() {
  step "Setting up production environment"

  # Validate required AWS environment variables
  info "Checking AWS configuration..."

  local missing_vars=()

  if [[ -z "${AWS_ACCESS_KEY_ID:-}" ]]; then
    missing_vars+=("AWS_ACCESS_KEY_ID")
  fi
  if [[ -z "${AWS_SECRET_ACCESS_KEY:-}" ]]; then
    missing_vars+=("AWS_SECRET_ACCESS_KEY")
  fi
  if [[ -z "${AWS_BUCKET:-}" && -z "${AWS_ACCESS_POINT_ARN:-}" ]]; then
    missing_vars+=("AWS_BUCKET or AWS_ACCESS_POINT_ARN")
  fi

  if [[ ${#missing_vars[@]} -gt 0 ]]; then
    error "The following required environment variables are not set:"
    for v in "${missing_vars[@]}"; do
      error "  - ${v}"
    done
    error ""
    error "Export them before running this script:"
    error "  export AWS_ACCESS_KEY_ID=..."
    error "  export AWS_SECRET_ACCESS_KEY=..."
    error "  export AWS_BUCKET=my-bucket-name"
    error "  (or AWS_ACCESS_POINT_ARN=arn:aws:s3:us-east-1:123456789012:accesspoint/my-ap)"
    die "Missing required AWS environment variables."
  fi

  success "AWS_ACCESS_KEY_ID: set"
  success "AWS_SECRET_ACCESS_KEY: set"
  if [[ -n "${AWS_ACCESS_POINT_ARN:-}" ]]; then
    success "AWS_ACCESS_POINT_ARN: ${AWS_ACCESS_POINT_ARN}"
  else
    success "AWS_BUCKET: ${AWS_BUCKET}"
  fi
  success "AWS_REGION: ${AWS_REGION:-us-east-1}"

  step "Building production container image"
  info "Image tag: personalsite"
  info "Dockerfile: Dockerfile"

  podman build \
    -f "${SCRIPT_DIR}/Dockerfile" \
    -t personalsite \
    "${SCRIPT_DIR}"

  success "Production image built successfully."

  # Stop any existing container with the same name (idempotent)
  step "Starting production container"
  if podman container exists personalsite-prod 2>/dev/null; then
    info "Stopping existing 'personalsite-prod' container..."
    podman rm -f personalsite-prod
  fi

  info "Starting container: personalsite-prod"
  info "  Port: 8080 -> http://localhost:8080"
  info "  Storage mode: s3"
  if [[ -n "${AWS_ACCESS_POINT_ARN:-}" ]]; then
    info "  S3 prefix: ${AWS_ACCESS_POINT_ARN}/blog/posts"
  else
    info "  S3 bucket: ${AWS_BUCKET}/blog/posts"
  fi
  info "  The entrypoint will sync posts from S3 before starting httpd."
  info "  A background sync loop re-checks S3 every 10 minutes."

  podman run \
    --rm \
    --name personalsite-prod \
    -p 8080:8080 \
    -e "AWS_REGION=${AWS_REGION:-us-east-1}" \
    -e "AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID}" \
    -e "AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY}" \
    ${AWS_BUCKET:+-e "AWS_BUCKET=${AWS_BUCKET}"} \
    ${AWS_ACCESS_POINT_ARN:+-e "AWS_ACCESS_POINT_ARN=${AWS_ACCESS_POINT_ARN}"} \
    personalsite &

  CONTAINER_PID=$!

  sleep 2

  if podman container exists personalsite-prod 2>/dev/null; then
    success "Container 'personalsite-prod' is running."
  else
    warn "Container may have exited immediately — check output above."
    warn "Common causes:"
    warn "  - AWS credentials are invalid"
    warn "  - The S3 bucket/prefix does not exist or is not accessible"
    warn "  - The .credentials/.crendential file is missing or malformed"
  fi

  print_prod_summary
}

# ── Post-launch summaries ──────────────────────────────────────────────────────

print_dev_summary() {
  printf "\n${BOLD}${GREEN}Development environment is running.${RESET}\n\n"
  printf "  Site:          ${CYAN}http://localhost:8888${RESET}\n"
  printf "  Admin panel:   ${CYAN}http://localhost:8888/admin/${RESET}\n"
  printf "  MinIO console: ${CYAN}http://localhost:9001${RESET}  (${DEV_MINIO_USER} / ${DEV_MINIO_PASS})\n"
  printf "  MinIO API:     ${CYAN}http://localhost:9000${RESET}\n"
  printf "  Storage mode:  s3 (MinIO — bucket: ${DEV_BUCKET})\n"
  printf "  Live editing:  yes — edit HTML/CSS/JS and refresh your browser\n"
  printf "\n  Containers on network '${DEV_NETWORK}':\n"
  printf "    ${BOLD}${DEV_SITE_CONTAINER}${RESET}        site\n"
  printf "    ${BOLD}${DEV_MINIO_CONTAINER}${RESET}  MinIO object store\n"
  printf "\n  To stop both containers:\n"
  printf "    ${BOLD}podman rm -f ${DEV_SITE_CONTAINER} ${DEV_MINIO_CONTAINER}${RESET}\n"
  printf "\n  To rebuild after changing the Dockerfile:\n"
  printf "    ${BOLD}podman build -f Dockerfile.dev -t personalsite-dev .${RESET}\n"
  printf "\n  To view container logs:\n"
  printf "    ${BOLD}podman logs -f ${DEV_SITE_CONTAINER}${RESET}\n"
  printf "    ${BOLD}podman logs -f ${DEV_MINIO_CONTAINER}${RESET}\n\n"
}

print_prod_summary() {
  printf "\n${BOLD}${GREEN}Production environment is running.${RESET}\n\n"
  printf "  Site:         ${CYAN}http://localhost:8080${RESET}\n"
  printf "  Admin panel:  ${CYAN}http://localhost:8080/admin/${RESET}\n"
  printf "  Storage mode: s3\n"
  printf "\n  The container syncs blog posts from S3 on startup and every 10 minutes.\n"
  printf "\n  To stop the container:\n"
  printf "    ${BOLD}podman rm -f personalsite-prod${RESET}\n"
  printf "\n  To view container logs:\n"
  printf "    ${BOLD}podman logs -f personalsite-prod${RESET}\n\n"
  printf "  ${YELLOW}Note:${RESET} AWS credentials are passed via environment variables.\n"
  printf "  Do not commit .env files or credentials to version control.\n\n"
}

# ── Dispatch ───────────────────────────────────────────────────────────────────

case "$MODE" in
  dev)  run_dev  ;;
  prod) run_prod ;;
esac
