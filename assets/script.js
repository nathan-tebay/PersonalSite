// ── Lorem ipsum generator (~10 000 words) ─────────────────────────────
const PARA = "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.";
const ALT  = "Sed ut perspiciatis unde omnis iste natus error sit voluptatem accusantium doloremque laudantium, totam rem aperiam, eaque ipsa quae ab illo inventore veritatis et quasi architecto beatae vitae dicta sunt explicabo. Nemo enim ipsam voluptatem quia voluptas sit aspernatur aut odit aut fugit, sed quia consequuntur magni dolores eos qui ratione voluptatem sequi nesciunt. Neque porro quisquam est, qui dolorem ipsum quia dolor sit amet, consectetur, adipisci velit, sed quia non numquam eius modi tempora incidunt ut labore et dolore magnam aliquam quaerat voluptatem.";
const contentPanel = document.getElementById('content-panel');
if (contentPanel) {
  for (let i = 0; i < 145; i++) {
    const p = document.createElement('p');
    p.textContent = i % 2 === 0 ? PARA : ALT;
    contentPanel.appendChild(p);
  }
}

// ── Theme definitions ─────────────────────────────────────────────────
// All chosen to complement the green PCB circuit-board logo.
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

function toCss([r, g, b]) { return `rgb(${r},${g},${b})`; }

// WCAG relative luminance
function luminance([r, g, b]) {
  const lin = v => { v /= 255; return v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4); };
  return 0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(b);
}

// ── Apply a theme ─────────────────────────────────────────────────────
const body      = document.body;
const panel     = document.getElementById('panel');
const allPanels = document.querySelectorAll('.side-panel');
const root      = document.documentElement;

function applyTheme(hex) {
  const base    = hexToRgb(hex);
  const isLight = luminance(base) > 0.15; // background is light → panels go darker

  // Light themes: darken panels; dark themes: lighten panels
  const fill = isLight ? darken(base, 0.78) : lighten(base, 0.18);

  if (isLight) {
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

  const borderColor = toCss(darken(base, 0.5));
  const fillCss     = toCss(fill);

  body.style.backgroundColor = hex;
  if (panel) panel.style.outlineColor = borderColor;
  allPanels.forEach(p => {
    p.style.outlineColor    = borderColor;
    p.style.backgroundColor = fillCss;
  });
}

// ── Tooltip (body-level, escapes backdrop-filter stacking context) ────
const tip = document.createElement('div');
tip.id = 'swatch-tip';
document.body.appendChild(tip);

function showTip(el, label) {
  const r = el.getBoundingClientRect();
  tip.textContent = label;
  tip.style.opacity = '0';
  tip.style.display = 'block';
  const tw = tip.offsetWidth;
  tip.style.left = `${r.left + r.width / 2 - tw / 2}px`;
  tip.style.top  = `${r.top - tip.offsetHeight - 7}px`;
  tip.style.opacity = '1';
}

function hideTip() { tip.style.opacity = '0'; }

const savedHex = localStorage.getItem('theme') ?? THEMES[0].hex;

// ── Render swatches (only on pages that have the picker) ──────────────
const swatchContainer = document.getElementById('swatches');
if (swatchContainer) {
  let activeBtn = null;

  THEMES.forEach((theme) => {
    const btn = document.createElement('button');
    btn.className = 'swatch';
    btn.style.backgroundColor = theme.hex;
    btn.setAttribute('aria-label', theme.name);
    btn.addEventListener('mouseenter', () => showTip(btn, theme.name));
    btn.addEventListener('mouseleave', hideTip);
    btn.addEventListener('click', () => {
      if (activeBtn) activeBtn.classList.remove('active');
      btn.classList.add('active');
      activeBtn = btn;
      hideTip();
      applyTheme(theme.hex);
      localStorage.setItem('theme', theme.hex);
    });
    swatchContainer.appendChild(btn);
    if (theme.hex === savedHex) {
      btn.classList.add('active');
      activeBtn = btn;
    }
  });

  // Fall back to first swatch if saved value no longer matches any theme
  if (!activeBtn) {
    activeBtn = swatchContainer.firstChild;
    activeBtn.classList.add('active');
  }
}

applyTheme(savedHex);
