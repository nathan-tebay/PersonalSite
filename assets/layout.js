(function () {
  const currentPage = document.body.dataset.page || ''
  const basePath = document.body.dataset.basepath || ''
  const projects = window.TEBAY_PROJECTS || []

  // ── Skip-to-content link (a11y: first focusable element) ──────────────
  const skipLink = document.createElement('a')
  skipLink.href = '#main-content'
  skipLink.className = 'skip-nav'
  skipLink.textContent = 'Skip to main content'
  document.body.insertBefore(skipLink, document.body.firstChild)

  // Ensure main content area has an id for the skip link target
  const mainCol = document.querySelector('.main-col')
  if (mainCol && !mainCol.id) mainCol.id = 'main-content'

  // ── Header (not shown on home page) ──────────────────────────────────
  if (currentPage !== 'home') {
    const header = document.createElement('header')
    header.id = 'site-header'
    header.setAttribute('role', 'banner')
    const headerInner = document.createElement('div')
    headerInner.id = 'header-inner'
    const logoLink = document.createElement('a')
    logoLink.href = basePath + 'index.html'
    logoLink.id = 'header-logo-wrap'
    logoLink.setAttribute('aria-label', 'Tebay.dev — Home')
    const headerLogo = document.createElement('img')
    headerLogo.id = 'header-logo'
    headerLogo.src = basePath + 'tebay-dev.svg'
    headerLogo.alt = 'Tebay.dev — Home'
    logoLink.appendChild(headerLogo)
    headerInner.appendChild(logoLink)
    header.appendChild(headerInner)
    const headerBottomBlend = document.createElement('div')
    headerBottomBlend.id = 'header-bottom-blend'
    header.appendChild(headerBottomBlend)
    document.body.insertBefore(header, document.body.firstChild)
  }

  // ── Nav ──────────────────────────────────────────────────────────────
  const navPanel = document.createElement('nav')
  navPanel.id = 'nav-panel'
  navPanel.className = 'side-panel'
  navPanel.setAttribute('aria-label', 'Main navigation')

  const navCollapseButton = document.createElement('button')
  navCollapseButton.id = 'nav-collapse-toggle'
  navCollapseButton.type = 'button'
  navCollapseButton.setAttribute('aria-controls', 'nav-panel')

  /**
   * Sets the persistent desktop navigation collapse state.
   * @param {boolean} collapsed - Whether the desktop navigation is collapsed.
   */
  function setNavCollapsed (collapsed) {
    document.body.classList.toggle('nav-collapsed', collapsed)
    navCollapseButton.setAttribute(
      'aria-expanded',
      collapsed ? 'false' : 'true'
    )
    navCollapseButton.setAttribute(
      'aria-label',
      collapsed ? 'Expand navigation panel' : 'Collapse navigation panel'
    )
    navCollapseButton.title = collapsed
      ? 'Expand navigation'
      : 'Collapse navigation'
    navCollapseButton.textContent = collapsed ? '☰' : '‹'
    try {
      window.localStorage.setItem('tebay_nav_collapsed', collapsed ? '1' : '0')
    } catch (_) {}
  }

  let savedNavCollapsed = false
  try {
    savedNavCollapsed =
      window.localStorage.getItem('tebay_nav_collapsed') === '1'
  } catch (_) {}
  setNavCollapsed(savedNavCollapsed)
  navCollapseButton.addEventListener('click', function () {
    setNavCollapsed(!document.body.classList.contains('nav-collapsed'))
  })
  navPanel.appendChild(navCollapseButton)

  /**
   * Creates an anchor element for the navigation tree.
   * @param {string} label - Link text.
   * @param {string} href - Link destination.
   * @param {string} pageId - The page identifier used to mark the active link.
   * @returns {HTMLAnchorElement}
   */
  function makeLink (label, href, pageId) {
    const linkElement = document.createElement('a')
    linkElement.href = href
    linkElement.textContent = label
    if (pageId && pageId === currentPage) linkElement.classList.add('active')
    return linkElement
  }

  /**
   * Creates a collapsible <details> group containing navigation links.
   * @param {string} label - Group heading text.
   * @param {{ label: string, href: string, id: string, description?: string }[]} items - Nav items.
   * @param {boolean} [open=false] - Whether the group starts expanded.
   * @returns {HTMLDetailsElement}
   */
  function createMenuGroup (label, items, open) {
    const detailsElement = document.createElement('details')
    if (open) detailsElement.open = true
    const summaryElement = document.createElement('summary')
    summaryElement.textContent = label
    detailsElement.appendChild(summaryElement)
    const listElement = document.createElement('ul')
    items.forEach(({ label: itemLabel, href, id, description }) => {
      const listItem = document.createElement('li')
      listItem.appendChild(makeLink(itemLabel, href, id))
      if (description) {
        const descriptionElement = document.createElement('p')
        descriptionElement.className = 'nav-description'
        descriptionElement.textContent = description
        listItem.appendChild(descriptionElement)
      }
      listElement.appendChild(listItem)
    })
    detailsElement.appendChild(listElement)
    return detailsElement
  }

  const sectionLabel = document.createElement('span')
  sectionLabel.className = 'section-label'
  sectionLabel.textContent = 'Navigation'
  navPanel.appendChild(sectionLabel)

  const navTree = document.createElement('ul')
  navTree.className = 'tree'

  // Restore saved nav group state, fall back to sensible defaults
  let savedNavOpen = ''
  try {
    savedNavOpen = window.localStorage.getItem('tebay_nav_open') || ''
  } catch (_) {}
  const defaultOpen = currentPage === 'blog' ? 'blog' : 'projects'
  const openGroup = savedNavOpen || defaultOpen

  // Projects group
  const projectListItem = document.createElement('li')
  const projectsDetails = createMenuGroup(
    'Projects',
    projects.map(function (project) {
      return {
        label: project.label,
        href: basePath + project.path,
        id: project.id,
        description: project.description
      }
    }),
    openGroup === 'projects'
  )
  projectsDetails.dataset.navId = 'projects'
  projectListItem.appendChild(projectsDetails)
  navTree.appendChild(projectListItem)

  // Blog group (expandable, async-populated with recent posts)
  const blogGroupDetails = document.createElement('details')
  blogGroupDetails.className = 'blog-nav-group'
  blogGroupDetails.dataset.navId = 'blog'
  if (openGroup === 'blog') blogGroupDetails.open = true
  const blogGroupSummary = document.createElement('summary')
  blogGroupSummary.textContent = 'Blog'
  blogGroupDetails.appendChild(blogGroupSummary)
  const blogGroupList = document.createElement('ul')
  const allPostsLi = document.createElement('li')
  allPostsLi.appendChild(makeLink('All Posts', basePath + 'blog.html', 'blog'))
  blogGroupList.appendChild(allPostsLi)
  blogGroupDetails.appendChild(blogGroupList)
  const blogListItem = document.createElement('li')
  blogListItem.appendChild(blogGroupDetails)
  navTree.appendChild(blogListItem)

  // Async: fetch manifest and append up to 5 recent posts under Blog group
  fetch(basePath + 'blog/posts/manifest.json')
    .then(function (r) {
      return r.ok ? r.json() : []
    })
    .then(function (posts) {
      posts
        .filter(function (p) {
          return !p.wip
        })
        .sort(function (a, b) {
          return a.date < b.date ? 1 : -1
        })
        .forEach(function (post) {
          const li = document.createElement('li')
          li.appendChild(
            makeLink(
              post.title,
              basePath + 'blog-post.html?slug=' + post.slug,
              ''
            )
          )
          if (post.desc) {
            const descEl = document.createElement('p')
            descEl.className = 'nav-description'
            descEl.textContent = post.desc
            li.appendChild(descEl)
          }
          blogGroupList.appendChild(li)
        })
    })
    .catch(function () {})

  // Divider
  const dividerElement = document.createElement('div')
  dividerElement.className = 'divider'
  navTree.appendChild(dividerElement)

  // Top-level links
  const topLevelLinks = [
    { label: 'Home', href: basePath + 'index.html', id: 'home' },
    { label: 'Links', href: basePath + 'links.html', id: 'links' },
    { label: 'Contact', href: 'mailto:nathan@tebay.dev', id: '' }
  ]
  topLevelLinks.forEach(({ label, href, id }) => {
    const listItem = document.createElement('li')
    listItem.appendChild(makeLink(label, href, id))
    navTree.appendChild(listItem)
  })

  navPanel.appendChild(navTree)

  // One section open at a time; persist open group to localStorage
  navTree.addEventListener(
    'toggle',
    function (e) {
      if (e.target.open) {
        navTree.querySelectorAll('details[open]').forEach(function (d) {
          if (d !== e.target) d.removeAttribute('open')
        })
      }
      try {
        const openEl = navTree.querySelector('details[open]')
        window.localStorage.setItem(
          'tebay_nav_open',
          openEl ? openEl.dataset.navId || '' : ''
        )
      } catch (_) {}
    },
    true
  )

  // ── Theme picker ──────────────────────────────────────────────────────
  const pickerDivider = document.createElement('div')
  pickerDivider.className = 'divider'
  navPanel.appendChild(pickerDivider)

  const pickerWrap = document.createElement('div')
  pickerWrap.id = 'picker-wrap'
  const pickerLabel = document.createElement('span')
  pickerLabel.className = 'section-label'
  pickerLabel.textContent = 'Theme'
  pickerWrap.appendChild(pickerLabel)
  const swatchesDiv = document.createElement('div')
  swatchesDiv.id = 'swatches'
  pickerWrap.appendChild(swatchesDiv)
  navPanel.appendChild(pickerWrap)

  // ── Admin login button ────────────────────────────────────────────────
  const loginDivider = document.createElement('div')
  loginDivider.className = 'divider'
  navPanel.appendChild(loginDivider)

  if (currentPage !== 'admin') {
    const loginLink = document.createElement('a')
    loginLink.href = basePath + 'admin/index.html'
    loginLink.id = 'nav-login-btn'
    loginLink.textContent = 'Admin Login'
    navPanel.appendChild(loginLink)
  }

  const navPlaceholder = document.getElementById('layout-nav')
  if (navPlaceholder) navPlaceholder.replaceWith(navPanel)

  // ── Analytics beacon ──────────────────────────────────────────────────────
  const _isAdmin = document.cookie.split(';').some(function (c) {
    return c.trim() === 'admin_ui=1'
  })
  if (currentPage !== 'admin' && !_isAdmin && navigator.sendBeacon) {
    try {
      const analyticsPayload = new URLSearchParams({
        page: window.location.pathname,
        ref: document.referrer || ''
      })
      if (window.location.pathname.endsWith('/blog-post.html')) {
        const slug = new URLSearchParams(window.location.search).get('slug')
        if (slug) analyticsPayload.set('slug', slug)
      }
      navigator.sendBeacon(
        '/cgi-bin/infiniteImprobablity.cgi',
        analyticsPayload
      )
    } catch (_) {}
  }

  // ── Hamburger toggle (mobile) ─────────────────────────────────────────
  const navOverlay = document.createElement('div')
  navOverlay.id = 'nav-overlay'
  document.body.appendChild(navOverlay)

  const navToggle = document.createElement('button')
  navToggle.id = 'nav-toggle'
  navToggle.setAttribute('aria-label', 'Toggle navigation')
  navToggle.setAttribute('aria-expanded', 'false')
  for (let i = 0; i < 3; i++) {
    navToggle.appendChild(document.createElement('span'))
  }
  document.body.appendChild(navToggle)

  /**
   * Opens the mobile nav drawer.
   */
  function openNav () {
    navPanel.classList.add('nav-open')
    navOverlay.classList.add('nav-open')
    navToggle.classList.add('open')
    navToggle.setAttribute('aria-expanded', 'true')
  }

  /**
   * Closes the mobile nav drawer.
   */
  function closeNav () {
    navPanel.classList.remove('nav-open')
    navOverlay.classList.remove('nav-open')
    navToggle.classList.remove('open')
    navToggle.setAttribute('aria-expanded', 'false')
  }

  navToggle.addEventListener('click', function () {
    navPanel.classList.contains('nav-open') ? closeNav() : openNav()
  })

  navOverlay.addEventListener('click', closeNav)
})()
