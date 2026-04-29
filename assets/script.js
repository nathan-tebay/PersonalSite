// ── LinkedIn quote expand/collapse ────────────────────────────────────
(function () {
  const quote = document.getElementById("li-quote");
  const readMore = document.getElementById("li-read-more");
  if (!quote || !readMore) return;

  readMore.addEventListener("click", () => {
    const collapsed = quote.classList.toggle("collapsed");
    readMore.textContent = collapsed ? "Read more" : "Read less";
  });
})();

// ── Theme definitions ─────────────────────────────────────────────────
// All chosen to complement the green PCB circuit-board logo.
const THEMES = [
  { name: "Forest", hex: "#0d1f14" }, // deep PCB green
  { name: "Abyss", hex: "#0a1520" }, // deep ocean blue
  { name: "Void", hex: "#18102e" }, // dark violet
  { name: "Obsidian", hex: "#111111" }, // near-black neutral
  { name: "Gunmetal", hex: "#14181e" }, // dark blue-gray
  { name: "Ember", hex: "#7a2800" }, // burnt orange
  { name: "Rust", hex: "#a84518" }, // lighter burnt orange
  { name: "Cobalt", hex: "#0d1a3a" }, // deep blue — safe for red-green colour blindness
  { name: "Graphite", hex: "#1c1c1c" }, // neutral gray — hue-free, works for all CVD types
  { name: "Fog", hex: "#b8c4cc" }, // light blue-gray
  { name: "Parchment", hex: "#c8b89a" }, // warm tan/cream
  { name: "Sage", hex: "#8aad92" }, // muted sage green
];

// ── Colour helpers ────────────────────────────────────────────────────
function hexToRgb(hex) {
  return [
    parseInt(hex.slice(1, 3), 16),
    parseInt(hex.slice(3, 5), 16),
    parseInt(hex.slice(5, 7), 16),
  ];
}

function darken([r, g, b], f) {
  return [Math.round(r * f), Math.round(g * f), Math.round(b * f)];
}

function lighten([r, g, b], a) {
  return [
    Math.round(r + (255 - r) * a),
    Math.round(g + (255 - g) * a),
    Math.round(b + (255 - b) * a),
  ];
}

function toCss([r, g, b]) {
  return `rgb(${r},${g},${b})`;
}

// WCAG relative luminance
function luminance([r, g, b]) {
  const lin = (v) => {
    v /= 255;
    return v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4);
  };
  return 0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(b);
}

// ── Apply a theme ─────────────────────────────────────────────────────
const body = document.body;
const root = document.documentElement;

function applyTheme(hex) {
  const base = hexToRgb(hex);
  const isLight = luminance(base) > 0.15; // background is light → panels go darker

  // Light themes: darken panels; dark themes: lighten panels
  const fill = isLight ? darken(base, 0.78) : lighten(base, 0.18);

  if (isLight) {
    root.style.setProperty("--text-high", "rgba(0,0,0,0.87)");
    root.style.setProperty("--text-mid", "rgba(0,0,0,0.60)");
    root.style.setProperty("--text-low", "rgba(0,0,0,0.40)");
    root.style.setProperty("--text-link", "#166534");
    root.style.setProperty("--divider", "rgba(0,0,0,0.10)");
    root.style.setProperty("--hover-bg", "rgba(0,0,0,0.06)");
  } else {
    root.style.setProperty("--text-high", "rgba(255,255,255,0.90)");
    root.style.setProperty("--text-mid", "rgba(255,255,255,0.65)");
    root.style.setProperty("--text-low", "rgba(255,255,255,0.38)");
    root.style.setProperty("--text-link", "#4ade80");
    root.style.setProperty("--divider", "rgba(255,255,255,0.08)");
    root.style.setProperty("--hover-bg", "rgba(255,255,255,0.07)");
  }

  // Drive panel colours via CSS custom properties so every panel on every page
  // picks up the theme, including those injected by layout.js after this runs.
  root.style.setProperty("--info-bg", toCss(fill));
  root.style.setProperty("--panel-border", toCss(darken(base, 0.5)));
  root.style.setProperty("--bg", hex);
  body.style.backgroundColor = hex;
}

// ── Tooltip (body-level, escapes backdrop-filter stacking context) ────
const tip = document.createElement("div");
tip.id = "swatch-tip";
document.body.appendChild(tip);

