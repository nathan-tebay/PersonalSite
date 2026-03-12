(function () {
  const currentPage = document.body.dataset.page || "";
  const basePath    = document.body.dataset.basepath || "";

  // ── Header (not shown on home page) ──────────────────────────────────
  if (currentPage !== "home") {
    const header = document.createElement("header");
    header.id = "site-header";
    const headerInner = document.createElement("div");
    headerInner.id = "header-inner";
    const logoLink = document.createElement("a");
    logoLink.href = basePath + "index.html";
    logoLink.id = "header-logo-wrap";
    const headerLogo = document.createElement("img");
    headerLogo.id = "header-logo";
    headerLogo.src = basePath + "tebay-dev.svg";
    headerLogo.alt = "Tebay.dev — Home";
    logoLink.appendChild(headerLogo);
    headerInner.appendChild(logoLink);
    header.appendChild(headerInner);
    const headerBottomBlend = document.createElement("div");
    headerBottomBlend.id = "header-bottom-blend";
    header.appendChild(headerBottomBlend);
    document.body.insertBefore(header, document.body.firstChild);
  }

  // ── Nav ──────────────────────────────────────────────────────────────
  const navPanel = document.createElement("nav");
  navPanel.id = "nav-panel";
  navPanel.className = "side-panel";

  /**
   * Creates an anchor element for the navigation tree.
   * @param {string} label - Link text.
   * @param {string} href - Link destination.
   * @param {string} pageId - The page identifier used to mark the active link.
   * @returns {HTMLAnchorElement}
   */
  function makeLink(label, href, pageId) {
    const linkElement = document.createElement("a");
    linkElement.href = href;
    linkElement.textContent = label;
    if (pageId && pageId === currentPage) linkElement.classList.add("active");
    return linkElement;
  }

  /**
   * Creates a collapsible <details> group containing navigation links.
   * @param {string} label - Group heading text.
   * @param {{ label: string, href: string, id: string }[]} items - Nav items.
   * @param {boolean} [open=false] - Whether the group starts expanded.
   * @returns {HTMLDetailsElement}
   */
  function createMenuGroup(label, items, open) {
    const detailsElement = document.createElement("details");
    if (open) detailsElement.open = true;
    const summaryElement = document.createElement("summary");
    summaryElement.textContent = label;
    detailsElement.appendChild(summaryElement);
    const listElement = document.createElement("ul");
    items.forEach(({ label: itemLabel, href, id }) => {
      const listItem = document.createElement("li");
      listItem.appendChild(makeLink(itemLabel, href, id));
      listElement.appendChild(listItem);
    });
    detailsElement.appendChild(listElement);
    return detailsElement;
  }

  const sectionLabel = document.createElement("span");
  sectionLabel.className = "section-label";
  sectionLabel.textContent = "Navigation";
  navPanel.appendChild(sectionLabel);

  const navTree = document.createElement("ul");
  navTree.className = "tree";

  // Projects group
  const projectListItem = document.createElement("li");
  projectListItem.appendChild(
    createMenuGroup(
      "Projects",
      [
        {
          label: "DBFirstDataGrid",
          href: basePath + "projects/dbfirstgrid.html",
          id: "dbfirstgrid",
        },
        {
          label: "AutoRejection",
          href: basePath + "projects/autorejection.html",
          id: "autorejection",
        },
        {
          label: "MicrophoneController",
          href: basePath + "projects/microphonecontroller.html",
          id: "microphonecontroller",
        },
        {
          label: "WhisperTranscribe",
          href: basePath + "projects/whispertranscribe.html",
          id: "whispertranscribe",
        },
        {
          label: "PersonalSite",
          href: basePath + "projects/personalsite.html",
          id: "personalsite",
        },
      ],
      true,
    ),
  );
  navTree.appendChild(projectListItem);

  // Divider
  const dividerElement = document.createElement("div");
  dividerElement.className = "divider";
  navTree.appendChild(dividerElement);

  // Top-level links
  [
    { label: "Home",    href: basePath + "index.html",  id: "home" },
    { label: "Blog",    href: basePath + "blog.html",   id: "blog" },
    { label: "Links",   href: basePath + "links.html",  id: "links" },
    { label: "Contact", href: "mailto:nathan@tebay.dev", id: "" },
  ].forEach(({ label, href, id }) => {
    const listItem = document.createElement("li");
    listItem.appendChild(makeLink(label, href, id));
    navTree.appendChild(listItem);
  });

  navPanel.appendChild(navTree);

  // ── Theme picker ──────────────────────────────────────────────────────
  const pickerDivider = document.createElement("div");
  pickerDivider.className = "divider";
  navPanel.appendChild(pickerDivider);

  const pickerWrap = document.createElement("div");
  pickerWrap.id = "picker-wrap";
  const pickerLabel = document.createElement("span");
  pickerLabel.className = "section-label";
  pickerLabel.textContent = "Theme";
  pickerWrap.appendChild(pickerLabel);
  const swatchesDiv = document.createElement("div");
  swatchesDiv.id = "swatches";
  pickerWrap.appendChild(swatchesDiv);
  navPanel.appendChild(pickerWrap);

  // ── Admin login button ────────────────────────────────────────────────
  const loginDivider = document.createElement("div");
  loginDivider.className = "divider";
  navPanel.appendChild(loginDivider);

  if (currentPage !== "admin") {
    const loginLink = document.createElement("a");
    loginLink.href = basePath + "admin/index.html";
    loginLink.id = "nav-login-btn";
    loginLink.textContent = "Admin Login";
    navPanel.appendChild(loginLink);
  }

  const navPlaceholder = document.getElementById("layout-nav");
  if (navPlaceholder) navPlaceholder.replaceWith(navPanel);

  // ── Hamburger toggle (mobile) ─────────────────────────────────────────
  const navOverlay = document.createElement("div");
  navOverlay.id = "nav-overlay";
  document.body.appendChild(navOverlay);

  const navToggle = document.createElement("button");
  navToggle.id = "nav-toggle";
  navToggle.setAttribute("aria-label", "Toggle navigation");
  navToggle.setAttribute("aria-expanded", "false");
  for (let i = 0; i < 3; i++) navToggle.appendChild(document.createElement("span"));
  document.body.appendChild(navToggle);

  /**
   * Opens the mobile nav drawer.
   */
  function openNav() {
    navPanel.classList.add("nav-open");
    navOverlay.classList.add("nav-open");
    navToggle.classList.add("open");
    navToggle.setAttribute("aria-expanded", "true");
  }

  /**
   * Closes the mobile nav drawer.
   */
  function closeNav() {
    navPanel.classList.remove("nav-open");
    navOverlay.classList.remove("nav-open");
    navToggle.classList.remove("open");
    navToggle.setAttribute("aria-expanded", "false");
  }

  navToggle.addEventListener("click", function () {
    navPanel.classList.contains("nav-open") ? closeNav() : openNav();
  });

  navOverlay.addEventListener("click", closeNav);
})();
