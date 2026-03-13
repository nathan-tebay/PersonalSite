# Tebay.dev — Personal Portfolio Site

A hand-rolled static portfolio website with vanilla HTML, CSS, and JavaScript—no frameworks, no build step. Features a dynamic navigation system, multi-theme colour picker, a blog and links system with S3-backed storage, admin panel, and containerised deployment options.

**Live site:** https://tebay.dev

## Features

- **Static site** — Pure HTML/CSS/JS, no build tools or dependencies
- **Dynamic navigation** — Injected by `assets/layout.js` and includes header, collapsible menu groups, and mobile hamburger toggle
- **Multi-theme colour picker** — Persisted to localStorage; theme preference is remembered across sessions
- **Blog system**
  - Storage backends: MinIO S3-compatible (local dev) or AWS S3 (production)
  - Admin panel at `/admin/` for creating, editing, and publishing posts
  - Public blog listing at `/blog.html` with post detail pages
  - WIP (work-in-progress) placeholder posts support
- **Links system**
  - Public links page at `/links.html` with categorized bookmarks
  - Admin panel for managing link categories and cards
  - S3-backed storage with cold-start reliability
- **Project portfolio** — Dedicated project pages in `projects/` subdirectory:
  - DBFirstDataGrid
  - AutoRejection
  - MicrophoneController
  - WhisperTranscribe
  - PersonalSite (this project)
- **Containerised serving** — Podman/Docker support with dev setup using local MinIO (S3-compatible) and production using AWS S3

## Project Structure

```
/
├── index.html                 # Home page
├── blog.html                  # Blog listing
├── blog-post.html             # Blog post detail page (slug-based routing)
├── favicon.svg
├── tebay-dev.svg              # Logo
│
├── assets/
│   ├── style.css              # Global styles and theme definitions
│   ├── script.js              # General page interactions
│   ├── layout.js              # Navigation injection & theme picker setup
│   └── blog-storage.js        # localStorage-backed blog store (local mode only)
│
├── projects/
│   ├── dbfirstgrid.html       # DBFirstDataGrid project page
│   ├── autorejection.html     # AutoRejection project page
│   ├── microphonecontroller.html
│   ├── whispertranscribe.html
│   └── personalsite.html      # This project
│
├── admin/
│   └── index.html             # Admin panel (protected by session auth; tabs: Blog, Links)
│
├── cgi-bin/
│   ├── login.cgi              # Login form and credential validation
│   ├── logout.cgi             # Logout and clear session cookie
│   ├── save.cgi               # Save draft post (session-protected)
│   ├── delete.cgi             # Delete post (session-protected)
│   ├── publish.cgi            # Publish/unpublish post (session-protected)
│   ├── posts.cgi              # List all posts (session-protected)
│   ├── links.cgi              # Load/save links.json (session-protected)
│   ├── upload.cgi             # Upload images (session-protected)
│   ├── images.cgi             # List uploaded images (session-protected)
│   ├── delete-image.cgi       # Delete image (session-protected)
│   ├── session.sh             # Session auth enforcement (sourced by CGI scripts)
│   └── storage.sh             # Storage backend helper
│
├── blog/
│   └── posts/                 # Post files (created at runtime)
│
├── links.html                 # Public links/bookmarks page
├── links.json                 # Links data file (categories and link cards)
│
├── dev.sh                     # Start dev containers (site + MinIO S3)
├── Dockerfile                 # Prod image (Lambda, S3 storage, AWS Lambda Web Adapter)
├── Dockerfile.dev             # Dev image (local storage or MinIO)
├── docker-entrypoint.sh       # Container startup logic
├── sync-posts.sh              # S3 ↔ local cache sync (prod only)
├── config.cgi                 # Public API: returns storage mode & posts URL
├── .credentials               # httpd MIME types and auth config (generated/copied)
│
├── scripts/
│   ├── deploy-lambda.sh       # Build, push to ECR, update Lambda function
│   ├── generate-credentials.sh # Generate and apply ADMIN_TOKEN to Lambda
│   └── aws-setup.sh           # Configure AWS IAM, S3, and CloudFront
```

