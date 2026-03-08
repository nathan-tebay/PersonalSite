/**
 * BlogStorage — localStorage-backed post store for local dev mode.
 * Loaded on all blog-related pages. When storage mode is "s3" the CGI
 * endpoints are used instead and these methods are not called.
 *
 * localStorage key: "tebay_blog_posts"
 * Schema: Array<{ slug, title, date, desc, content, published }>
 */
(function () {
  const LS_KEY = "tebay_blog_posts";

  /** @returns {Array<{slug:string,title:string,date:string,desc:string,content:string,published:boolean}>} */
  function loadAll() {
    try { return JSON.parse(localStorage.getItem(LS_KEY)) || []; } catch (_) { return []; }
  }

  /** @param {Array} posts */
  function persist(posts) {
    localStorage.setItem(LS_KEY, JSON.stringify(posts));
  }

  window.BlogStorage = {
    /** Return all posts including drafts (admin use). */
    getAllPosts() {
      return loadAll();
    },

    /** Return published posts only (public use). */
    getPublishedPosts() {
      return loadAll().filter(function (p) { return p.published; });
    },

    /**
     * Return a single post by slug regardless of published state.
     * @param {string} slug
     * @returns {{slug,title,date,desc,content,published}|null}
     */
    getPost(slug) {
      return loadAll().find(function (p) { return p.slug === slug; }) || null;
    },

    /**
     * Create or update a post. Published and wip states are preserved if the
     * post already exists unless explicitly provided.
     * @param {{slug,title,date,desc,content,published?,wip?}} post
     * @returns {{slug,title,date,desc,content,published,wip}}
     */
    savePost(post) {
      const posts = loadAll();
      const index = posts.findIndex(function (p) { return p.slug === post.slug; });
      const existing = index >= 0 ? posts[index] : null;
      const entry = {
        slug:      post.slug,
        title:     post.title,
        date:      post.date,
        desc:      post.desc,
        content:   post.content,
        published: post.published !== undefined ? post.published : (existing ? existing.published : false),
        wip:       post.wip      !== undefined ? post.wip      : (existing ? existing.wip      : false),
      };
      if (index >= 0) posts[index] = entry;
      else posts.push(entry);
      persist(posts);
      return entry;
    },

    /**
     * Toggle the published state of a post. Publishing clears the wip flag.
     * @param {string} slug
     * @returns {{slug,title,date,desc,content,published,wip}|null}
     */
    togglePublished(slug) {
      const posts = loadAll();
      const post = posts.find(function (p) { return p.slug === slug; });
      if (!post) return null;
      post.published = !post.published;
      if (post.published) post.wip = false;
      persist(posts);
      return post;
    },

    /**
     * Return published posts plus any unpublished WIP placeholders (public use).
     * @returns {Array}
     */
    getPublishedAndWipPosts() {
      return loadAll().filter(function (p) { return p.published || p.wip; });
    },

    /**
     * Delete a post by slug.
     * @param {string} slug
     */
    deletePost(slug) {
      persist(loadAll().filter(function (p) { return p.slug !== slug; }));
    },
  };
})();
