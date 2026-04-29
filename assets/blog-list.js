(function () {
  const listEl = document.getElementById("blog-list");
  if (!listEl) return;

  function escapeHtml(text) {
    return String(text || "")
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;");
  }

  function formatDate(isoDate) {
    const parts = String(isoDate || "").split("-");
    if (parts.length !== 3) return isoDate || "";
    return parts[1] + "-" + parts[2] + "-" + parts[0];
  }

  function renderPosts(posts) {
    listEl.innerHTML = "";
    if (!posts.length) {
      listEl.innerHTML = '<p class="blog-empty">No posts yet.</p>';
      return;
    }

    const sorted = [...posts].sort((a, b) => String(b.date || "").localeCompare(String(a.date || "")));
    sorted.forEach(function (post) {
      if (post.wip) {
        const item = document.createElement("div");
        item.className = "blog-card blog-card--wip";
        item.innerHTML =
          '<span class="blog-card__date">' + escapeHtml(formatDate(post.date)) + "</span>" +
          '<span class="blog-card__title">WIP: ' + escapeHtml(post.title) + "</span>" +
          '<span class="blog-card__desc">Coming soon...</span>';
        listEl.appendChild(item);
      } else {
        const anchor = document.createElement("a");
        anchor.className = "blog-card";
        anchor.href = "blog-post.html?slug=" + encodeURIComponent(post.slug || "");
        anchor.innerHTML =
          '<span class="blog-card__date">' + escapeHtml(formatDate(post.date)) + "</span>" +
          '<span class="blog-card__title">' + escapeHtml(post.title) + "</span>" +
          '<span class="blog-card__desc">' + escapeHtml(post.desc) + "</span>";
        listEl.appendChild(anchor);
      }
    });
  }

  (async function init() {
    try {
      const response = await fetch("blog/posts/manifest.json?v=" + Date.now());
      renderPosts(response.ok ? await response.json() : []);
    } catch (_) {
      listEl.innerHTML = '<p class="blog-empty">Could not load posts.</p>';
    }
  })();
})();
