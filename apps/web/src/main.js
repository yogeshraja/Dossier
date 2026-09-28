import { DOCS_SECTIONS } from './docs-data.js';
import { THEME_CONSTANTS, TIMING_CONSTANTS, DOM_SELECTORS } from './constants.js';
import { WebConfig } from './config.js';

// State
let currentSectionIndex = 0;
let currentItemIndex = 0;
let searchQuery = '';

// Theme Management
function initTheme() {
  const savedTheme = localStorage.getItem(THEME_CONSTANTS.STORAGE_KEY) || THEME_CONSTANTS.THEME_DARK;
  document.documentElement.setAttribute('data-theme', savedTheme);
  updateThemeButton(savedTheme);
}

function toggleTheme() {
  const current = document.documentElement.getAttribute('data-theme') || THEME_CONSTANTS.THEME_DARK;
  const next = current === THEME_CONSTANTS.THEME_DARK ? THEME_CONSTANTS.THEME_LIGHT : THEME_CONSTANTS.THEME_DARK;
  document.documentElement.setAttribute('data-theme', next);
  localStorage.setItem(THEME_CONSTANTS.STORAGE_KEY, next);
  updateThemeButton(next);
}

function updateThemeButton(theme) {
  const btn = document.getElementById(DOM_SELECTORS.THEME_TOGGLE);
  if (btn) {
    btn.innerHTML = theme === THEME_CONSTANTS.THEME_DARK ? THEME_CONSTANTS.DARK_LABEL : THEME_CONSTANTS.LIGHT_LABEL;
  }
}