function showTip(el, label) {
  const r = el.getBoundingClientRect();
  tip.textContent = label;
  tip.style.opacity = "0";
  tip.style.display = "block";
  const tw = tip.offsetWidth;
  tip.style.left = `${r.left + r.width / 2 - tw / 2}px`;
  tip.style.top = `${r.top - tip.offsetHeight - 7}px`;
  tip.style.opacity = "1";
}

function hideTip() {
  tip.style.opacity = "0";
}

// ── Theme persistence (localStorage + window.name fallback for file://) ──
function isValidHex(s) {
  return /^#[0-9a-fA-F]{6}$/.test(s);
}

function getSavedTheme() {
  const theme = localStorage.getItem("tebay_theme") || localStorage.getItem("theme");
  if (theme && isValidHex(theme)) return theme;
  return THEMES[0].hex;
}

function saveTheme(hex) {
  localStorage.setItem("tebay_theme", hex);
  localStorage.removeItem("theme");
  window.name = hex; // persists across same-tab file:// navigations
}

const savedHex = getSavedTheme();

// ── Render swatches (only on pages that have the picker) ──────────────
const swatchContainer = document.getElementById("swatches");
if (swatchContainer) {
  let activeBtn = null;

  THEMES.forEach((theme) => {
    const btn = document.createElement("button");
    btn.className = "swatch";
    btn.style.backgroundColor = theme.hex;
    btn.setAttribute("aria-label", theme.name);
    btn.addEventListener("mouseenter", () => showTip(btn, theme.name));
    btn.addEventListener("mouseleave", hideTip);
    btn.addEventListener("click", () => {
      if (activeBtn) activeBtn.classList.remove("active");
      btn.classList.add("active");
      activeBtn = btn;
      hideTip();
      applyTheme(theme.hex);
      saveTheme(theme.hex);
    });
    swatchContainer.appendChild(btn);
    if (theme.hex === savedHex) {
      btn.classList.add("active");
      activeBtn = btn;
    }
  });

  // Fall back to first swatch if saved value no longer matches any theme
  if (!activeBtn) {
    activeBtn = swatchContainer.firstChild;
    activeBtn.classList.add("active");
  }
}

applyTheme(savedHex);

// ── Project media fallbacks ────────────────────────────────────────────
(function () {
  document.querySelectorAll(".render-card img").forEach(function (img) {
    img.loading = img.loading || "lazy";
    img.decoding = img.decoding || "async";
    img.tabIndex = 0;
    img.setAttribute("role", "button");
    img.setAttribute("aria-label", "Open image preview");
    img.addEventListener("error", function () {
      const card = img.closest(".render-card");
      if (!card) return;
      img.remove();
      if (!card.querySelector(".render-card--image-error")) {
        const fallback = document.createElement("div");
        fallback.className = "render-card--image-error";
        fallback.textContent = "Image unavailable";
        card.insertBefore(fallback, card.firstChild);
      }
    });
  });
})();

