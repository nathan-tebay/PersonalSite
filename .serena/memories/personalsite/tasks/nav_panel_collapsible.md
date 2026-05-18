# Navigation panel collapsible update

Implemented desktop user-collapsible navigation panel in `assets/layout.js` and `assets/style.css`.

Behavior:
- Adds `#nav-collapse-toggle` inside `#nav-panel`.
- Persists state in `window.localStorage` key `tebay_nav_collapsed`.
- Toggles `body.nav-collapsed`.
- Desktop (`min-width: 601px`) collapses nav to a narrow rail and hides nav tree, theme picker, dividers, and admin link.
- Mobile keeps existing hamburger drawer behavior; desktop collapse control is hidden under `max-width: 600px` so persisted desktop collapse does not empty the mobile drawer.

Also fixed JS StandardJS issues across `assets/*.js` using `standard --fix`, plus manual fixes for `window.localStorage` globals and unused helpers.

Verification:
- `XDG_CACHE_HOME=/tmp npx standard assets/*.js` passed.
- `for f in assets/*.js; do node --check "$f" || exit 1; done` passed.
- `git diff --check` passed.
- `python3 scripts/validate-site.py` still fails only on pre-existing missing blog image assets under `blog-posts/*`.