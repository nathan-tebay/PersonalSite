#!/bin/sh
# aws-setup.sh — create and attach AWS IAM / S3 policies for the blog container.
#
# What this script does:
#   1. Optionally creates the IAM user or role named in --principal.
#   2. Creates (or updates) a least-privilege IAM managed policy scoped to
#      blog/posts/* and attaches it to the principal.
#   3. Optionally applies an access point resource policy granting the principal
#      access through the access point.
#   4. Optionally applies a bucket policy that denies all direct bucket access,
#      forcing every request to go through the access point.
#   5. Optionally applies a CloudFront OAC bucket policy allowing CloudFront to
#      read videos/* directly from S3 (bypassing the access point).
#   6. Optionally writes the key environment variables to your shell rc file.
#
# Usage:
#   ./aws-setup.sh --account-id 123456789012 \
#                  --region us-east-1 \
#                  --bucket my-bucket \
#                  --principal arn:aws:iam::123456789012:role/my-role \
#                  [--access-point my-ap] \
#                  [--policy-name tebay-blog-s3] \
#                  [--create-user] \
#                  [--create-role [--trust lambda.amazonaws.com]] \
#                  [--bucket-policy] \
#                  [--cf-dist-id EXXXXXXXXXX --cf-video-policy] \
#                  [--save-env] \
#                  [--dry-run]
#
# Required parameters:
#   --account-id   Your 12-digit AWS account ID.
#   --bucket       S3 bucket name (e.g. my-bucket, not the full ARN).
#   --principal    Full IAM ARN of the user or role that will access S3.
#                  Must contain ':user/' or ':role/'.
#                  Example (user): arn:aws:iam::123456789012:user/tebay-blog
#                  Example (role): arn:aws:iam::123456789012:role/tebay-blog
#
# Optional parameters:
#   --region       AWS region (default: us-east-1).
#   --access-point Access point name (not ARN) — if set, the IAM policy and
#                  access point policy are scoped to the access point instead
#                  of the bucket directly.
#   --policy-name  Name for the IAM managed policy (default: tebay-blog-s3).
#                  Reusing the same name on subsequent runs updates the policy
#                  in-place rather than creating a duplicate.
#   --create-user  Create the IAM user named in --principal before applying
#                  policies. Also generates an access key and prints the
#                  key ID and secret — save the secret immediately, it cannot
#                  be retrieved again. Skipped silently if the user exists.
#   --create-role  Create the IAM role named in --principal before applying
#                  policies. The role's trust policy is set via --trust.
#                  Skipped silently if the role already exists.
#   --trust        Which service or principal can assume the role created by
#                  --create-role (default: lambda.amazonaws.com).
#                  Pass a service name (e.g. ec2.amazonaws.com,
#                  ecs-tasks.amazonaws.com) or a full IAM ARN for
#                  cross-account / key-based assume-role.
#   --bucket-policy
#                  Apply a bucket policy that DENYs all direct S3 access,
#                  requiring every request to go through an access point.
#                  Only valid when --access-point is also set.
#                  WARNING: this denies access-point requests from accounts
#                  other than your own. Root and IAM roles are always exempt.
#                  Use with caution and ensure
#                  your access point is correctly configured first.
#                  When combined with --cf-video-policy, the Deny statement
#                  includes a CloudFront exception so videos/* remains
#                  accessible via OAC.
#   --cf-dist-id   CloudFront distribution ID (e.g. EXXXXXXXXXX). Required
#                  when --cf-video-policy is set.
#   --cf-video-policy
#                  Apply (or merge into) the bucket policy an Allow statement
#                  granting the CloudFront distribution (--cf-dist-id) OAC
#                  read access to videos/*. The S3 bucket remains private;
#                  CloudFront serves videos via Origin Access Control.
#                  When used with --bucket-policy, the access-point-only Deny
#                  is extended with a CloudFront exception so the two policies
#                  do not conflict.
#   --cf-s3-origin Add (or restore) the S3 bucket origin and a videos/*
#                  cache behavior to the CloudFront distribution. The origin
#                  uses the OAC named <bucket>.s3.amazonaws.com. Requires
#                  --cf-dist-id. Use this to wire up or recover the direct
#                  S3 → CloudFront path for video delivery.
#   --oac-id       Override the OAC ID used by --cf-s3-origin. If omitted,
#                  the OAC is looked up by name (<bucket>.s3.amazonaws.com).
#   --save-env     Write the key variables (AWS_ACCOUNT_ID, AWS_REGION,
#                  AWS_BUCKET or AWS_ACCESS_POINT_ARN, AWS_PRINCIPAL,
#                  AWS_POLICY_NAME) to your shell rc file (~/.bashrc,
#                  ~/.zshrc, or ~/.profile). Existing entries are updated
#                  in-place; new entries are appended. After running, source
#                  the file to apply changes to your current shell.
#   --dry-run      Print what would be created/changed without making any
#                  AWS API calls or writing to the shell rc file.
#
# Parameters can also be set as environment variables (same names):
#   AWS_ACCOUNT_ID, AWS_REGION, AWS_BUCKET, AWS_PRINCIPAL,
#   AWS_ACCESS_POINT, AWS_POLICY_NAME, CF_DIST_ID, OAC_ID

