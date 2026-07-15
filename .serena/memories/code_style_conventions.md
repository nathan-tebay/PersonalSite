# Code Style & Conventions — PersonalSite

## General
- Vanilla HTML/CSS/JS plus CGI shell scripts.
- No app framework and no browser build pipeline.
- Keep source readable; do not add minify/bundle steps unless user explicitly asks.
- Runtime has no npm app dependency, but dev checks may use `npx` tools when available.
- Indentation: 2 spaces throughout.

## JavaScript
- Linter: StandardJS for `assets/*.js`.
- Formatter: Prettier for targeted changed files.
- camelCase for functions and variables.
- Descriptive variable names; avoid unclear abbreviations.
- JSDoc only where it adds useful interface/behavior clarity.
- Avoid inline conditionals with more than one condition.
- Prefer guard clauses over nesting / else-if chains.

## HTML/CSS
- Maintain 2-space indentation matching existing files.
- Navigation injected by `assets/layout.js`; do NOT duplicate nav markup in HTML files.
- Pages declare routing with body attributes, e.g.:
  `<body data-page="pagename" data-basepath="../">`

## Theming
- Six dark swatches; JS derives border, panel fill, and text vars from chosen hex.
- Theme persisted to localStorage key `tebay_theme`.

## CGI Scripts
- Bash CGI scripts source `session.sh` for auth enforcement where needed.
- Source `storage.sh` for backend abstraction.
- Use Podman, never Docker CLI, for container work.