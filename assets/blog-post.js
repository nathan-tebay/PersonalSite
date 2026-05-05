(function () {
  const panel = document.getElementById("post-panel");
  if (!panel) return;

  function escapeHtml(text) {
    return String(text || "")
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;");
  }

  function getSlug() {
    return new URLSearchParams(window.location.search).get("slug");
  }

  function setMeta(selector, attribute, value) {
    if (!value) return;
    var element = document.head.querySelector(selector);
    if (!element) {
      element = document.createElement("meta");
      if (selector.indexOf("property=") !== -1) {
        element.setAttribute("property", selector.match(/property="([^"]+)"/)[1]);
      } else {
        element.setAttribute("name", selector.match(/name="([^"]+)"/)[1]);
      }
      document.head.appendChild(element);
    }
    element.setAttribute(attribute, value);
  }

  function setLink(selector, attribute, value) {
    if (!value) return;
    var element = document.head.querySelector(selector);
    if (!element) {
      element = document.createElement("link");
      element.setAttribute("rel", selector.match(/rel="([^"]+)"/)[1]);
      document.head.appendChild(element);
    }
    element.setAttribute(attribute, value);
  }

  function updatePostSeo(meta, slug) {
    var title = String(meta.title || "Blog") + " - Tebay.dev";
    var description = String(meta.desc || "A blog post by Nathan Tebay.");
    var url = "https://tebay.dev/blog-post.html?slug=" + encodeURIComponent(slug || "");
    var image = meta.image
      ? new URL(meta.image, window.location.origin + "/").href
      : "https://tebay.dev/background.jpeg";

    document.title = title;
    setMeta('meta[name="description"]', "content", description);
    setLink('link[rel="canonical"]', "href", url);
    setMeta('meta[property="og:title"]', "content", title);
    setMeta('meta[property="og:description"]', "content", description);
    setMeta('meta[property="og:url"]', "content", url);
    setMeta('meta[property="og:image"]', "content", image);
    setMeta('meta[property="article:author"]', "content", "Nathan Tebay");
    setMeta('meta[name="twitter:title"]', "content", title);
    setMeta('meta[name="twitter:description"]', "content", description);
    setMeta('meta[name="twitter:image"]', "content", image);
    if (meta.date) setMeta('meta[property="article:published_time"]', "content", meta.date);
  }

  function formatDate(isoDate) {
    const parts = String(isoDate || "").split("-");
    if (parts.length !== 3) return isoDate || "";
    return parts[1] + "-" + parts[2] + "-" + parts[0];
  }

  function sanitizeHtml(html) {
    var template = document.createElement("template");
    template.innerHTML = html;

    var allowedTags = new Set([
      "A", "ABBR", "B", "BLOCKQUOTE", "BR", "CODE", "DEL", "EM", "H1", "H2", "H3",
      "H4", "H5", "H6", "HR", "I", "IMG", "LI", "OL", "P", "PRE", "S", "STRONG",
      "SUB", "SUP", "TABLE", "TBODY", "TD", "TH", "THEAD", "TR", "U", "UL"
    ]);
    var allowedAttrs = {
      A: new Set(["href", "title"]),
      IMG: new Set(["src", "alt", "title", "width", "height", "loading"]),
      ABBR: new Set(["title"]),
      TH: new Set(["colspan", "rowspan"]),
      TD: new Set(["colspan", "rowspan"])
    };
    var urlAttrs = new Set(["href", "src"]);
    var allowedProtocols = new Set(["http:", "https:", "mailto:", ""]);

    function isSafeUrl(value) {
      try {
        var parsed = new URL(value, window.location.href);
        return allowedProtocols.has(parsed.protocol);
      } catch (error) {
        return false;
      }
    }

    function scrub(node) {
      Array.from(node.children).forEach(function (child) {
        if (!allowedTags.has(child.tagName)) {
          child.replaceWith(document.createTextNode(child.textContent || ""));
          return;
        }

        Array.from(child.attributes).forEach(function (attr) {
          var name = attr.name.toLowerCase();
          var allowedForTag = allowedAttrs[child.tagName] || new Set();
          if (!allowedForTag.has(name) || name.startsWith("on")) {
            child.removeAttribute(attr.name);
            return;
          }
          if (urlAttrs.has(name) && !isSafeUrl(attr.value.trim())) {
            child.removeAttribute(attr.name);
          }
        });

        if (child.tagName === "A") {
          child.setAttribute("rel", "noopener noreferrer");
        }
        if (child.tagName === "IMG" && !child.getAttribute("loading")) {
          child.setAttribute("loading", "lazy");
        }

        scrub(child);
      });
    }

    scrub(template.content);
    return template.innerHTML;
  }

  function renderPost(meta, bodyHtml, slug) {
    updatePostSeo(meta, slug);
    var safeBody = sanitizeHtml(bodyHtml);
    panel.innerHTML =
      '<div class="project-header">' +
        "<div>" +
          "<h1>" + escapeHtml(meta.title) + "</h1>" +
          '<p class="tagline">' + escapeHtml(formatDate(meta.date)) + "</p>" +
        "</div>" +
        '<a href="blog.html" class="github-link">Back to Blog</a>' +
      "</div>" +
      '<div class="blog-post-content">' + safeBody + "</div>";
  }

  (async function init() {
    const slug = getSlug();
    if (!slug) {
      panel.innerHTML = '<p class="blog-empty">No post specified.</p>';
      return;
    }

    try {
      const response = await fetch("blog/posts/" + encodeURIComponent(slug) + "/index.html");
      if (!response.ok) throw new Error("Post not found.");
      const text = await response.text();
      const newlineIndex = text.indexOf("\n");
      const metaMatch = text.substring(0, newlineIndex).match(/^<!-- (.*) -->$/);
      if (!metaMatch) throw new Error("Invalid post format.");
      const meta = JSON.parse(metaMatch[1]);
      const bodyHtml = text.substring(newlineIndex + 1);
      renderPost(meta, bodyHtml, slug);
    } catch (error) {
      panel.innerHTML = '<p class="blog-empty">' + escapeHtml(error.message) + "</p>";
    }
  })();
})();