## Getting Started

### Local Development

**Prerequisite:** Podman or Docker installed.

```bash
./dev.sh
```

This script:

1. Stops any existing `personalsite` and `personalsite-minio` containers
2. Creates a Podman network (`personalsite-dev`)
3. Builds the dev image (`Dockerfile.dev`)
4. Launches two containers:
   - **MinIO** — S3-compatible storage on port 9000/9001 (console: `minioadmin` / `minioadmin`)
   - **Site** — Served on `http://localhost:8888` with live editing

Both containers run in the background (detached) and are non-blocking.

**Blog storage in dev mode:**

- Blog posts are stored locally (file-backed) via `STORAGE=local`
- Admin panel at `http://localhost:8888/admin/` with cookie-based session auth
- Dev password: `Password123` (pre-configured `ADMIN_TOKEN` in `dev.sh`)
- Posts persist in the local blog directory and survive container restarts

**Admin authentication:**

The site uses cookie-based session authentication (located at root `/cgi-bin/`, not under `/admin/`):
- `/cgi-bin/login.cgi` — Login form and credential validation
- `/cgi-bin/logout.cgi` — Clears session cookie
- Session token is SHA-256(password), passed in `admin_session` cookie
- `ADMIN_TOKEN` environment variable holds the hash (never raw password)

**Stopping the dev environment:**

```bash
podman rm -f personalsite personalsite-minio
```

This removes both containers. The network persists but will be cleaned up by Podman automatically.

### Production Deployment

The site is deployed as an AWS Lambda function using a container image with the AWS Lambda Web Adapter.

**Build and deploy with the helper script:**

```bash
./scripts/deploy-lambda.sh \
  [--account-id 123456789012] \
  [--region us-east-1] \
  [--repo ntebay/personalsite] \
  [--function personalSite] \
  [--tag latest]
```

The script:
1. Authenticates podman with ECR
2. Builds the container image (linux/amd64)
3. Pushes to ECR
4. Updates the Lambda function with the new image

**Manual deployment:**

```bash
podman build -f Dockerfile -t tebay-site:latest .
```

Required environment variables (set on the Lambda function):

- `STORAGE` — Set to `s3` (default in Dockerfile)
- `AWS_REGION` — AWS region (default: `us-east-1`)
- `AWS_ACCESS_KEY_ID` — AWS credentials
- `AWS_SECRET_ACCESS_KEY` — AWS credentials
- `AWS_BUCKET` — S3 bucket name (e.g. `my-bucket`)
- `ADMIN_TOKEN` — SHA-256 hash of the admin password (generated via `./scripts/generate-credentials.sh`)

Or use an S3 Access Point ARN (recommended) instead of `AWS_BUCKET`:

```
AWS_ACCESS_POINT_ARN=arn:aws:s3:us-east-1:123456789012:accesspoint/my-ap
```

**Container behavior:**

- Listens on port 8080 (inside Lambda, port is abstracted via Lambda Web Adapter)
- Web root is copied to `/tmp/www` at startup; httpd serves from `/tmp/www`
- Blog posts are cached locally at `/tmp/www/blog/posts` and synced from S3 on startup
- `links.json` is fetched from S3 to `/tmp/www/links.json` on cold start (if missing)
- All content is served from the local cache (never directly from S3)
- Requires `STORAGE=s3` environment variable (set by default in `Dockerfile`)

## Configuration

### Storage Mode

The site operates in two storage modes, set via the `STORAGE` environment variable:

| Mode    | Location                  | Use Case       | Persistence              |
|---------|---------------------------|----------------|--------------------------|
| `local` | Local file system         | Dev            | Persistent across restarts |
| `s3`    | AWS S3                    | Production     | Persistent across restarts |

