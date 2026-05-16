(function () {
  const contentEl = document.getElementById('links-content')
  if (!contentEl) return

  function safeUrl (rawUrl) {
    const value = String(rawUrl || '').trim()
    if (!value) return ''

    try {
      const parsed = new URL(value, window.location.href)
      if (['http:', 'https:', 'mailto:'].includes(parsed.protocol)) return parsed.href
    } catch (_) {
      return ''
    }

    return ''
  }

  function appendLink (parent, link) {
    const href = safeUrl(link.url)
    if (!href) return

    const item = document.createElement('div')
    item.className = 'link-item'

    const linkWrap = document.createElement('div')
    const anchor = document.createElement('a')
    anchor.href = href
    anchor.target = '_blank'
    anchor.rel = 'noopener'
    anchor.textContent = link.title || link.url
    linkWrap.appendChild(anchor)
    item.appendChild(linkWrap)

    if (link.desc) {
      const desc = document.createElement('div')
      desc.className = 'link-item-desc'
      desc.textContent = link.desc
      item.appendChild(desc)
    }

    parent.appendChild(item)
  }

  function appendSection (title, links, showTitle) {
    const section = document.createElement('div')
    section.className = 'links-section'
    if (showTitle) {
      const heading = document.createElement('div')
      heading.className = 'links-section-title'
      heading.textContent = title
      section.appendChild(heading)
    }

    const list = document.createElement('div')
    list.className = 'links-list'
    links.forEach(function (link) {
      appendLink(list, link)
    })

    if (!list.children.length) return
    section.appendChild(list)
    contentEl.appendChild(section)
  }

  function render (data) {
    contentEl.innerHTML = ''
    const categories = data.categories || []
    const links = data.links || []

    if (!links.length) {
      contentEl.innerHTML = '<p class="blog-empty">No links yet.</p>'
      return
    }

    const catMap = {}
    categories.forEach(function (category) {
      catMap[category.id] = category.name
    })

    const groups = {}
    const uncategorized = []
    links.forEach(function (link) {
      if (link.categoryId && catMap[link.categoryId]) {
        const name = catMap[link.categoryId]
        if (!groups[name]) groups[name] = []
        groups[name].push(link)
      } else {
        uncategorized.push(link)
      }
    })

    categories.forEach(function (category) {
      const catLinks = groups[category.name]
      if (catLinks && catLinks.length) appendSection(category.name, catLinks, true)
    })

    if (uncategorized.length) appendSection('Other', uncategorized, categories.length > 0)
    if (!contentEl.children.length) {
      contentEl.innerHTML = '<p class="blog-empty">No valid links yet.</p>'
    }
  }

  (async function init () {
    try {
      const response = await fetch('links.json?v=' + Date.now())
      render(response.ok ? await response.json() : { categories: [], links: [] })
    } catch (_) {
      contentEl.innerHTML = '<p class="blog-empty">Could not load links.</p>'
    }
  })()
})()
