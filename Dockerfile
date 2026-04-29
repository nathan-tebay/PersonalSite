# Production image — runs against AWS S3 (Lambda-compatible).
# Multi-stage: dev stage builds and validates, prod stage is minimal.

# ── Stage 1: Build & validate ────────────────────────────────────────────────
FROM alpine:latest AS build

RUN apk add --no-cache busybox-extras aws-cli jq

RUN mkdir -p /var/www/html /var/www/html/blog/posts
COPY . /var/www/html/

# Validate CGI scripts have correct permissions
RUN chmod +x \
      /var/www/html/config.cgi \
      /var/www/html/cgi-bin/*.cgi \
      /var/www/html/cgi-bin/*.sh

# ── Stage 2: Production runtime ─────────────────────────────────────────────
FROM alpine:latest

RUN apk add --no-cache busybox-extras aws-cli jq

RUN mkdir -p /var/www/html /var/www/html/blog/posts

# Copy only necessary files from build stage
COPY --from=build /var/www/html /var/www/html

# Copy scripts to known locations
RUN cp /var/www/html/docker-entrypoint.sh /usr/local/bin/entrypoint.sh && \
    cp /var/www/html/sync-posts.sh        /usr/local/bin/sync-posts.sh && \
    chmod +x \
      /usr/local/bin/entrypoint.sh \
      /usr/local/bin/sync-posts.sh \
      /var/www/html/config.cgi \
      /var/www/html/cgi-bin/*.cgi \
      /var/www/html/cgi-bin/*.sh

# httpd content-type config
RUN printf '.webp:image/webp\n.mp4:video/mp4\n' > /etc/httpd.conf

EXPOSE 8080

COPY --from=public.ecr.aws/awsguru/aws-lambda-adapter:0.8.4 /lambda-adapter /opt/extensions/lambda-adapter

# STORAGE=s3: CGI scripts read/write via AWS CLI (Lambda STS credentials).
# Mount a local directory to persist posts across invocations:
#   podman run -p 8080:8080 -v ./posts:/var/www/html/blog/posts:Z tebay-site
ENV STORAGE=s3
ENV PORT=8080
# Give the entrypoint time to fetch index files before accepting requests.
ENV AWS_LWA_READINESS_CHECK_TIMEOUT=15

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["httpd", "-f", "-p", "8080", "-h", "/tmp/www", "-c", "/etc/httpd.conf"]
