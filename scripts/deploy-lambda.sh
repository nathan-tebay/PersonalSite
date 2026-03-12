#!/bin/sh
# deploy-lambda.sh — build, push to ECR, and update the personalSite Lambda function.
#
# What this script does:
#   1. Authenticates podman with ECR.
#   2. Builds the container image for linux/amd64.
#   3. Pushes the image to ECR.
#   4. Updates the Lambda function to use the new image.
#   5. Waits for the update to complete and prints the new image digest.
#
# Usage:
#   ./scripts/deploy-lambda.sh \
#     [--account-id 123456789012] \
#     [--region us-east-1] \
#     [--repo ntebay/personalsite] \
#     [--function personalSite] \
#     [--tag latest] \
#     [--dry-run]
#
# All parameters have defaults derived from the environment or the values used
# when this project was set up. Override only what you need.
#
# Optional parameters:
#   --account-id   AWS account ID (default: $AWS_ACCOUNT_ID or 158578456321).
#   --region       AWS region (default: $AWS_REGION or us-east-1).
#   --repo         ECR repository name without registry prefix
#                  (default: ntebay/personalsite).
#   --function     Lambda function name (default: personalSite).
#   --tag          Image tag to build and deploy (default: latest).
#   --dry-run      Print what would happen without making any changes.

# ── Defaults ──────────────────────────────────────────────────────────────────
AWS_ACCOUNT_ID="${AWS_ACCOUNT_ID:-158578456321}"
AWS_REGION="${AWS_REGION:-us-east-1}"
ECR_REPO="${ECR_REPO:-ntebay/personalsite}"
LAMBDA_FUNCTION="${LAMBDA_FUNCTION:-personalSite}"
IMAGE_TAG="latest"
DRY_RUN=0

# ── Argument parsing ──────────────────────────────────────────────────────────
usage() {
  sed -n '/^# Usage:/,/^[^#]/p' "$0" | grep '^#' | sed 's/^# \?//'
  exit 1
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --account-id) AWS_ACCOUNT_ID="$2"; shift 2 ;;
    --region)     AWS_REGION="$2";     shift 2 ;;
    --repo)       ECR_REPO="$2";       shift 2 ;;
    --function)   LAMBDA_FUNCTION="$2"; shift 2 ;;
    --tag)        IMAGE_TAG="$2";      shift 2 ;;
    --dry-run)    DRY_RUN=1;           shift   ;;
    -h|--help)    usage ;;
    *) echo "Unknown option: $1"; usage ;;
  esac
done

ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
IMAGE_URI="${ECR_REGISTRY}/${ECR_REPO}:${IMAGE_TAG}"

# Resolve project root (one level up from scripts/)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

section() { printf '\n\033[1;32m==> %s\033[0m\n' "$*"; }
info()    { printf '    %s\n' "$*"; }
ok()      { printf '    \033[32m✓\033[0m %s\n' "$*"; }
warn()    { printf '    \033[33m!\033[0m %s\n' "$*"; }
err()     { printf '    \033[31m✗\033[0m %s\n' "$*"; exit 1; }

# ── Summary ───────────────────────────────────────────────────────────────────
section "tebay.dev — Lambda deploy"
info "Account  : $AWS_ACCOUNT_ID"
info "Region   : $AWS_REGION"
info "Image    : $IMAGE_URI"
info "Function : $LAMBDA_FUNCTION"
[ "$DRY_RUN" = "1" ] && warn "Dry-run mode — no changes will be made"

# ── 1. ECR login ──────────────────────────────────────────────────────────────
section "1. ECR login"
if [ "$DRY_RUN" = "1" ]; then
  info "Would authenticate podman with $ECR_REGISTRY"
else
  aws ecr get-login-password --region "$AWS_REGION" \
    | podman login --username AWS --password-stdin "$ECR_REGISTRY" \
    && ok "Authenticated with ECR" \
    || err "ECR login failed"
fi

# ── 2. Build ──────────────────────────────────────────────────────────────────
section "2. Build (linux/amd64)"
if [ "$DRY_RUN" = "1" ]; then
  info "Would build: $IMAGE_URI"
  info "Context: $PROJECT_ROOT"
else
  podman build \
    --no-cache \
    --platform linux/amd64 \
    -t "$IMAGE_URI" \
    "$PROJECT_ROOT" \
    && ok "Built $IMAGE_URI" \
    || err "Build failed"
fi

# ── 3. Push ───────────────────────────────────────────────────────────────────
section "3. Push to ECR"
if [ "$DRY_RUN" = "1" ]; then
  info "Would push: $IMAGE_URI"
else
  podman push "$IMAGE_URI" \
    && ok "Pushed $IMAGE_URI" \
    || err "Push failed"
fi

# ── 4. Update Lambda ──────────────────────────────────────────────────────────
section "4. Update Lambda function"
if [ "$DRY_RUN" = "1" ]; then
  info "Would update $LAMBDA_FUNCTION to use $IMAGE_URI"
else
  aws lambda update-function-code \
    --function-name "$LAMBDA_FUNCTION" \
    --image-uri "$IMAGE_URI" \
    --region "$AWS_REGION" \
    --query 'CodeSize' \
    --output text >/dev/null \
    && ok "Triggered image update for $LAMBDA_FUNCTION" \
    || err "Failed to update Lambda function"

  info "Waiting for update to complete..."
  aws lambda wait function-updated \
    --function-name "$LAMBDA_FUNCTION" \
    --region "$AWS_REGION" \
    && ok "Function updated successfully" \
    || err "Function update did not complete in time"

  DIGEST=$(aws lambda get-function \
    --function-name "$LAMBDA_FUNCTION" \
    --region "$AWS_REGION" \
    --query 'Code.ResolvedImageUri' \
    --output text 2>/dev/null)
  [ -n "$DIGEST" ] && info "Deployed image: $DIGEST"
fi

# ── Done ──────────────────────────────────────────────────────────────────────
section "Done"
