# Tebay.dev Technical Improvement Plan

Review date: 2026-04-24

This file tracks the technical improvement work split out from `plan.md`. These items are intended to be implemented before the separate content pass.

## Priority Tracker

### P2 - UX, Accessibility, and Polish

- [x] Add a real page-level `h1` to the home page.
  - Current home page uses `h2` for `Nathan Tebay`; this is weaker for accessibility and document outline.
- [x] Improve mobile layout spacing.
  - At narrow widths, nav becomes a drawer, but `.page-layout` keeps desktop padding and the main content remains panel-heavy.
  - Review at 375px, 430px, 768px, and desktop widths.
- [x] Add `loading="lazy"` and explicit image dimensions or aspect-ratio wrappers to project images.
  - This should reduce layout shift and improve first load.
- [x] Add focus-visible styles for nav links, buttons, swatches, and modal controls.
- [x] Improve video modal accessibility.
  - Add `role="dialog"`, `aria-modal="true"`, focus management, and restore focus to the opener after close.
- [x] Remove production console logging from `assets/script.js`.
  - `getSavedTheme()` currently logs theme reads.
- [x] Align theme persistence docs and code.
  - Code now writes `tebay_theme` and migrates away from the old `theme` key.
- [x] Add a visible fallback for failed project images/videos.
- [x] Consider a smaller, more readable content width for long prose pages.

### P3 - Maintainability and Security Hardening

- [x] Centralize repeated project page data.
  - Shared project navigation metadata now lives in `assets/project-data.js`.
  - Full project body templating is deferred to the content/template pass because it would change how project copy is authored.
- [x] Move inline page scripts/styles into assets where practical.
  - `blog.html` and `links.html` contain substantial inline rendering logic.
  - `links.html` also has page-specific inline CSS.
- [x] Escape dynamic blog post metadata in `blog-post.html`.
  - `meta.title` is inserted into `innerHTML` without escaping.
- [x] Validate/sanitize link URLs in `links.html`.
  - Escaping HTML is not enough for `href`; reject `javascript:` and other unsafe protocols.
- [x] Add a simple static validation script.
  - Check local asset references, duplicate IDs, missing `alt`, broken internal links, and root-relative paths.
- [x] Add deployment smoke checks.
  - Verify blog manifest, links data, project pages, videos, and admin login route after deploy.
- [x] Update README project list to include `Fly Fishing Game`.

## Technical Validation Checklist

- [x] Run local static server and request every nav page.
- [ ] Check desktop, tablet, and mobile layouts.
- [x] Confirm all project images load.
- [x] Confirm both demo videos open and play.
- [ ] Check keyboard navigation through nav, theme swatches, project actions, and modal.
- [x] Run a link/reference check before deployment.
