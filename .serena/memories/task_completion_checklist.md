# Task Completion Checklist — PersonalSite

After completing any coding task:

1. **Lint JS** — `npx standard assets/*.js` (fix any errors)
2. **Format** — `npx prettier --write .` if HTML/CSS changed
3. **Validate** — `python3 scripts/validate-site.py` for HTML structure
4. **Smoke check** — `scripts/smoke-check.sh` if containers are running
5. **Dev test** — `./dev.sh` and manually verify in browser at http://localhost:8888
6. **Only commit when explicitly asked** by the user

## Adding a New Project Page
1. Create `projects/mynewproject.html` with `<body data-page="mynewproject" data-basepath="../">`
2. Add project entry to Projects menu group in `assets/layout.js`
3. Add project data to `assets/project-data.js`