# ── Defaults ──────────────────────────────────────────────────────────────────
AWS_REGION="${AWS_REGION:-us-east-1}"
AWS_POLICY_NAME="${AWS_POLICY_NAME:-tebay-blog-s3}"
CF_DIST_ID="${CF_DIST_ID:-}"
OAC_ID="${OAC_ID:-}"
DRY_RUN=0
BUCKET_POLICY=0
CF_VIDEO_POLICY=0
CF_S3_ORIGIN=0
SAVE_ENV=0
CREATE_USER=0
CREATE_ROLE=0
TRUST_ENTITY="lambda.amazonaws.com"

# ── Argument parsing ──────────────────────────────────────────────────────────
usage() {
  sed -n '/^# Usage:/,/^[^#]/p' "$0" | grep '^#' | sed 's/^# \?//'
  exit 1
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --account-id)    AWS_ACCOUNT_ID="$2";   shift 2 ;;
    --region)        AWS_REGION="$2";       shift 2 ;;
    --bucket)        AWS_BUCKET="$2";       shift 2 ;;
    --access-point)  AWS_ACCESS_POINT="$2"; shift 2 ;;
    --principal)     AWS_PRINCIPAL="$2";    shift 2 ;;
    --policy-name)   AWS_POLICY_NAME="$2";  shift 2 ;;
    --create-user)   CREATE_USER=1;         shift   ;;
    --create-role)   CREATE_ROLE=1;         shift   ;;
    --trust)         TRUST_ENTITY="$2";     shift 2 ;;
    --bucket-policy)    BUCKET_POLICY=1;       shift   ;;
    --cf-dist-id)       CF_DIST_ID="$2";      shift 2 ;;
    --cf-video-policy)  CF_VIDEO_POLICY=1;    shift   ;;
    --cf-s3-origin)     CF_S3_ORIGIN=1;       shift   ;;
    --oac-id)           OAC_ID="$2";          shift 2 ;;
    --save-env)         SAVE_ENV=1;           shift   ;;
    --dry-run)          DRY_RUN=1;            shift   ;;
    -h|--help)       usage ;;
    *) echo "Unknown option: $1"; usage ;;
  esac
done

# ── Validate required parameters ──────────────────────────────────────────────
MISSING=""
[ -z "$AWS_ACCOUNT_ID" ] && MISSING="$MISSING --account-id"
[ -z "$AWS_BUCKET"     ] && MISSING="$MISSING --bucket"
[ -z "$AWS_PRINCIPAL"  ] && MISSING="$MISSING --principal"

if [ -n "$MISSING" ]; then
  echo "Error: missing required parameters:$MISSING"
  echo "Run with --help for usage."
  exit 1
