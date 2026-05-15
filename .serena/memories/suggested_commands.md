# Suggested Commands — PersonalSite

## Development
```bash
./dev.sh                          # Start dev containers (site + MinIO) — http://localhost:8888, dev password: Password123
podman rm -f personalsite personalsite-minio   # Stop dev environment
```

## Linting / Formatting
- JS: StandardJS (`npx standard assets/*.js`)
- General: Prettier (`npx prettier --write .`)
- No test suite; validate with `scripts/validate-site.py`
- Smoke check: `scripts/smoke-check.sh`

## Build & Deploy
```bash
scripts/deploy-lambda.sh          # Build, push to ECR, update Lambda
scripts/aws-setup.sh              # Configure AWS IAM, S3, CloudFront
scripts/generate-credentials.sh  # Generate/apply ADMIN_TOKEN
```

## Container Commands
```bash
podman build -f Dockerfile -t personalsite .        # Prod image
podman build -f Dockerfile.dev -t personalsite-dev . # Dev image
```

## Utilities
```bash
git log --oneline -10
find . -name "*.html"
grep -r "pattern" assets/
```
