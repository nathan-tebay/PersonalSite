// ── Lorem ipsum placeholder content ───────────────────────────────────
const LOREM_PARAGRAPH = 'Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.';
const LOREM_PARAGRAPH_ALT = 'Sed ut perspiciatis unde omnis iste natus error sit voluptatem accusantium doloremque laudantium, totam rem aperiam, eaque ipsa quae ab illo inventore veritatis et quasi architecto beatae vitae dicta sunt explicabo. Nemo enim ipsam voluptatem quia voluptas sit aspernatur aut odit aut fugit, sed quia consequuntur magni dolores eos qui ratione voluptatem sequi nesciunt. Neque porro quisquam est, qui dolorem ipsum quia dolor sit amet, consectetur, adipisci velit, sed quia non numquam eius modi tempora incidunt ut labore et dolore magnam aliquam quaerat voluptatem.';

const contentPanel = document.getElementById('content-panel');
if (contentPanel) {
  for (let i = 0; i < 145; i++) {
    const paragraph = document.createElement('p');
    paragraph.textContent = i % 2 === 0 ? LOREM_PARAGRAPH : LOREM_PARAGRAPH_ALT;
    contentPanel.appendChild(paragraph);
  }
}

// ── Theme definitions ──────────────────────────────────────────────────

/** @typedef {{ name: string, hex: string }} Theme */

/** @type {Theme[]} All themes chosen to complement the green PCB circuit-board logo. */
const THEMES = [
  { name: 'Forest',    hex: '#0d1f14' },  // deep PCB green
  { name: 'Abyss',     hex: '#0a1520' },  // deep ocean blue
  { name: 'Void',      hex: '#18102e' },  // dark violet
  { name: 'Obsidian',  hex: '#111111' },  // near-black neutral
  { name: 'Gunmetal',  hex: '#14181e' },  // dark blue-gray
  { name: 'Ember',     hex: '#7a2800' },  // burnt orange
  { name: 'Rust',      hex: '#a84518' },  // lighter burnt orange
  { name: 'Cobalt',    hex: '#0d1a3a' },  // deep blue — safe for red-green colour blindness
  { name: 'Graphite',  hex: '#1c1c1c' },  // neutral gray — hue-free, works for all CVD types
  { name: 'Fog',       hex: '#b8c4cc' },  // light blue-gray
  { name: 'Parchment', hex: '#c8b89a' },  // warm tan/cream
  { name: 'Sage',      hex: '#8aad92' },  // muted sage green
];

// ── Colour helpers ─────────────────────────────────────────────────────

/**
 * Converts a 6-digit hex color string to an [R, G, B] array.
 * @param {string} hex - A hex color string like '#1a2b3c'.
 * @returns {[number, number, number]} Array of [red, green, blue] values (0–255).
 */
function hexToRgb(hex) {
  return [
    parseInt(hex.slice(1, 3), 16),
    parseInt(hex.slice(3, 5), 16),
    parseInt(hex.slice(5, 7), 16),
  ];
}

/**
 * Darkens an RGB color by multiplying each channel by a scale factor.
 * @param {[number, number, number]} _ - Input color as [red, green, blue].
 * @param {number} factor - Scale factor in range 0–1 (0 = black, 1 = unchanged).
 * @returns {[number, number, number]} Darkened color.
 */
function darken([red, green, blue], factor) {
  return [Math.round(red * factor), Math.round(green * factor), Math.round(blue * factor)];
}

/**
 * Lightens an RGB color by blending it toward white by the given amount.
 * @param {[number, number, number]} _ - Input color as [red, green, blue].
 * @param {number} amount - Blend amount in range 0–1 (0 = unchanged, 1 = white).
 * @returns {[number, number, number]} Lightened color.
 */
function lighten([red, green, blue], amount) {
  return [
    Math.round(red   + (255 - red)   * amount),
    Math.round(green + (255 - green) * amount),
    Math.round(blue  + (255 - blue)  * amount),
  ];
}

/**
 * Converts an RGB array to a CSS rgb() string.
 * @param {[number, number, number]} _ - Color as [red, green, blue].
 * @returns {string} CSS color string like 'rgb(26,43,60)'.
 */
function toCss([red, green, blue]) { return `rgb(${red},${green},${blue})`; }

/**
 * Computes the WCAG relative luminance of an RGB color.
 * @param {[number, number, number]} _ - Color as [red, green, blue].
 * @returns {number} Luminance value in range 0–1.
 */
function luminance([red, green, blue]) {
  const linearize = (channelValue) => {
    const normalized = channelValue / 255;
    return normalized <= 0.03928
      ? normalized / 12.92
      : Math.pow((normalized + 0.055) / 1.055, 2.4);
  };
  return 0.2126 * linearize(red) + 0.7152 * linearize(green) + 0.0722 * linearize(blue);
}

// ── Apply a theme ──────────────────────────────────────────────────────
const body = document.body;
const root = document.documentElement;

/**
 * Applies a background theme to the page, updating body color, panel fills,
 * outlines, and all text-related CSS custom properties.
 * @param {string} hex - A hex color string like '#0d1f14'.
 */
