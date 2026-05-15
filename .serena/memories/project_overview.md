# PersonalSite — Project Overview

Personal portfolio site for **tebay.dev**. Vanilla HTML/CSS/JS, no build step, no framework. Circuit-board aesthetic, dynamic navigation, multi-theme colour picker, blog, links system, and admin panel.

## Tech Stack
- **Frontend**: Vanilla HTML/CSS/JS (no frameworks, no npm, no build step)
- **Backend**: Apache httpd with CGI shell scripts
- **Storage**: MinIO (dev, S3-compatible) or AWS S3 (prod)
- **Containers**: Podman (never docker) — rootless preferred
- **Deployment**: AWS Lambda container image + CloudFront CDN

## Key Entry Points
- `index.html` — home page
- `blog.html` / `blog-post.html` — blog
- `links.html` — public bookmarks
- `admin/index.html` — admin panel (session-protected)
- `config.cgi` — public API: returns storage mode & posts URL

## Runtime Modes
| `STORAGE` env var | Backend | Use |
|---|---|---|
| `local` | filesystem | dev |
| `s3` | AWS S3 / MinIO | prod |
