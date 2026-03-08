FROM alpine:latest

RUN apk add --no-cache busybox-extras && \
    ARCH=$(uname -m | sed 's/x86_64/amd64/;s/aarch64/arm64/') && \
    wget -qO /usr/local/bin/mc \
      "https://dl.min.io/client/mc/release/linux-${ARCH}/mc" && \
    chmod +x /usr/local/bin/mc

RUN mkdir -p /var/www/html /var/www/html/blog/posts
COPY . /var/www/html/

# Entrypoint and sync helper live outside the web root
RUN cp /var/www/html/docker-entrypoint.sh /usr/local/bin/entrypoint.sh && \
    cp /var/www/html/sync-posts.sh        /usr/local/bin/sync-posts.sh && \
    chmod +x \
      /usr/local/bin/entrypoint.sh \
      /usr/local/bin/sync-posts.sh \
      /var/www/html/config.cgi \
      /var/www/html/admin/cgi-bin/save.cgi \
      /var/www/html/admin/cgi-bin/delete.cgi \
      /var/www/html/admin/cgi-bin/publish.cgi \
      /var/www/html/admin/cgi-bin/posts.cgi \
      /var/www/html/admin/cgi-bin/upload.cgi \
      /var/www/html/admin/cgi-bin/images.cgi \
      /var/www/html/admin/cgi-bin/delete-image.cgi


COPY .credentials /etc/httpd.conf
RUN printf '.webp:image/webp\n.mp4:video/mp4\n' >> /etc/httpd.conf

EXPOSE 8080

# Required env vars at runtime:
#   AWS_REGION            — AWS region (default: us-east-1)
#   AWS_ACCESS_KEY_ID     — AWS credentials (or use an IAM role / instance profile)
#   AWS_SECRET_ACCESS_KEY
#
# Required env var for the S3 target:
#   AWS_BUCKET            — plain bucket name (e.g. my-bucket)
#
ENV STORAGE=s3

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["httpd", "-f", "-p", "8080", "-h", "/var/www/html", "-c", "/etc/httpd.conf"]
