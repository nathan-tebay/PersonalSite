# Analytics bot filter and blog slug tracking

Implemented analytics changes:
- `assets/layout.js`: beacon now sends `slug` from `?slug=` when `window.location.pathname` ends with `/blog-post.html`.
- `cgi-bin/infiniteImprobablity.cgi`: added `is_likely_bot_user_agent` and skips recording likely crawlers, preview bots, monitors, headless/script clients, and empty UAs. New analytics JSONL records include `slug` field.
- `cgi-bin/analytics.cgi`: filters likely bot records out of returned visits, including historical rows already in JSONL.
- `admin/index.html`: analytics dashboard now shows `Top Blog Posts` using `v.slug` counts.

Verification:
- `XDG_CACHE_HOME=/tmp npx standard assets/*.js` passed.
- `for f in assets/*.js; do node --check "$f" || exit 1; done` passed.
- `sh -n cgi-bin/infiniteImprobablity.cgi cgi-bin/analytics.cgi cgi-bin/purge-visits.cgi` passed.
- `git diff --check` passed.
- Manual awk smoke test showed Googlebot and empty UA rows dropped while normal UA rows remained.
- `python3 scripts/validate-site.py` still fails only on pre-existing missing blog image assets under `blog-posts/*`.