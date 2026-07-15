# Suggested Commands — PersonalSite

## Development
```bash
./dev.sh                          # Start dev containers (site + MinIO): http://localhost:8888, dev password: Password123
podman rm -f personalsite personalsite-minio   # Stop dev environment
```

## Linting / Formatting
```bash
XDG_CACHE_HOME=/tmp npx standard assets/*.js
npx prettier --write <touched-files>
python3 scripts/validate-site.py
scripts/smoke-check.sh
```

## Build & Deploy
Run deploy/setup commands only when user explicitly asks for deployment/infrastructure changes.
```bash
scripts/deploy-lambda.sh          # Build, push to ECR, update Lambda
scripts/aws-setup.sh              # Configure AWS IAM, S3, CloudFront
scripts/generate-credentials.sh   # Generate/apply ADMIN_TOKEN
```

## Container Commands
```bash
podman build -f Dockerfile -t personalsite .
podman build -f Dockerfile.dev -t personalsite-dev .
```

## Utilities
```bash
git log --oneline -10
find . -name "*.html"
grep -r "pattern" assets/
```