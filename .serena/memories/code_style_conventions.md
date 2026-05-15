# Code Style & Conventions — PersonalSite

## General
- **Indentation**: 2 spaces throughout
- **No frameworks**, no npm, no build step — KISS & readability
- Minimize/compress/bundle JS and CSS for the browser

## JavaScript
- **Linter**: StandardJS
- **Formatter**: Prettier
- camelCase for functions and variables
- Descriptive variable names — no abbreviations
- JSDoc for function and interface documentation
- Avoid inline conditionals with >1 condition
- Prefer guard clauses over nesting / else-if chains

## HTML/CSS
- Maintain 2-space indentation matching existing files
- Navigation injected by `assets/layout.js` — do NOT duplicate nav markup in HTML files
- Pages declare routing via body attributes:
  ```html
  <body data-page="pagename" data-basepath="../">
  ```

## Theming
- Six dark swatches; JS derives border, panel fill, and text vars from chosen hex
- Theme persisted to localStorage key `tebay_theme`

## CGI Scripts (bash)
- Source `session.sh` for auth enforcement
- Source `storage.sh` for backend abstraction
- Always use `podman`, never `docker`