fi

POLICY_ARN="arn:aws:iam::${AWS_ACCOUNT_ID}:policy/${AWS_POLICY_NAME}"

# ── Derived ARNs ──────────────────────────────────────────────────────────────
if [ -n "$AWS_ACCESS_POINT" ]; then
  AP_ARN="arn:aws:s3:${AWS_REGION}:${AWS_ACCOUNT_ID}:accesspoint/${AWS_ACCESS_POINT}"
fi

# Detect whether principal is a user or role
case "$AWS_PRINCIPAL" in
  *:user/*)  PRINCIPAL_TYPE="user" ;;
  *:role/*)  PRINCIPAL_TYPE="role" ;;
  *)
    echo "Error: --principal must be a full IAM ARN containing ':user/' or ':role/'"
    exit 1 ;;
esac

if [ "$CREATE_USER" = "1" ] && [ "$PRINCIPAL_TYPE" != "user" ]; then
  echo "Error: --create-user requires a ':user/' ARN in --principal"
  exit 1
fi
if [ "$CREATE_ROLE" = "1" ] && [ "$PRINCIPAL_TYPE" != "role" ]; then
  echo "Error: --create-role requires a ':role/' ARN in --principal"
  exit 1
fi
if [ "$CREATE_USER" = "1" ] && [ "$CREATE_ROLE" = "1" ]; then
  echo "Error: --create-user and --create-role are mutually exclusive"
  exit 1
fi
if [ "$CF_VIDEO_POLICY" = "1" ] && [ -z "$CF_DIST_ID" ]; then
  echo "Error: --cf-video-policy requires --cf-dist-id"
  exit 1
fi
if [ "$CF_S3_ORIGIN" = "1" ] && [ -z "$CF_DIST_ID" ]; then
  echo "Error: --cf-s3-origin requires --cf-dist-id"
  exit 1
fi

PRINCIPAL_NAME="${AWS_PRINCIPAL##*/}"

# ── Policy generators ─────────────────────────────────────────────────────────

# IAM policy: scoped to the access point (if set) or the bucket directly.
build_iam_policy() {
  if [ -n "$AWS_ACCESS_POINT" ]; then
    cat <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ListBlogPostsViaAccessPoint",
      "Effect": "Allow",
      "Action": [
        "s3:ListBucket"
      ],
      "Resource": "${AP_ARN}",
      "Condition": {
        "StringLike": {
          "s3:prefix": ["blog/posts/*", "blog/posts/"]
        }
      }
    },
    {
      "Sid": "ReadWriteBlogPostsViaAccessPoint",
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject"
      ],
      "Resource": "${AP_ARN}/object/blog/posts/*"
    }
  ]
}
EOF
  else
    cat <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ListBlogPosts",
      "Effect": "Allow",
      "Action": [
        "s3:ListBucket",
        "s3:GetBucketLocation"
      ],
      "Resource": "arn:aws:s3:::${AWS_BUCKET}",
      "Condition": {
        "StringLike": {
          "s3:prefix": ["blog/posts/*", "blog/posts/"]
        }
      }
    },
    {
      "Sid": "ReadWriteBlogPosts",
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject",
        "s3:CopyObject"
      ],
      "Resource": "arn:aws:s3:::${AWS_BUCKET}/blog/posts/*"
    }
  ]
}
EOF
  fi
}

# Access point policy: grants the principal access through the access point.
build_access_point_policy() {
  cat <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowBlogContainerAccess",
      "Effect": "Allow",
      "Principal": {
        "AWS": "${AWS_PRINCIPAL}"
      },
      "Action": [
        "s3:ListBucket"
      ],
      "Resource": "${AP_ARN}"
    },
    {
      "Sid": "AllowBlogContainerObjectAccess",
      "Effect": "Allow",
      "Principal": {
        "AWS": "${AWS_PRINCIPAL}"
      },
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject"
      ],
      "Resource": "${AP_ARN}/object/blog/posts/*"
    }
  ]
}
EOF
}

