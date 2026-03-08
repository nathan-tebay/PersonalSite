# Tebay.dev — Personal Portfolio Site

A hand-rolled static portfolio website with vanilla HTML, CSS, and JavaScript—no frameworks, no build step. Features a dynamic navigation system, multi-theme colour picker, a blog with localStorage-backed storage and admin panel, and containerised deployment options.

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
│   ├── index.html             # Admin login & blog editor
│   └── api/
│       ├── save.cgi           # Save draft post
│       ├── delete.cgi         # Delete post
│       ├── publish.cgi        # Publish/unpublish post
│       ├── posts.cgi          # List all posts
│       └── storage.sh         # Storage backend helper
│
├── blog/
│   └── posts/                 # Post files (created at runtime)
│
├── dev.sh                     # Start dev containers (site + MinIO S3)
├── Dockerfile                 # Prod image (S3 storage)
├── docker-entrypoint.sh       # Container startup logic
├── sync-posts.sh              # S3 ↔ local cache sync (prod only)
└── config.cgi                 # Public API: returns storage mode & posts URL
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
   - **MinIO** — S3-compatible storage on `http://localhost:9001` (console: `minioadmin` / `minioadmin`)
   - **Site** — Served on `http://localhost:8888` with volume mount for live editing

Both containers run in the background (detached) and are non-blocking.

**Blog storage in dev mode:**

- Blog posts are stored in MinIO (S3-compatible) via `STORAGE=s3`
- Admin panel at `http://localhost:8888/admin/` (no authentication in dev)
- MinIO console accessible at `http://localhost:9001` with credentials `minioadmin` / `minioadmin` for debugging
- Posts persist in MinIO and survive container restarts
- The `personalsite-dev` network connects both containers; the site uses `http://personalsite-minio:9000` to reach MinIO

**Stopping the dev environment:**

```bash
podman rm -f personalsite personalsite-minio
```

This removes both containers. The network persists but will be cleaned up by Podman automatically.

### Production Deployment

Build the production image with S3 backend:

```bash
podman build -f Dockerfile -t tebay-site:latest .
```

Required environment variables:

```bash
podman run \
  -p 8080:8080 \
  -e AWS_REGION=us-east-1 \
  -e AWS_ACCESS_KEY_ID=<key> \
  -e AWS_SECRET_ACCESS_KEY=<secret> \
  -e AWS_BUCKET=my-bucket \
  tebay-site:latest
```

Or use an S3 Access Point ARN (recommended) instead of `AWS_BUCKET`:

```bash
-e AWS_ACCESS_POINT_ARN=arn:aws:s3:us-east-1:123456789012:accesspoint/my-ap
```

The container:
- Serves the site on port `8080`
- Syncs posts between S3 and a local cache (`/var/www/html/blog/posts/`) on startup and periodically
- Serves all blog posts from the local cache (never directly from S3)
- Requires `STORAGE=s3` environment variable (set by default in `Dockerfile`)

## Configuration

### Storage Mode

The site can operate in two storage modes, set via the `STORAGE` environment variable:

| Mode | Location                             | Use Case                   | Persistence                  |
|------|--------------------------------------|----------------------------|-------------------------------|
| `s3` | MinIO (local dev) or AWS S3 (prod) | Development and production | Persistent across restarts   |

The `config.cgi` endpoint returns the active storage mode and post URL:

```bash
curl http://localhost:8888/config.cgi
# {"postsUrl":"/blog/posts","storage":"local"}
```

### Theme Customization

Colours are defined in `assets/style.css` as CSS custom properties:

```css
:root {
  --bg-primary: #1a1a1a;
  --bg-secondary: #2d2d2d;
  --text-high: #ffffff;
  --text-mid: #b3b3b3;
  --text-low: #808080;
  --divider: #404040;
  --accent: #6366f1;
  /* ... more colours ... */
}

[data-theme="light"] {
  --bg-primary: #ffffff;
  --bg-secondary: #f5f5f5;
  --text-high: #1a1a1a;
  --text-mid: #4d4d4d;
  --text-low: #808080;
  --divider: #e0e0e0;
  --accent: #4f46e5;
  /* ... more colours ... */
}
```

The theme picker in the navigation (injected by `layout.js`) cycles through available themes and saves the selection to localStorage under the key `tebay_theme`.

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

**Local storage key:** `tebay_blog_posts` (JSON array)

## Admin Panel

Access at `/admin/index.html` (no authentication required in dev; implement as needed for production).

**Features:**
- Create and edit blog posts
- Preview posts before publishing
- Toggle publish/draft status
- Delete posts
- WIP placeholder posts (shown on public listing with "Coming soon" label)

The admin panel uses the following API endpoints:

| Method | Path | Description |
|--------|------|-------------|
| POST | `/admin/api/save.cgi` | Save draft post |
| POST | `/admin/api/publish.cgi` | Toggle published state |
| POST | `/admin/api/delete.cgi` | Delete post |
| GET | `/admin/api/posts.cgi` | List all posts (including drafts) |

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

### Admin (write operations)

| Method | Path | Description |
|--------|------|-------------|
| POST | `/admin/api/save.cgi` | Save/update post |
| POST | `/admin/api/publish.cgi` | Toggle published state |
| POST | `/admin/api/delete.cgi` | Delete post |
| GET | `/admin/api/posts.cgi` | List all posts |

## Browser Support

- Modern browsers (Chrome, Firefox, Safari, Edge)
- Mobile-friendly (viewport meta tag, responsive CSS)
- Requires ES6 JavaScript support
- No polyfills or build-time transpilation

## Scripts

- **`dev.sh`** — Start containerised dev server with hot-reload (`localhost:8888`)
- **`docker-entrypoint.sh`** — Container startup logic; handles S3 sync and cache initialization
- **`sync-posts.sh`** — Bidirectional sync between S3 and local cache (production only)
- **`scripts/aws-setup.sh`** — Helper to configure AWS credentials for S3 access
- **`scripts/generate-credentials.sh`** — Generate `.credentials` file for httpd config

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

### AWS S3 Setup

For production S3 deployment, you'll need:
1. An S3 bucket (or Access Point) with appropriate permissions
2. AWS credentials with `s3:GetObject`, `s3:PutObject`, `s3:DeleteObject` permissions
3. `CORS` policy configured if serving from a different domain

Use the helper scripts:

```bash
./scripts/aws-setup.sh      # Configure AWS region and bucket
./scripts/generate-credentials.sh  # Create .credentials file
```

### Docker Image Security

- The prod image (`Dockerfile`) requires AWS credentials at runtime
- Credentials are **not** baked into the image
- Use Docker secrets or environment variable injection (e.g., via `.env` file or secrets manager)

### Cache Invalidation

Blog posts are served from a local cache (`/blog/posts/`) to avoid repeated S3 calls. The cache is synced on container startup. If you need to force a resync:

```bash
/usr/local/bin/sync-posts.sh  # Inside the container
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

### Admin panel not saving posts

1. Verify CGI scripts are executable: `ls -la admin/api/`
2. Check browser console for POST errors
3. In local mode, verify localStorage is enabled
4. In S3 mode, verify AWS credentials and bucket permissions

## License

Personal project; see repository for details.