The `config.cgi` endpoint returns the active storage mode and post URL:

```bash
curl http://localhost:8888/config.cgi
# {"postsUrl":"/blog/posts","storage":"local"}
```

### Admin Authentication

Admin credentials are managed via the `ADMIN_TOKEN` environment variable (set on the Lambda function or container):

**Generate a token:**

```bash
./scripts/generate-credentials.sh
```

This prompts for a password, computes its SHA-256 hash, and displays the token.

**Apply to Lambda:**

```bash
./scripts/generate-credentials.sh --apply --function personalSite --region us-east-1
```

This automatically updates the Lambda function's `ADMIN_TOKEN` environment variable.

### Theme Customization

The site features six curated colour swatches (dark tones) accessible via swatch buttons in the navigation. The theme picker (injected by `layout.js`) persists the selection to localStorage under the key `tebay_theme`.

CSS custom properties are dynamically computed from the selected swatch:
- `--text-high`, `--text-mid`, `--text-low`, `--text-link`, `--divider`, `--hover-bg` are calculated based on the swatch's relative luminance for optimal contrast

See `CLAUDE.md` for details on the colour computation algorithm.

### Blog Post Schema

Blog posts (stored as JSON) have the following structure:

```json
{
  "slug": "my-project",
  "title": "My Awesome Project",
  "date": "2025-02-15",
  "desc": "A short description for the listing",
  "content": "<h2>Heading</h2><p>Full HTML content…</p>",
  "published": true,
  "wip": false
}
```

**Fields:**
- `slug` — URL-safe identifier (used in post detail URLs)
- `title` — Post title
- `date` — ISO date string (YYYY-MM-DD)
- `desc` — Short description shown in blog listing
- `content` — Full HTML content (sanitised by admin panel)
- `published` — Whether the post is visible to the public
- `wip` — Work-in-progress flag; shows as "Coming soon" on public listing

## Admin Panel

Access at `/admin/index.html` — redirects to `/cgi-bin/login.cgi` if not authenticated.

**Features:**
- **Blog tab** — Create, edit, publish, and delete blog posts with preview
- **Links tab** — Manage categorized links:
  - Add/rename/delete/reorder categories (with ▲/▼ buttons)
  - Add link cards with title, URL, and multi-line description
  - New links appear at the top of the list
  - Save posts and links with session-protected endpoints
- WIP placeholder posts (shown on public listing with "Coming soon" label)

**Login flow:**

1. Visit `/admin/` → redirected to `/cgi-bin/login.cgi`
2. Enter admin password
3. On success, `admin_session` cookie is set (contains SHA-256 hash)
4. Cookie persists; logout via `/cgi-bin/logout.cgi`

The admin panel uses the following API endpoints (all session-protected):

| Method | Path | Description |
|--------|------|-------------|
| POST | `/cgi-bin/save.cgi` | Save draft post |
| POST | `/cgi-bin/publish.cgi` | Toggle published state |
| POST | `/cgi-bin/delete.cgi` | Delete post |
| GET | `/cgi-bin/posts.cgi` | List all posts (including drafts) |
| GET | `/cgi-bin/links.cgi` | Load links data (categories and cards) |
| POST | `/cgi-bin/links.cgi` | Save links data to storage |
| POST | `/cgi-bin/upload.cgi` | Upload images |
| GET | `/cgi-bin/images.cgi` | List uploaded images |
| POST | `/cgi-bin/delete-image.cgi` | Delete image |

## Navigation

The navigation menu (`assets/layout.js`) is injected into every page and includes:

- **Header** (on all pages except home) — Logo + back-to-home link
- **Navigation panel** (side drawer on mobile)
  - Projects (collapsible group)
  - Home, Blog, Contact links
  - Theme colour picker
  - Admin Login button (not shown on admin page itself)
