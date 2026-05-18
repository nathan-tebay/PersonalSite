# Project page case-study refresh

Updated all non-QMK project pages to follow the QMK Nexus case-study format: SEO title/meta, hero summary, "What it solves", audience, overview, workflow, grouped stack, why-it-matters, technical notes grid, hard parts, engineering takeaways, current scope, related work, and CTA.

Touched files:
- `projects/aiagents.html`
- `projects/autorejection.html`
- `projects/dbfirstgrid.html`
- `projects/flyfishinggame.html`
- `projects/microphonecontroller.html`
- `projects/personalsite.html`
- `projects/whispertranscribe.html`
- `assets/project-data.js`

Verification:
- `npx prettier --write` ran on touched HTML and project-data initially; `assets/project-data.js` then manually adjusted to StandardJS style.
- `XDG_CACHE_HOME=/tmp npx standard assets/project-data.js` passed.
- `git diff --check` passed.
- Custom touched project local href/src check passed.
- `python3 scripts/validate-site.py` still fails only on pre-existing missing blog image assets under `blog-posts/*`, unrelated to project page changes.
- `XDG_CACHE_HOME=/tmp npx standard assets/*.js` still fails on pre-existing style issues across other asset JS files.