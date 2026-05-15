# Architecture Notes — PersonalSite

## File Layout (key files)
```
index.html, blog.html, blog-post.html, links.html   # Pages
admin/index.html                                      # Admin panel
assets/style.css                                      # Global styles + theme definitions
assets/script.js                                      # General page interactions
assets/layout.js                                      # Nav injection + theme picker
assets/blog-list.js, blog-post.js, blog-storage.js   # Blog frontend
assets/links-page.js                                  # Links frontend
assets/project-data.js                                # Project metadata
cgi-bin/*.cgi                                         # Session-protected APIs
config.cgi                                            # Public API (storage mode + posts URL)
dev.sh                                                # Dev environment launcher
Dockerfile / Dockerfile.dev                           # Container images
scripts/                                              # Deploy + utility scripts
```

## Page Layout (index.html flex structure)
```
.page-layout
├── #nav-panel          (sticky left, 220px)
└── .main-col
    ├── .top-row
    │   ├── #panel      (logo + circuit-board background)
    │   └── #info-panel (bio/info)
    └── #content-panel  (long-form content)
```

## Auth
- Cookie-based: `admin_session` = SHA-256 of password
- `ADMIN_TOKEN` env var holds the hash
- All CGI scripts (except login/logout) source `session.sh`

## Blog Storage Fallback
- `assets/blog-storage.js` provides localStorage fallback for local dev without MinIO
