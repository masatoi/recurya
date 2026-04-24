// resources/static/js/learn.js
// Progress tracking for SICP notebook course — local-only, no server state.

const STORAGE_KEY = 'recurya:learn:v1';

function loadProgress() {
  try {
    return JSON.parse(localStorage.getItem(STORAGE_KEY)) || {};
  } catch (_) {
    return {};
  }
}

function saveProgress(obj) {
  localStorage.setItem(STORAGE_KEY, JSON.stringify(obj));
}

function updateProgress(notebookId, cellId) {
  const p = loadProgress();
  if (!p[notebookId]) {
    p[notebookId] = { passed: [], last_visited_at: null };
  }
  if (!p[notebookId].passed.includes(cellId)) {
    p[notebookId].passed.push(cellId);
  }
  p[notebookId].last_visited_at = new Date().toISOString();
  saveProgress(p);
}

function badge(text) {
  const b = document.createElement('span');
  b.className = 'progress-badge';
  b.textContent = text;
  b.style.cssText =
    'float:right;background:#16a34a;color:#fff;' +
    'padding:2px 8px;border-radius:999px;font-size:0.75rem;';
  return b;
}

function markCellBadge(cellNode) {
  if (!cellNode || cellNode.querySelector('.progress-badge')) return;
  cellNode.prepend(badge('✓ done'));
}

function markCompletedCells(notebookId) {
  const nb = loadProgress()[notebookId];
  if (!nb) return;
  for (const cellId of nb.passed) {
    const cell = document.querySelector(
      `[data-cell-id="${CSS.escape(cellId.toLowerCase())}"]`);
    markCellBadge(cell);
  }
}

function renderHomeCardProgress() {
  const progress = loadProgress();
  document.querySelectorAll('[data-notebook-id]').forEach((card) => {
    const nbId = card.dataset.notebookId;
    const nbProgress = progress[nbId];
    if (!nbProgress || nbProgress.passed.length === 0) return;
    const count = nbProgress.passed.length;
    const meta = card.querySelector('.nb-card__meta');
    if (meta) {
      const tag = document.createElement('span');
      tag.textContent = ` · ${count} 完了`;
      tag.style.color = '#4ade80';
      meta.appendChild(tag);
    }
  });
}

document.addEventListener('DOMContentLoaded', () => {
  // On a notebook page, body has data-notebook-id
  const nbId = document.body.dataset.notebookId;
  if (nbId && document.body.dataset.page !== 'learn-home') {
    markCompletedCells(nbId);
  }
  // On the home page, mark cards
  if (document.body.dataset.page === 'learn-home') {
    renderHomeCardProgress();
  }
});

document.body.addEventListener('cell-passed', (e) => {
  const detail = (e && e.detail) || {};
  const nb = detail.notebook;
  const cell = detail.cell;
  if (!nb || !cell) return;
  updateProgress(nb, cell);
  const node = document.querySelector(
    `[data-cell-id="${CSS.escape(cell.toLowerCase())}"]`);
  markCellBadge(node);
});