// Simple Markdown Parser for Docs Content
function parseMarkdown(md) {
  let html = md
    // Headers
    .replace(/^### (.*$)/gim, '<h3>$1</h3>')
    .replace(/^## (.*$)/gim, '<h2>$1</h2>')
    .replace(/^# (.*$)/gim, '<h1>$1</h1>')
    // Code blocks with language
    .replace(/```([\w]*)\n([\s\S]*?)```/gim, (match, lang, code) => {
      const cleanCode = code.replace(/</g, '&lt;').replace(/>/g, '&gt;');
      return `<pre><button class="code-copy-btn" onclick="copyCode(this)">Copy</button><code>${cleanCode.trim()}</code></pre>`;
    })
    // Inline code
    .replace(/`([^`]+)`/g, '<code>$1</code>')
    // Bold
    .replace(/\*\*(.*?)\*\*/g, '<strong>$1</strong>')
    // Lists
    .replace(/^\s*-\s+(.*$)/gim, '<li>$1</li>')
    // Paragraphs
    .replace(/\n\n/gim, '</p><p>');

  return `<article class="docs-article"><p>${html}</p></article>`;
}

// Global copy helper
window.copyCode = function(button) {
  const pre = button.parentElement;
  const code = pre.querySelector('code');
  if (code) {
    navigator.clipboard.writeText(code.innerText).then(() => {
      button.innerText = 'Copied!';
      button.style.color = THEME_CONSTANTS.SUCCESS_COLOR;
      setTimeout(() => {
        button.innerText = 'Copy';
        button.style.color = '';
      }, TIMING_CONSTANTS.COPY_FEEDBACK_MS);
    });
  }
};

// Render Sidebar Navigation
function renderSidebar() {
  const navContainer = document.getElementById(DOM_SELECTORS.DOCS_NAV_GROUPS);
  if (!navContainer) return;

  navContainer.innerHTML = '';

  DOCS_SECTIONS.forEach((section, sIdx) => {
    // Check if section matches search
    const filteredItems = section.items.filter(item => {
      if (!searchQuery) return true;
      return item.title.toLowerCase().includes(searchQuery.toLowerCase()) ||
             item.content.toLowerCase().includes(searchQuery.toLowerCase());
    });

    if (filteredItems.length === 0) return;

    const group = document.createElement('div');
    group.className = 'nav-group';

    const title = document.createElement('div');
    title.className = 'nav-group-title';
    title.innerHTML = `<span>${section.icon}</span> ${section.title}`;
    group.appendChild(title);

    filteredItems.forEach((item) => {
      const actualItemIdx = section.items.indexOf(item);
      const isSelected = sIdx === currentSectionIndex && actualItemIdx === currentItemIndex;

      const btn = document.createElement('button');
      btn.className = `nav-item-btn ${isSelected ? 'active' : ''}`;
      btn.innerHTML = `
        <span>${item.title}</span>
        ${item.badge ? `<span class="item-badge">${item.badge}</span>` : ''}
      `;

      btn.addEventListener('click', () => {
        currentSectionIndex = sIdx;
        currentItemIndex = actualItemIdx;
        renderSidebar();
        renderActiveDoc();
      });

      group.appendChild(btn);
    });

    navContainer.appendChild(group);
  });
}

// Render Active Document
function renderActiveDoc() {
  const viewer = document.getElementById(DOM_SELECTORS.DOCS_VIEWER);
  if (!viewer) return;

  const section = DOCS_SECTIONS[currentSectionIndex];
  if (!section) return;

  const item = section.items[currentItemIndex];
  if (!item) return;

  let htmlContent = parseMarkdown(item.content);

  // If viewing auth or api endpoints, attach live interactive playground
  if (item.id === 'activation-gate' || item.id === 'auth-endpoints') {
    htmlContent += `
      <div class="api-tester">
        <div class="api-tester-header">
          <span class="api-badge">POST /api/v1/auth/activate</span>
          <button class="api-run-btn" id="${DOM_SELECTORS.SIMULATE_ACTIVATE_BTN}">Test Live Endpoint</button>
        </div>
        <p style="font-size: 0.85rem; color: var(--text-secondary); margin-bottom: 0.75rem;">Endpoint target: ${WebConfig.apiBaseUrl}</p>
        <div class="api-response-box" id="${DOM_SELECTORS.API_OUTPUT}">// Click "Test Live Endpoint" to dispatch request...</div>
      </div>
    `;
  }

  viewer.innerHTML = htmlContent;

  // Bind interactive tester if present
  const simBtn = document.getElementById(DOM_SELECTORS.SIMULATE_ACTIVATE_BTN);
  if (simBtn) {
    simBtn.addEventListener('click', simulateActivationApi);
  }
}

function simulateActivationApi() {
  const out = document.getElementById(DOM_SELECTORS.API_OUTPUT);
  if (!out) return;

  out.innerText = `Dispatching POST /api/v1/auth/activate to ${WebConfig.apiBaseUrl}...\n`;
  setTimeout(() => {
    const mockResponse = {
      success: true,
      token: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJvcC1hZG1pbi0wMDEiLCJ0ZW5hbnRJZCI6Imtp..." + Math.random().toString(36).substring(7),
      tenantId: "kiosk-tenant-csc-01",
      kioskName: "Main CSC Document Center",
      admin: {
        id: "op-admin-001",
        name: "Yogesh Raja",
        role: "admin"
      },
      operators: [
        { id: "op-admin-001", name: "Yogesh Raja", role: "admin" },
        { id: "op-002", name: "Desk Operator 1", role: "operator" }
      ],
      serverTime: new Date().toISOString()
    };
    out.innerText = `// HTTP 200 OK (Cloudflare D1 Edge)\n` + JSON.stringify(mockResponse, null, 2);
  }, TIMING_CONSTANTS.API_SIMULATION_DELAY_MS);
}

// Search Filter Input
function setupSearch() {
  const searchInput = document.getElementById(DOM_SELECTORS.DOCS_SEARCH);
  if (searchInput) {
    searchInput.addEventListener('input', (e) => {
      searchQuery = e.target.value;
      renderSidebar();
    });
  }
}

// Initialize on DOM Ready
document.addEventListener('DOMContentLoaded', () => {
  initTheme();
  
  const themeBtn = document.getElementById(DOM_SELECTORS.THEME_TOGGLE);
  if (themeBtn) {
    themeBtn.addEventListener('click', toggleTheme);
  }

  renderSidebar();
  renderActiveDoc();
  setupSearch();
});
