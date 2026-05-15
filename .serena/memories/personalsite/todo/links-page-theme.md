---
type: project
---

Match the links page link cards/styling to the site's colour theme (the dynamic theme picker that derives border, panel fill, and text colours from the selected swatch hex). Currently the links page links may not respond to theme changes the way other panels do.

**Why:** User flagged this as a pending visual consistency task.
**How to apply:** When working on links.html or assets/style.css, check that link card colours use the same CSS variables (--text-high, --text-mid, --text-link, --divider, --hover-bg, panel fill/border derived vars) as the rest of the site so they update when the theme swatch is changed.
