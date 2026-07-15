# Task Completion Checklist — PersonalSite

After coding changes, run focused checks relevant to touched files:

1. JS: `XDG_CACHE_HOME=/tmp npx standard <touched-js-files>`.
2. JS syntax: `node --check <touched-js-file>` when useful.
3. HTML/CSS formatting: run Prettier on touched files only, not the whole repo, unless user asks for broad formatting.
4. HTML structure: `python3 scripts/validate-site.py`; known pre-existing missing blog image assets may cause failure and should be reported, not hidden.
5. CGI/shell: `sh -n <touched-cgi-or-sh-files>` or `bash -n` for bash scripts.
6. Smoke check: `scripts/smoke-check.sh` if containers are running or the change affects runtime routing/storage.
7. Dev test: `./dev.sh` and manual browser review only when visual/runtime verification is needed.
8. Do not commit, push, or deploy unless user explicitly asks.

## Adding a New Project Page
1. Create `projects/mynewproject.html` with `<body data-page="mynewproject" data-basepath="../">`.
2. Add project entry to Projects menu group in `assets/layout.js`.
3. Add project data to `assets/project-data.js`.