(function () {
  const currentPage = document.body.dataset.page || '';

  // ── Header (not shown on home page) ──────────────────────────────────
  if (currentPage !== 'home') {
    const header = document.createElement('header');
    header.id = 'site-header';
    const headerInner = document.createElement('div');
    headerInner.id = 'header-inner';
    const logoLink = document.createElement('a');
    logoLink.href = 'tebay-dev.html';
    logoLink.id = 'header-logo-wrap';
    const headerLogo = document.createElement('img');
    headerLogo.id = 'header-logo';
    headerLogo.src = 'tebay-dev.svg';
    headerLogo.alt = 'Tebay.dev — Home';
    logoLink.appendChild(headerLogo);
    headerInner.appendChild(logoLink);
    header.appendChild(headerInner);
    document.body.insertBefore(header, document.body.firstChild);
  }

  // ── Nav ──────────────────────────────────────────────────────────────
  const navPanel = document.createElement('nav');
  navPanel.id = 'nav-panel';
  navPanel.className = 'side-panel';

  /**
   * Creates an anchor element for the navigation tree.
   * @param {string} label - Link text.
   * @param {string} href - Link destination.
   * @param {string} pageId - The page identifier used to mark the active link.
   * @returns {HTMLAnchorElement}
   */
  function makeLink(label, href, pageId) {
    const linkElement = document.createElement('a');
    linkElement.href = href;
    linkElement.textContent = label;
    if (pageId && pageId === currentPage) linkElement.classList.add('active');
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
    const detailsElement = document.createElement('details');
    if (open) detailsElement.open = true;
    const summaryElement = document.createElement('summary');
    summaryElement.textContent = label;
    detailsElement.appendChild(summaryElement);
    const listElement = document.createElement('ul');
    items.forEach(({ label: itemLabel, href, id }) => {
      const listItem = document.createElement('li');
      listItem.appendChild(makeLink(itemLabel, href, id));
      listElement.appendChild(listItem);
    });
    detailsElement.appendChild(listElement);
    return detailsElement;
  }

  const sectionLabel = document.createElement('span');
  sectionLabel.className = 'section-label';
  sectionLabel.textContent = 'Navigation';
  navPanel.appendChild(sectionLabel);

  const navTree = document.createElement('ul');
  navTree.className = 'tree';

  // Projects group
  const projectListItem = document.createElement('li');
  projectListItem.appendChild(createMenuGroup('Projects', [
    { label: 'DBFirstDataGrid',       href: 'dbfirstgrid.html',          id: 'dbfirstgrid' },
    { label: 'AutoRejection',         href: 'autorejection.html',        id: 'autorejection' },
    { label: 'MicrophoneController',  href: 'microphonecontroller.html', id: 'microphonecontroller' },
  ], true));
  navTree.appendChild(projectListItem);

  // Divider
  const dividerElement = document.createElement('div');
  dividerElement.className = 'divider';
  navTree.appendChild(dividerElement);

  // Top-level links
  [
    { label: 'Home',    href: 'tebay-dev.html', id: 'home' },
    { label: 'Contact', href: '#',              id: '' },
  ].forEach(({ label, href, id }) => {
    const listItem = document.createElement('li');
    listItem.appendChild(makeLink(label, href, id));
    navTree.appendChild(listItem);
  });

  navPanel.appendChild(navTree);

  const navPlaceholder = document.getElementById('layout-nav');
  if (navPlaceholder) navPlaceholder.replaceWith(navPanel);
})();
