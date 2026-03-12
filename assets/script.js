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
  console.log("Checking for saved theme...");
  const theme = localStorage.getItem("theme");
  console.log("localStorage theme:", theme);
  if (theme && isValidHex(theme)) return theme;
  return THEMES[0].hex;
}

function saveTheme(hex) {
  localStorage.setItem("theme", hex);
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

// ── Shared video modal ────────────────────────────────────────────────
(function () {
  var modal = document.createElement("div");
  modal.className = "video-modal";
  modal.hidden = true;
  modal.innerHTML =
    '<div class="video-modal__backdrop"></div>' +
    '<div class="video-modal__box">' +
      '<button class="video-modal__close" aria-label="Close">&#x2715;</button>' +
      '<video class="video-modal__video" playsinline controls></video>' +
      '<p class="video-modal__caption"></p>' +
    "</div>";
  document.body.appendChild(modal);

  var video = modal.querySelector(".video-modal__video");
  var caption = modal.querySelector(".video-modal__caption");

  function openModal(src, label) {
    video.src = src;
    caption.textContent = label || "";
    modal.hidden = false;
    video.play();
  }

  function closeModal() {
    modal.hidden = true;
    video.pause();
    video.src = "";
  }

  modal.querySelector(".video-modal__backdrop").addEventListener("click", closeModal);
  modal.querySelector(".video-modal__close").addEventListener("click", closeModal);

  document.addEventListener("keydown", function (e) {
    if (e.key === "Escape" && !modal.hidden) closeModal();
  });

  document.addEventListener("click", function (e) {
    var trigger = e.target.closest("[data-video-src]");
    if (!trigger) return;
    openModal(trigger.dataset.videoSrc, trigger.dataset.videoCaption || "");
  });
})();
