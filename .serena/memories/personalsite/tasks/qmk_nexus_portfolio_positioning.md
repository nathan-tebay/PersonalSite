# QMK Nexus portfolio positioning update

Homepage and QMK Nexus page were updated to position Nathan as building systems that make complex workflows understandable, usable, and safer.

Touched files:
- `index.html`: SEO title/meta, tighter About copy, QMK Nexus first-path links, primary project feature panel, guided project-path section grouped by theme, job-search/value CTA copy.
- `projects/qmknexus.html`: SEO title/meta, rewritten hero/tagline, problem/solution/signal grid, technical notes grid, workflow-covered section, renamed flow headings, related work cards, final CTA panel.
- `assets/project-data.js`: stronger QMK Nexus nav description.
- `assets/style.css`: home feature/project-path/related-card styling, QMK outcome/note grid/CTA styling, responsive grid behavior.

Verification:
- Custom touched-file href/src check passed.
- `python3 scripts/validate-site.py` still fails on pre-existing missing blog image assets under `blog-posts/*`, unrelated to this change.

Repo had unrelated dirty files before/alongside this task: `admin/index.html`, `assets/layout.js`, `blog-posts/why-i-finally-quit-three-years-inside-a-stuck-org/draft.html`, `cgi-bin/infiniteImprobablity.cgi`, untracked `.serena/`, `cgi-bin/purge-visits.cgi`.