# Bucket policy: Allow CloudFront OAC to read videos/* directly from S3.
# Used standalone when --cf-video-policy is set without --bucket-policy.
build_cloudfront_bucket_policy() {
  cat <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowCloudFrontOACVideos",
      "Effect": "Allow",
      "Principal": {
        "Service": "cloudfront.amazonaws.com"
      },
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::${AWS_BUCKET}/videos/*",
      "Condition": {
        "StringEquals": {
          "AWS:SourceArn": "arn:aws:cloudfront::${AWS_ACCOUNT_ID}:distribution/${CF_DIST_ID}"
        }
      }
    }
  ]
}
EOF
}

# Bucket policy: restricts bucket access to go via access points only, with an
# optional CloudFront exception so videos/* remains accessible via OAC.
# Apply with caution — this blocks ALL direct bucket access for every principal
# not explicitly excepted.
build_bucket_policy() {
  if [ "$CF_VIDEO_POLICY" = "1" ]; then
    # Combined: access-point-only deny (with CF exception) + CF OAC allow
    cat <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowCloudFrontOACVideos",
      "Effect": "Allow",
      "Principal": {
        "Service": "cloudfront.amazonaws.com"
      },
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::${AWS_BUCKET}/videos/*",
      "Condition": {
        "StringEquals": {
          "AWS:SourceArn": "arn:aws:cloudfront::${AWS_ACCOUNT_ID}:distribution/${CF_DIST_ID}"
        }
      }
    },
    {
      "Sid": "EnforceAccessPointOnly",
      "Effect": "Deny",
      "Principal": "*",
      "Action": "s3:*",
      "Resource": [
        "arn:aws:s3:::${AWS_BUCKET}",
        "arn:aws:s3:::${AWS_BUCKET}/*"
      ],
      "Condition": {
        "Null": {
          "s3:DataAccessPointAccount": "false"
        },
        "StringNotEquals": {
          "s3:DataAccessPointAccount": "${AWS_ACCOUNT_ID}"
        },
        "ArnNotLike": {
          "aws:PrincipalArn": [
            "arn:aws:iam::${AWS_ACCOUNT_ID}:root",
            "arn:aws:iam::${AWS_ACCOUNT_ID}:role/*"
          ],
          "aws:SourceArn": "arn:aws:cloudfront::${AWS_ACCOUNT_ID}:distribution/${CF_DIST_ID}"
        }
      }
    }
  ]
}
EOF
  else
    cat <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "EnforceAccessPointOnly",
      "Effect": "Deny",
      "Principal": "*",
      "Action": "s3:*",
      "Resource": [
        "arn:aws:s3:::${AWS_BUCKET}",
        "arn:aws:s3:::${AWS_BUCKET}/*"
      ],
      "Condition": {
        "Null": {
          "s3:DataAccessPointAccount": "false"
        },
        "StringNotEquals": {
          "s3:DataAccessPointAccount": "${AWS_ACCOUNT_ID}"
        },
        "ArnNotLike": {
          "aws:PrincipalArn": [
            "arn:aws:iam::${AWS_ACCOUNT_ID}:root",
            "arn:aws:iam::${AWS_ACCOUNT_ID}:role/*"
          ]
        }
      }
    }
  ]
}
EOF
  fi
}

# Trust policy for an IAM role. TRUST_ENTITY may be a service (foo.amazonaws.com)
# or an IAM ARN (arn:aws:iam::...) for cross-account / key-based assume-role.
build_trust_policy() {
  case "$TRUST_ENTITY" in
    arn:*)
      cat <<EOF
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": { "AWS": "${TRUST_ENTITY}" },
    "Action": "sts:AssumeRole"
  }]
}
EOF
      ;;
    *)
      cat <<EOF
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": { "Service": "${TRUST_ENTITY}" },
    "Action": "sts:AssumeRole"
  }]
}
EOF
      ;;
  esac
}

# ── Helpers ───────────────────────────────────────────────────────────────────
# Detect the user's shell rc file (bash preferred, fallback to profile).
_shell_rc() {
  if [ -f "${HOME}/.bashrc" ]; then
    printf '%s' "${HOME}/.bashrc"
  elif [ -f "${HOME}/.zshrc" ]; then
    printf '%s' "${HOME}/.zshrc"
  else
    printf '%s' "${HOME}/.profile"
  fi
}

# Write or update a single "export VAR=value" line in the shell rc file.
# persist_env <var_name> <value>
persist_env() {
  local var="$1" val="$2" rc
  rc=$(_shell_rc)
  if grep -q "^export ${var}=" "${rc}" 2>/dev/null; then
    sed -i "s|^export ${var}=.*|export ${var}=\"${val}\"|" "${rc}"
    ok "Updated ${var} in ${rc}"
  else
    printf 'export %s="%s"\n' "${var}" "${val}" >> "${rc}"
    ok "Added ${var} to ${rc}"
  fi
}

section() { printf '\n\033[1;32m==> %s\033[0m\n' "$*"; }
info()    { printf '    %s\n' "$*"; }
ok()      { printf '    \033[32m✓\033[0m %s\n' "$*"; }
warn()    { printf '    \033[33m!\033[0m %s\n' "$*"; }
err()     { printf '    \033[31m✗\033[0m %s\n' "$*"; }

# Create or update an IAM managed policy.
apply_iam_policy() {
  local policy_json="$1"

  if aws iam get-policy --policy-arn "$POLICY_ARN" >/dev/null 2>&1; then
    info "Policy exists; creating new version..."
    aws iam create-policy-version \
      --policy-arn "$POLICY_ARN" \
      --policy-document "$policy_json" \
      --set-as-default >/dev/null
    # Prune old non-default versions (IAM cap is 5)
    aws iam list-policy-versions --policy-arn "$POLICY_ARN" \
      --query 'Versions[?!IsDefaultVersion].VersionId' \
      --output text \
    | tr '\t' '\n' \
    | while read -r vid; do
        aws iam delete-policy-version \
          --policy-arn "$POLICY_ARN" --version-id "$vid" >/dev/null 2>&1 || true
      done
    ok "Updated $POLICY_ARN"
  else
    aws iam create-policy \
      --policy-name "$AWS_POLICY_NAME" \
      --policy-document "$policy_json" \
      --description "Minimal S3 access for tebay.dev blog container (blog/posts/* only)" \
      >/dev/null
    ok "Created $POLICY_ARN"
  fi
}

# Attach the IAM policy to the principal (user or role).
attach_iam_policy() {
  if [ "$PRINCIPAL_TYPE" = "user" ]; then
    aws iam attach-user-policy \
      --user-name "$PRINCIPAL_NAME" \
      --policy-arn "$POLICY_ARN" >/dev/null
  else
    aws iam attach-role-policy \
      --role-name "$PRINCIPAL_NAME" \
      --policy-arn "$POLICY_ARN" >/dev/null
  fi
  ok "Attached to $PRINCIPAL_TYPE $PRINCIPAL_NAME"
}

# Create an IAM user and print its access keys.
create_iam_user() {
  if aws iam get-user --user-name "$PRINCIPAL_NAME" >/dev/null 2>&1; then
    warn "User $PRINCIPAL_NAME already exists — skipping creation"
  else
    aws iam create-user --user-name "$PRINCIPAL_NAME" >/dev/null
    ok "Created user $PRINCIPAL_NAME"
  fi

  info "Creating access key..."
  local key_output
  key_output=$(aws iam create-access-key \
    --user-name "$PRINCIPAL_NAME" \
    --query 'AccessKey.[AccessKeyId,SecretAccessKey]' \
    --output text)
  local key_id secret
  key_id=$(printf '%s' "$key_output"  | cut -f1)
  secret=$(printf '%s' "$key_output"  | cut -f2)
  ok "Access key created"
  info ""
  info "  AWS_ACCESS_KEY_ID=${key_id}"
  info "  AWS_SECRET_ACCESS_KEY=${secret}"
  info ""
  warn "Save the secret now — it cannot be retrieved again."
}

# Create an IAM role with a trust policy.
create_iam_role() {
  local trust_json
  trust_json=$(build_trust_policy)

  if aws iam get-role --role-name "$PRINCIPAL_NAME" >/dev/null 2>&1; then
    warn "Role $PRINCIPAL_NAME already exists — skipping creation"
  else
    aws iam create-role \
      --role-name "$PRINCIPAL_NAME" \
      --assume-role-policy-document "$trust_json" \
      --description "tebay.dev blog container role" \
      >/dev/null
    ok "Created role $PRINCIPAL_NAME (trust: $TRUST_ENTITY)"
  fi
}

# Add/restore the S3 bucket origin (with OAC) and videos/* cache behavior in
# the CloudFront distribution. Idempotent: skips entries that already exist.
apply_cf_s3_origin() {
  local oac_id="$OAC_ID"
  local oac_name="${AWS_BUCKET}.s3.amazonaws.com"

  # Look up OAC by name if not provided
  if [ -z "$oac_id" ]; then
    oac_id=$(aws cloudfront list-origin-access-controls \
      --query "OriginAccessControlList.Items[?Name=='${oac_name}'].Id" \
      --output text 2>/dev/null)
    if [ -z "$oac_id" ] || [ "$oac_id" = "None" ]; then
      err "No OAC found named '${oac_name}'. Create one first or pass --oac-id."
      return 1
    fi
  fi
  info "OAC ID : $oac_id"

  local s3_origin_id="${AWS_BUCKET}.s3.amazonaws.com-oac"
  local s3_domain="${AWS_BUCKET}.s3.amazonaws.com"

  local etag
  etag=$(aws cloudfront get-distribution-config \
    --id "$CF_DIST_ID" --query ETag --output text)

  local new_config
  new_config=$(python3 <<PYEOF
import json, subprocess, sys

dist = json.loads(subprocess.check_output([
  'aws', 'cloudfront', 'get-distribution-config',
  '--id', '${CF_DIST_ID}', '--output', 'json'
]))
config = dist['DistributionConfig']
origin_id = '${s3_origin_id}'
domain    = '${s3_domain}'
oac_id    = '${oac_id}'

# Add S3 origin if not already present
origins = config['Origins']['Items']
if not any(o['DomainName'] == domain for o in origins):
    origins.append({
        'Id': origin_id,
        'DomainName': domain,
        'OriginPath': '',
        'CustomHeaders': {'Quantity': 0},
        'S3OriginConfig': {'OriginAccessIdentity': ''},
        'OriginAccessControlId': oac_id,
        'ConnectionAttempts': 3,
        'ConnectionTimeout': 10,
        'OriginShield': {'Enabled': False}
    })
    config['Origins']['Quantity'] = len(origins)

# Add videos/* cache behavior if not already present
cb = config.setdefault('CacheBehaviors', {'Quantity': 0, 'Items': []})
cb.setdefault('Items', [])
if not any(b['PathPattern'] == 'videos/*' for b in cb['Items']):
    cb['Items'].append({
        'PathPattern': 'videos/*',
        'TargetOriginId': origin_id,
        'ViewerProtocolPolicy': 'redirect-to-https',
        'TrustedSigners': {'Enabled': False, 'Quantity': 0},
        'TrustedKeyGroups': {'Enabled': False, 'Quantity': 0},
        'AllowedMethods': {
            'Quantity': 2,
            'Items': ['HEAD', 'GET'],
            'CachedMethods': {'Quantity': 2, 'Items': ['HEAD', 'GET']}
        },
        'SmoothStreaming': False,
        'Compress': True,
        'LambdaFunctionAssociations': {'Quantity': 0},
        'FunctionAssociations': {'Quantity': 0},
        'FieldLevelEncryptionId': '',
        'CachePolicyId': '658327ea-f89d-4fab-a63d-7e88639e58f6'
    })
    cb['Quantity'] = len(cb['Items'])

print(json.dumps(config))
PYEOF
  )

  aws cloudfront update-distribution \
    --id "$CF_DIST_ID" \
    --if-match "$etag" \
    --distribution-config "$new_config" \
    --query 'Distribution.Status' \
    --output text >/dev/null \
    && ok "CloudFront distribution updated — deploying (may take a few minutes)" \
    || err "Failed to update CloudFront distribution"
}

# ── Main ──────────────────────────────────────────────────────────────────────
section "tebay.dev blog — AWS policy setup"
info "AWS_ACCOUNT_ID  : $AWS_ACCOUNT_ID"
info "AWS_REGION      : $AWS_REGION"
info "AWS_BUCKET      : $AWS_BUCKET"
info "AWS_PRINCIPAL   : $AWS_PRINCIPAL ($PRINCIPAL_TYPE)"
info "AWS_POLICY_NAME : $AWS_POLICY_NAME"
[ -n "$AWS_ACCESS_POINT" ] && info "AWS_ACCESS_POINT: $AWS_ACCESS_POINT"
[ -n "$CF_DIST_ID" ]       && info "CF_DIST_ID      : $CF_DIST_ID"
[ "$CREATE_ROLE" = "1" ]   && info "TRUST_ENTITY    : $TRUST_ENTITY"
[ "$DRY_RUN" = "1" ]       && warn "Dry-run mode — no changes will be made"

# ── 0. Create principal (optional) ────────────────────────────────────────────
if [ "$CREATE_USER" = "1" ] || [ "$CREATE_ROLE" = "1" ]; then
  section "0. Creating IAM principal"
  if [ "$DRY_RUN" = "1" ]; then
    if [ "$CREATE_USER" = "1" ]; then
      info "Would create IAM user: $PRINCIPAL_NAME"
      info "Would create access key for: $PRINCIPAL_NAME"
    else
      info "Would create IAM role: $PRINCIPAL_NAME"
      info "Trust policy document:"
      build_trust_policy
    fi
  else
    if [ "$CREATE_USER" = "1" ]; then
      create_iam_user
    else
      create_iam_role
    fi
  fi
fi

# ── 1. IAM policy ─────────────────────────────────────────────────────────────
section "1. IAM policy"
IAM_POLICY_JSON=$(build_iam_policy)

if [ "$DRY_RUN" = "1" ]; then
  info "IAM policy document:"
  echo "$IAM_POLICY_JSON"
else
  apply_iam_policy "$IAM_POLICY_JSON"
  attach_iam_policy
fi

# ── 2. Access point policy ────────────────────────────────────────────────────
if [ -n "$AWS_ACCESS_POINT" ]; then
  section "2. Access point policy ($AWS_ACCESS_POINT)"
  AP_POLICY_JSON=$(build_access_point_policy)

  if [ "$DRY_RUN" = "1" ]; then
    info "Access point policy document:"
    echo "$AP_POLICY_JSON"
  else
    aws s3control put-access-point-policy \
      --account-id "$AWS_ACCOUNT_ID" \
      --name "$AWS_ACCESS_POINT" \
      --policy "$AP_POLICY_JSON" >/dev/null \
      && ok "Applied access point policy" \
      || err "Failed to apply access point policy (check it exists in $AWS_REGION)"
  fi
fi

# ── 3. Bucket policy (optional) ───────────────────────────────────────────────
if ([ -n "$AWS_ACCESS_POINT" ] && [ "$BUCKET_POLICY" = "1" ]) || [ "$CF_VIDEO_POLICY" = "1" ]; then
  if [ "$BUCKET_POLICY" = "1" ] && [ "$CF_VIDEO_POLICY" = "1" ]; then
    section "3. Bucket policy (access-point-only + CloudFront OAC for videos/*)"
    warn "This will DENY all direct bucket access except via the access point or CloudFront."
    warn "Existing bucket policies will be replaced."
    BP_JSON=$(build_bucket_policy)
  elif [ "$BUCKET_POLICY" = "1" ]; then
    section "3. Bucket policy (enforce access-point-only)"
    warn "This will DENY all direct bucket access for every principal."
    warn "Existing bucket policies will be replaced."
    BP_JSON=$(build_bucket_policy)
  else
    section "3. Bucket policy (CloudFront OAC for videos/*)"
    info "Allows CloudFront distribution $CF_DIST_ID to read videos/* via OAC."
    warn "Existing bucket policies will be replaced."
    BP_JSON=$(build_cloudfront_bucket_policy)
  fi

  if [ "$DRY_RUN" = "1" ]; then
    info "Bucket policy document:"
    echo "$BP_JSON"
  else
    aws s3api put-bucket-policy \
      --bucket "$AWS_BUCKET" \
      --policy "$BP_JSON" >/dev/null \
      && ok "Applied bucket policy" \
      || err "Failed to apply bucket policy"
  fi
fi

# ── 4. CloudFront S3 origin for videos/* (optional) ───────────────────────────
if [ "$CF_S3_ORIGIN" = "1" ]; then
  section "4. CloudFront S3 origin (videos/*)"
  info "Distribution : $CF_DIST_ID"
  info "Bucket origin: ${AWS_BUCKET}.s3.amazonaws.com"
  if [ "$DRY_RUN" = "1" ]; then
    info "Would add S3 origin and videos/* cache behavior to $CF_DIST_ID"
  else
    apply_cf_s3_origin
  fi
fi

# ── 5. Persist env vars ───────────────────────────────────────────────────────
if [ "$SAVE_ENV" = "1" ]; then
  section "5. Saving environment variables"
  if [ "$DRY_RUN" = "1" ]; then
    info "Would write to $(_shell_rc):"
    info "  export AWS_ACCOUNT_ID=\"${AWS_ACCOUNT_ID}\""
    info "  export AWS_REGION=\"${AWS_REGION}\""
    if [ -n "$AWS_ACCESS_POINT" ]; then
      info "  export AWS_ACCESS_POINT_ARN=\"${AP_ARN}\""
    else
      info "  export AWS_BUCKET=\"${AWS_BUCKET}\""
    fi
    info "  export AWS_PRINCIPAL=\"${AWS_PRINCIPAL}\""
    info "  export AWS_POLICY_NAME=\"${AWS_POLICY_NAME}\""
  else
    persist_env AWS_ACCOUNT_ID   "${AWS_ACCOUNT_ID}"
    persist_env AWS_REGION       "${AWS_REGION}"
    if [ -n "$AWS_ACCESS_POINT" ]; then
      persist_env AWS_ACCESS_POINT_ARN "${AP_ARN}"
    else
      persist_env AWS_BUCKET     "${AWS_BUCKET}"
    fi
    persist_env AWS_PRINCIPAL    "${AWS_PRINCIPAL}"
    persist_env AWS_POLICY_NAME  "${AWS_POLICY_NAME}"
    info "Run: source $(_shell_rc)"
  fi
fi

# ── Done ──────────────────────────────────────────────────────────────────────
section "Done"
if [ "$DRY_RUN" = "0" ]; then
  info "Container env vars to set:"
  if [ -n "$AWS_ACCESS_POINT" ]; then
    info "  AWS_ACCESS_POINT_ARN=${AP_ARN}"
  else
    info "  AWS_BUCKET=${AWS_BUCKET}"
  fi
  info "  AWS_REGION=${AWS_REGION}"
  info "  AWS_ACCESS_KEY_ID=<key for $PRINCIPAL_NAME>"
  info "  AWS_SECRET_ACCESS_KEY=<secret for $PRINCIPAL_NAME>"
fi
