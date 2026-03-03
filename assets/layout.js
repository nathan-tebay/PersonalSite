(function () {
  const page = document.body.dataset.page || '';

  // ── Header (not shown on home page) ──────────────────────────────────
  if (page !== 'home') {
    const header = document.createElement('header');
    header.id = 'site-header';
    const inner = document.createElement('div');
    inner.id = 'header-inner';
    const logoLink = document.createElement('a');
    logoLink.href = 'tebay-dev.html';
    logoLink.id = 'header-logo-wrap';
    const headerLogo = document.createElement('img');
    headerLogo.id = 'header-logo';
    headerLogo.src = 'tebay-dev.svg';
    headerLogo.alt = 'Tebay.dev — Home';
    logoLink.appendChild(headerLogo);
    inner.appendChild(logoLink);
    header.appendChild(inner);
    document.body.insertBefore(header, document.body.firstChild);
  }

  // ── Nav ──────────────────────────────────────────────────────────────
  const nav = document.createElement('nav');
  nav.id = 'nav-panel';
  nav.className = 'side-panel';

  function makeLink(label, href, id) {
    const a = document.createElement('a');
    a.href = href;
    a.textContent = label;
    if (id && id === page) a.classList.add('active');
    return a;
  }

  function makeGroup(label, items, open) {
    const det = document.createElement('details');
    if (open) det.open = true;
    const sum = document.createElement('summary');
    sum.textContent = label;
    det.appendChild(sum);
    const ul = document.createElement('ul');
    items.forEach(({ label: l, href, id }) => {
      const li = document.createElement('li');
      li.appendChild(makeLink(l, href, id));
      ul.appendChild(li);
    });
    det.appendChild(ul);
    return det;
  }

  const sectionLabel = document.createElement('span');
  sectionLabel.className = 'section-label';
  sectionLabel.textContent = 'Navigation';
  nav.appendChild(sectionLabel);

  const tree = document.createElement('ul');
  tree.className = 'tree';

  // Projects group
  const projLi = document.createElement('li');
  projLi.appendChild(makeGroup('Projects', [
    { label: 'DBFirstDataGrid',       href: 'dbfirstgrid.html',          id: 'dbfirstgrid' },
    { label: 'AutoRejection',         href: 'autorejection.html',        id: 'autorejection' },
    { label: 'MicrophoneController',  href: 'microphonecontroller.html', id: 'microphonecontroller' },
  ], true));
  tree.appendChild(projLi);

  // Divider
  const divider = document.createElement('div');
  divider.className = 'divider';
  tree.appendChild(divider);

  // Top-level links
  [
    { label: 'Home',    href: 'tebay-dev.html', id: 'home' },
    { label: 'Contact', href: '#',              id: '' },
  ].forEach(({ label, href, id }) => {
    const li = document.createElement('li');
    li.appendChild(makeLink(label, href, id));
    tree.appendChild(li);
  });

  nav.appendChild(tree);

  const placeholder = document.getElementById('layout-nav');
  if (placeholder) placeholder.replaceWith(nav);
})();
