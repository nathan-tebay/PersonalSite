FROM alpine:latest

RUN apk add --no-cache busybox-extras aws-cli

RUN mkdir -p /var/www/html /var/www/html/blog/posts
COPY . /var/www/html/

# Entrypoint and sync helper live outside the web root
RUN cp /var/www/html/docker-entrypoint.sh /usr/local/bin/entrypoint.sh && \
    cp /var/www/html/sync-posts.sh        /usr/local/bin/sync-posts.sh && \
    chmod +x \
      /usr/local/bin/entrypoint.sh \
      /usr/local/bin/sync-posts.sh \
      /var/www/html/config.cgi \
      /var/www/html/cgi-bin/*.cgi \
      /var/www/html/cgi-bin/*.sh

RUN printf '.webp:image/webp\n.mp4:video/mp4\n' > /etc/httpd.conf

EXPOSE 8080

# Required env vars at runtime:
#   AWS_REGION            — AWS region (default: us-east-1)
#   AWS_ACCESS_KEY_ID     — AWS credentials (or use an IAM role / instance profile)
#   AWS_SECRET_ACCESS_KEY
#
# Required env var for the S3 target:
#   AWS_BUCKET            — plain bucket name (e.g. my-bucket)
#
COPY --from=public.ecr.aws/awsguru/aws-lambda-adapter:0.8.4 /lambda-adapter /opt/extensions/lambda-adapter

ENV STORAGE=s3
ENV PORT=8080
# Give the entrypoint time to fetch index files before accepting requests
ENV AWS_LWA_READINESS_CHECK_TIMEOUT=15

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["httpd", "-f", "-p", "8080", "-h", "/tmp/www", "-c", "/etc/httpd.conf"]