- **Mobile hamburger toggle** — Opens/closes the nav drawer on small screens

The nav uses `data-page` and `data-basepath` attributes on `<body>` for routing:

```html
<body data-page="dbfirstgrid" data-basepath="../">
```

- `data-page` — Used to mark the active link in the nav
- `data-basepath` — Used to construct correct URLs (useful for nested pages like `projects/`)

## API Endpoints

### Public

| Method | Path | Description |
|--------|------|-------------|
| GET | `/config.cgi` | Returns `{postsUrl, storage}` |

### Admin Authentication

| Method | Path | Description |
|--------|------|-------------|
| GET/POST | `/cgi-bin/login.cgi` | Login form and credential validation |
| GET | `/cgi-bin/logout.cgi` | Clear session cookie and redirect |

### Admin (protected by session cookie)

| Method | Path | Description |
|--------|------|-------------|
| POST | `/cgi-bin/save.cgi` | Save/update post |
| POST | `/cgi-bin/publish.cgi` | Toggle published state |
| POST | `/cgi-bin/delete.cgi` | Delete post |
| GET | `/cgi-bin/posts.cgi` | List all posts (including drafts) |

## Browser Support

- Modern browsers (Chrome, Firefox, Safari, Edge)
- Mobile-friendly (viewport meta tag, responsive CSS)
- Requires ES6 JavaScript support
- No polyfills or build-time transpilation

## Scripts

- **`dev.sh`** — Start containerised dev server with hot-reload (`localhost:8888`)
- **`docker-entrypoint.sh`** — Container startup logic; handles S3 sync and cache initialization
- **`sync-posts.sh`** — Bidirectional sync between S3 and local cache (production only)
- **`scripts/deploy-lambda.sh`** — Build, push to ECR, and update the Lambda function
- **`scripts/generate-credentials.sh`** — Generate and apply `ADMIN_TOKEN` to Lambda
- **`scripts/aws-setup.sh`** — Helper to configure AWS IAM, S3, and CloudFront for blog deployment

## Development

### Adding a New Project

1. Create a new HTML page in `projects/` (e.g., `projects/mynewproject.html`)
2. Add the project's `<body data-page="mynewproject" data-basepath="../">` attribute
3. Update `assets/layout.js` to include the new project in the Projects menu group (lines 82–111)

### Adding Navigation Items

Edit the navigation structure in `assets/layout.js`:

- **Top-level links** (lines 121–129) — Home, Blog, Contact
- **Project menu** (lines 79–112) — Collapsible group with project pages
- **Theme picker** (lines 133–147) — Colour themes

### Styling

All CSS is in `assets/style.css`. The site uses:
- CSS custom properties (variables) for theming
- CSS Grid for layout
- Flexbox for component alignment
- Media queries for responsive design

To add a new theme, define a `[data-theme="themename"]` selector in `style.css` and add a swatch in `layout.js`.

## Deployment Notes

### AWS Lambda Setup

**Prerequisites:**

1. AWS Account with Lambda and ECR access
2. IAM role or user with permissions to:
   - Create/update Lambda functions
   - Push to ECR
   - Get/put objects in S3 (via access point or bucket)

**Required environment variables on the Lambda function:**

- `STORAGE=s3`
- `AWS_REGION` — e.g. `us-east-1`
- `AWS_ACCESS_KEY_ID` — IAM credentials
- `AWS_SECRET_ACCESS_KEY` — IAM credentials
- `AWS_BUCKET` or `AWS_ACCESS_POINT_ARN` — S3 target
- `ADMIN_TOKEN` — SHA-256 hash of admin password

**Deploying:**

```bash
# 1. Generate and apply the admin token
./scripts/generate-credentials.sh --apply --function personalSite

# 2. Configure S3 IAM and bucket policies
./scripts/aws-setup.sh --account-id 123456789012 \
                        --bucket my-bucket \
                        --principal arn:aws:iam::123456789012:role/personalsite-lambda \
                        --create-role --bucket-policy

# 3. Build and deploy the container to Lambda
./scripts/deploy-lambda.sh --account-id 123456789012 --region us-east-1
```

