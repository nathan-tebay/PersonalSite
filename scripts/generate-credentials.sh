#!/bin/sh
# generate-credentials.sh — generate an ADMIN_TOKEN for the admin login.
#
# Computes SHA-256(password) and prints the token. The raw password is never
# stored anywhere; the hash is what gets set as the Lambda environment variable.
#
# Usage:
#   ./scripts/generate-credentials.sh [--apply] [--function <name>] [--region <region>]
#
# Options:
#   --apply             Set ADMIN_TOKEN on the Lambda function via the AWS CLI.
#   --function <name>   Lambda function name (default: personalSite).
#   --region <region>   AWS region (default: $AWS_REGION or us-east-1).
#
# Without --apply the token is printed with copy-paste instructions only.

LAMBDA_FUNCTION="${LAMBDA_FUNCTION:-personalSite}"
AWS_REGION="${AWS_REGION:-us-east-1}"
APPLY=0

while [ "$#" -gt 0 ]; do
  case "$1" in
    --apply)            APPLY=1;                shift   ;;
    --function)         LAMBDA_FUNCTION="$2";   shift 2 ;;
    --region)           AWS_REGION="$2";        shift 2 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

# ── Prompt for password (hidden) ──────────────────────────────────────────────
printf 'Password: '
stty -echo 2>/dev/null
read -r PASSWORD
stty echo 2>/dev/null
printf '\n'

if [ -z "$PASSWORD" ]; then
  echo "Error: password cannot be empty."
  exit 1
fi

printf 'Confirm:  '
stty -echo 2>/dev/null
read -r PASSWORD2
stty echo 2>/dev/null
printf '\n'

if [ "$PASSWORD" != "$PASSWORD2" ]; then
  echo "Error: passwords do not match."
  exit 1
fi

TOKEN=$(printf '%s' "$PASSWORD" | sha256sum | cut -d' ' -f1)

printf '\nADMIN_TOKEN: %s\n' "$TOKEN"

if [ "$APPLY" = "1" ]; then
  printf '\nSetting ADMIN_TOKEN on Lambda function "%s"...\n' "$LAMBDA_FUNCTION"
  aws lambda update-function-configuration \
    --function-name "$LAMBDA_FUNCTION" \
    --region "$AWS_REGION" \
    --environment "Variables={ADMIN_TOKEN=${TOKEN}}" \
    --query 'LastUpdateStatus' --output text \
    && echo "Done." \
    || echo "Failed — check your AWS credentials and function name."
else
  printf '\nTo apply, run one of:\n'
  printf '  # Apply automatically:\n'
  printf '  ./scripts/generate-credentials.sh --apply\n\n'
  printf '  # Or set manually via AWS CLI:\n'
  printf '  aws lambda update-function-configuration \\\n'
  printf '    --function-name %s \\\n' "$LAMBDA_FUNCTION"
  printf '    --environment "Variables={ADMIN_TOKEN=%s}"\n' "$TOKEN"
fi