// ── Shared image modal ────────────────────────────────────────────────
(function () {
  var modal = document.createElement("div");
  modal.className = "image-modal";
  modal.hidden = true;
  modal.setAttribute("role", "dialog");
  modal.setAttribute("aria-modal", "true");
  modal.setAttribute("aria-label", "Image preview");
  modal.innerHTML =
    '<div class="image-modal__backdrop"></div>' +
    '<div class="image-modal__box">' +
      '<button class="image-modal__close" aria-label="Close">&#x2715;</button>' +
      '<button class="image-modal__nav image-modal__nav--prev" aria-label="Previous image">&#x2039;</button>' +
      '<img class="image-modal__image" alt="" />' +
      '<button class="image-modal__nav image-modal__nav--next" aria-label="Next image">&#x203a;</button>' +
      '<p class="image-modal__caption"></p>' +
    "</div>";
  document.body.appendChild(modal);

  var preview = modal.querySelector(".image-modal__image");
  var caption = modal.querySelector(".image-modal__caption");
  var closeButton = modal.querySelector(".image-modal__close");
  var prevButton = modal.querySelector(".image-modal__nav--prev");
  var nextButton = modal.querySelector(".image-modal__nav--next");
  var images = [];
  var currentIndex = 0;
  var lastFocused = null;

  function getImageLabel(img) {
    var card = img.closest(".render-card");
    var label = card ? card.querySelector(".render-label") : null;
    return (label && label.textContent.trim()) || img.alt || "Image preview";
  }

  function setActiveImage(index) {
    if (!images.length) return;
    currentIndex = (index + images.length) % images.length;
    var img = images[currentIndex];
    var label = getImageLabel(img);
    preview.src = img.currentSrc || img.src;
    preview.alt = img.alt || label;
    caption.textContent =
      images.length > 1 ? label + " (" + (currentIndex + 1) + " of " + images.length + ")" : label;
    prevButton.hidden = images.length < 2;
    nextButton.hidden = images.length < 2;
  }

  function openModal(img) {
    images = Array.prototype.slice.call(document.querySelectorAll(".render-card img"));
    var index = images.indexOf(img);
    lastFocused = img || document.activeElement;
    setActiveImage(index >= 0 ? index : 0);
    modal.hidden = false;
    closeButton.focus();
  }

  function closeModal() {
    modal.hidden = true;
    preview.src = "";
    preview.alt = "";
    if (lastFocused && typeof lastFocused.focus === "function") lastFocused.focus();
    images = [];
    currentIndex = 0;
    lastFocused = null;
  }

  function showPrevious() {
    setActiveImage(currentIndex - 1);
  }

  function showNext() {
    setActiveImage(currentIndex + 1);
  }

  modal.querySelector(".image-modal__backdrop").addEventListener("click", closeModal);
  closeButton.addEventListener("click", closeModal);
  prevButton.addEventListener("click", showPrevious);
  nextButton.addEventListener("click", showNext);

  document.addEventListener("keydown", function (e) {
    if (modal.hidden) return;
    if (e.key === "Escape") closeModal();
    if (e.key === "ArrowLeft") {
      e.preventDefault();
      showPrevious();
    }
    if (e.key === "ArrowRight") {
      e.preventDefault();
      showNext();
    }
    if (e.key === "Tab") {
      e.preventDefault();
      closeButton.focus();
    }
  });

  document.addEventListener("click", function (e) {
    var img = e.target.closest(".render-card img");
    if (!img) return;
    openModal(img);
  });

  document.addEventListener("keydown", function (e) {
    if (e.key !== "Enter" && e.key !== " ") return;
    var img = e.target.closest && e.target.closest(".render-card img");
    if (!img) return;
    e.preventDefault();
    openModal(img);
  });
})();

// ── Shared video modal ────────────────────────────────────────────────
(function () {
  var modal = document.createElement("div");
  modal.className = "video-modal";
  modal.hidden = true;
  modal.setAttribute("role", "dialog");
  modal.setAttribute("aria-modal", "true");
  modal.setAttribute("aria-label", "Video player");
  modal.innerHTML =
    '<div class="video-modal__backdrop"></div>' +
    '<div class="video-modal__box">' +
      '<button class="video-modal__close" aria-label="Close">&#x2715;</button>' +
      '<video class="video-modal__video" playsinline controls></video>' +
      '<div class="video-modal__error">Video unavailable</div>' +
      '<p class="video-modal__caption"></p>' +
    "</div>";
  document.body.appendChild(modal);

  var video = modal.querySelector(".video-modal__video");
  var caption = modal.querySelector(".video-modal__caption");
  var closeButton = modal.querySelector(".video-modal__close");
  var lastFocused = null;

  function openModal(src, label, opener) {
    lastFocused = opener || document.activeElement;
    modal.classList.remove("video-modal--error");
    video.src = src;
    caption.textContent = label || "";
    modal.hidden = false;
    closeButton.focus();
    video.play().catch(function () {
      video.controls = true;
    });
  }

  function closeModal() {
    modal.hidden = true;
    video.pause();
    video.src = "";
    modal.classList.remove("video-modal--error");
    if (lastFocused && typeof lastFocused.focus === "function") lastFocused.focus();
    lastFocused = null;
  }

  video.addEventListener("error", function () {
    modal.classList.add("video-modal--error");
  });

  modal.querySelector(".video-modal__backdrop").addEventListener("click", closeModal);
  closeButton.addEventListener("click", closeModal);

  document.addEventListener("keydown", function (e) {
    if (modal.hidden) return;
    if (e.key === "Escape") closeModal();
    if (e.key === "Tab") {
      e.preventDefault();
      closeButton.focus();
    }
  });

  document.addEventListener("click", function (e) {
    var trigger = e.target.closest("[data-video-src]");
    if (!trigger) return;
    openModal(trigger.dataset.videoSrc, trigger.dataset.videoCaption || "", trigger);
  });
})();
