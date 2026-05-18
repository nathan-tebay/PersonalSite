# Nav collapse pullout label tweak

Adjusted desktop nav collapse UI:
- `assets/layout.js`: collapse button moved into new `#nav-heading` next to the `Navigation` label; collapsed button glyph is `›`, expanded remains `‹`.
- `assets/style.css`: `#nav-heading` lays out label + button horizontally when expanded. In collapsed desktop mode, the panel becomes a narrow pullout rail with rounded right side, vertical `Navigation` label, and highlighted expand button. Mobile drawer behavior remains unchanged.

Verification:
- `XDG_CACHE_HOME=/tmp npx standard assets/*.js` passed.
- `for f in assets/*.js; do node --check "$f" || exit 1; done` passed.
- `git diff --check` passed.