function applyTheme(hex) {
  const baseColor = hexToRgb(hex);
  const isLightBackground = luminance(baseColor) > 0.15;

  // Light themes: darken panels; dark themes: lighten panels
  const panelFill = isLightBackground ? darken(baseColor, 0.78) : lighten(baseColor, 0.18);

  if (isLightBackground) {
    root.style.setProperty('--text-high', 'rgba(0,0,0,0.87)');
    root.style.setProperty('--text-mid',  'rgba(0,0,0,0.60)');
    root.style.setProperty('--text-low',  'rgba(0,0,0,0.40)');
    root.style.setProperty('--text-link', '#166534');
    root.style.setProperty('--divider',   'rgba(0,0,0,0.10)');
    root.style.setProperty('--hover-bg',  'rgba(0,0,0,0.06)');
  } else {
    root.style.setProperty('--text-high', 'rgba(255,255,255,0.90)');
    root.style.setProperty('--text-mid',  'rgba(255,255,255,0.65)');
    root.style.setProperty('--text-low',  'rgba(255,255,255,0.38)');
    root.style.setProperty('--text-link', '#4ade80');
    root.style.setProperty('--divider',   'rgba(255,255,255,0.08)');
    root.style.setProperty('--hover-bg',  'rgba(255,255,255,0.07)');
  }

  // Drive panel colours via CSS custom properties so every panel on every page
  // picks up the theme, including those injected by layout.js.
  root.style.setProperty('--info-bg',      toCss(panelFill));
  root.style.setProperty('--panel-border', toCss(darken(baseColor, 0.5)));
  body.style.backgroundColor = hex;
}

// ── Tooltip (body-level, escapes backdrop-filter stacking context) ─────
const tooltipElement = document.createElement('div');
tooltipElement.id = 'swatch-tip';
document.body.appendChild(tooltipElement);

/**
 * Positions and shows the swatch tooltip near the given element.
 * @param {HTMLElement} element - The swatch button that triggered the tooltip.
 * @param {string} label - Text to display in the tooltip.
 */
function showTip(element, label) {
  const boundingRect = element.getBoundingClientRect();
  tooltipElement.textContent = label;
  tooltipElement.style.opacity = '0';
  tooltipElement.style.display = 'block';
  const tooltipWidth = tooltipElement.offsetWidth;
  tooltipElement.style.left = `${boundingRect.left + boundingRect.width / 2 - tooltipWidth / 2}px`;
  tooltipElement.style.top  = `${boundingRect.top - tooltipElement.offsetHeight - 7}px`;
  tooltipElement.style.opacity = '1';
}

/** Hides the swatch tooltip. */
function hideTip() { tooltipElement.style.opacity = '0'; }

// ── Theme persistence (localStorage + window.name fallback for file://) ──

/**
 * Checks whether a string is a valid 6-digit hex color.
 * @param {string} hexString - The string to validate.
 * @returns {boolean}
 */
function isValidHex(hexString) { return /^#[0-9a-fA-F]{6}$/.test(hexString); }

/**
 * Retrieves the saved theme hex from localStorage, falling back to window.name
 * (which persists across same-tab file:// navigations) and then to the default theme.
 * @returns {string} A valid hex color string.
 */
function getSavedTheme() {
  const localStorageValue = localStorage.getItem('theme');
  if (localStorageValue && isValidHex(localStorageValue)) return localStorageValue;
  if (isValidHex(window.name)) return window.name;
  return THEMES[0].hex;
}

/**
 * Persists the selected theme hex to both localStorage and window.name.
 * @param {string} hex - A valid hex color string.
 */
function saveTheme(hex) {
  localStorage.setItem('theme', hex);
  window.name = hex; // persists across same-tab file:// navigations
}

const savedHex = getSavedTheme();
window.name = savedHex; // seed window.name so the next page can read it

// ── Render swatches (only on pages that have the picker) ───────────────
const swatchContainer = document.getElementById('swatches');
if (swatchContainer) {
  let activeSwatchButton = null;

  THEMES.forEach((theme) => {
    const swatchButton = document.createElement('button');
    swatchButton.className = 'swatch';
    swatchButton.style.backgroundColor = theme.hex;
    swatchButton.setAttribute('aria-label', theme.name);
    swatchButton.addEventListener('mouseenter', () => showTip(swatchButton, theme.name));
    swatchButton.addEventListener('mouseleave', hideTip);
    swatchButton.addEventListener('click', () => {
      if (activeSwatchButton) activeSwatchButton.classList.remove('active');
      swatchButton.classList.add('active');
      activeSwatchButton = swatchButton;
      hideTip();
      applyTheme(theme.hex);
      saveTheme(theme.hex);
    });
    swatchContainer.appendChild(swatchButton);
    if (theme.hex === savedHex) {
      swatchButton.classList.add('active');
      activeSwatchButton = swatchButton;
    }
  });

  // Fall back to first swatch if saved value no longer matches any theme
  if (!activeSwatchButton) {
    activeSwatchButton = swatchContainer.firstChild;
    activeSwatchButton.classList.add('active');
  }
}

applyTheme(savedHex);