### S3 Access Point (Recommended)

For production, use S3 Access Points to enforce private bucket access:

```bash
./scripts/aws-setup.sh --account-id 123456789012 \
                        --bucket my-bucket \
                        --principal arn:aws:iam::123456789012:role/personalsite-lambda \
                        --access-point my-ap \
                        --bucket-policy
```

This:
1. Creates/updates IAM policies scoped to `blog/posts/*`
2. Applies access point resource policy
3. Denies all direct bucket access (forces access point route)

### CloudFront Video Delivery (Optional)

To serve video files (`videos/*`) via CloudFront with Origin Access Control:

```bash
./scripts/aws-setup.sh --account-id 123456789012 \
                        --bucket my-bucket \
                        --principal arn:aws:iam::123456789012:role/personalsite-lambda \
                        --access-point my-ap \
                        --bucket-policy \
                        --cf-dist-id EXXXXXXXXXX \
                        --cf-video-policy \
                        --cf-s3-origin
```

Options:
- `--cf-video-policy` — Grant CloudFront OAC read access to `videos/*`
- `--cf-s3-origin` — Add S3 origin and `videos/*` cache behavior to the distribution
- `--oac-id` — Override OAC lookup (optional)

### Image Security

- The container image (`Dockerfile`) does **not** contain AWS credentials
- Credentials are injected at runtime via Lambda environment variables
- Never commit `.credentials` or sensitive data to version control

### Cache Invalidation

Blog posts are served from a local cache (`/blog/posts/`) to avoid repeated S3 calls. The cache is synced on container startup and periodically during operation.

To force a manual resync inside the container:

```bash
/usr/local/bin/sync-posts.sh
```

## Troubleshooting

### Dev server not starting

```bash
# Check if the ports are already in use
lsof -i :8888
lsof -i :9001

# Force-stop any existing containers
podman rm -f personalsite personalsite-minio

# Check logs
podman logs personalsite
podman logs personalsite-minio
```

### Blog posts not appearing in dev (MinIO)

1. Verify MinIO is running: `podman ps | grep personalsite-minio`
2. Check MinIO console at `http://localhost:9001` (minioadmin / minioadmin)
3. Verify the bucket `blog-posts` exists
4. Check site container logs: `podman logs personalsite`
5. Test MinIO connectivity from site container: `podman exec personalsite wget -O- http://personalsite-minio:9000/minio/health/live`

### Blog posts not appearing in production (AWS S3)

1. Verify S3 credentials: `aws s3 ls s3://my-bucket/`
2. Check container logs: `podman logs <container-id>`
3. Manually sync: `podman exec <container-id> /usr/local/bin/sync-posts.sh`

### Theme not persisting

1. Check browser console for localStorage errors
2. Verify `tebay_theme` key in browser DevTools → Application → Local Storage
3. Try clearing cache and reloading

### Admin panel not saving posts or links

1. Verify session is authenticated: check browser DevTools for `admin_session` cookie
2. Verify CGI scripts are executable: `ls -la cgi-bin/`
3. Check browser console for POST errors
4. In S3 mode, verify AWS credentials and bucket permissions
5. If saving links returns "s3 upload failed": check AWS credentials, bucket permissions, and IAM role. Note that changes revert on container restart if S3 upload fails

### Admin login not working

1. Verify `ADMIN_TOKEN` environment variable is set correctly
2. In dev, check `dev.sh` sets `ADMIN_TOKEN` (default: SHA-256 of "Password123")
3. For Lambda, verify `ADMIN_TOKEN` is set via `generate-credentials.sh --apply`
4. Check CGI logs: `podman logs <container-id>`

## License

Personal project; see repository for details.
