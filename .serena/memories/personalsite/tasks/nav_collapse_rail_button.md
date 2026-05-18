# Nav collapse rail button tweak

Adjusted desktop nav collapse UX after user feedback:
- `assets/layout.js`: collapse button is inserted to the left of the visible `Navigation` heading. Button now contains `.nav-collapse-glyph` and `.nav-collapse-text` spans.
- `assets/style.css`: expanded mode shows only the glyph button left of `Navigation`. Collapsed desktop mode makes the nav panel a very narrow rail (`2.35rem`) with the collapse button absolutely covering the full rail, so the entire rail is clickable. The glyph sits at the top and `Navigation` appears vertically below it inside the full-height button.

Verification:
- `XDG_CACHE_HOME=/tmp npx standard assets/*.js` passed.
- `for f in assets/*.js; do node --check "$f" || exit 1; done` passed.
- `git diff --check` passed.