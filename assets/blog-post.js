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

  function renderPost(meta, bodyHtml) {
    document.title = String(meta.title || "Blog") + " - Tebay.dev";
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
      renderPost(meta, bodyHtml);
    } catch (error) {
      panel.innerHTML = '<p class="blog-empty">' + escapeHtml(error.message) + "</p>";
    }
  })();
})();
