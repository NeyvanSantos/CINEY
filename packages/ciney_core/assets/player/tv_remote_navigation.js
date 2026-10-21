(function () {
  'use strict';
  if (window === window.top || window.__cineyTvPrepareMenu) return;
  let controls = [], current = null, announced = false;
  const labels = ['Dublado', 'Legendado', 'Servidor Principal', 'Servidor Alternativo'];
  function label(element) { return (element.textContent || '').replace(/\s+/g, ' ').trim(); }
  function visible(element) {
    const style = getComputedStyle(element);
    return !element.disabled && element.getAttribute('aria-disabled') !== 'true' &&
      style.display !== 'none' && style.visibility !== 'hidden' && element.getClientRects().length > 0;
  }
  function notify(action, element) {
    try { TvMediaBridge.postMessage(JSON.stringify({ event: 'remoteMenu', action,
      label: element ? label(element) : null })); } catch (_) {}
  }
  function focus(element) {
    if (!element) return;
    for (const control of controls) control.removeAttribute('data-ciney-tv-focus');
    current = element;
    element.setAttribute('data-ciney-tv-focus', 'true');
    element.focus({ preventScroll: true });
    if (element.scrollIntoView) element.scrollIntoView({ block: 'nearest', inline: 'nearest' });
  }
  window.__cineyTvPrepareMenu = function (doc) {
    if (doc !== document || !['myembed.biz', 'playerflix.ink', 'superflixapi.quest', 'superflixapi.fun']
      .includes(location.hostname) || location.pathname !== window.__cineyProviderPath) return false;
    const candidates = Array.from(doc.querySelectorAll('button, [role="button"], [onclick], a[href], div, span'));
    controls = candidates.filter(element => labels.includes(label(element)) && visible(element) &&
      (!element.parentElement || label(element.parentElement) !== label(element)));
    if (!controls.some(element => label(element) === 'Servidor Principal') ||
        !controls.some(element => ['Dublado', 'Legendado'].includes(label(element)))) return false;
    for (const element of controls) {
      element.tabIndex = 0;
      if (!element.getAttribute('role')) element.setAttribute('role', 'button');
    }
    if (!doc.__cineyTvFocusStyle) {
      const style = doc.createElement('style');
      style.textContent = '[data-ciney-tv-focus="true"]{outline:4px solid #ff6b00!important;outline-offset:4px!important;box-shadow:0 0 0 7px rgba(255,107,0,.25)!important}';
      (doc.head || doc.documentElement).appendChild(style);
      doc.__cineyTvFocusStyle = true;
    }
    if (!controls.includes(current)) focus(controls.find(element => label(element) === 'Servidor Principal'));
    if (!announced) { announced = true; notify('ready', current); }
    return true;
  };
  function move(key) {
    const rect = current.getBoundingClientRect();
    const x = rect.left + rect.width / 2, y = rect.top + rect.height / 2;
    const horizontal = key === 'ArrowLeft' || key === 'ArrowRight';
    const sign = key === 'ArrowLeft' || key === 'ArrowUp' ? -1 : 1;
    let best = null, bestScore = Infinity;
    for (const element of controls) {
      if (element === current) continue;
      const next = element.getBoundingClientRect();
      const dx = next.left + next.width / 2 - x, dy = next.top + next.height / 2 - y;
      const primary = (horizontal ? dx : dy) * sign;
      const cross = Math.abs(horizontal ? dy : dx);
      if (primary <= 1 || (horizontal && cross > Math.max(rect.height, next.height))) continue;
      const score = primary + cross * 3;
      if (score < bestScore) { best = element; bestScore = score; }
    }
    focus(best);
  }
  function keydown(event) {
    if (!window.__cineyTvPrepareMenu(document)) return;
    const key = event.key;
    if (['ArrowUp', 'ArrowDown', 'ArrowLeft', 'ArrowRight'].includes(key)) {
      event.preventDefault(); event.stopImmediatePropagation();
      move(key);
    } else if (['Enter', 'Select', 'Accept', ' ', 'Spacebar'].includes(key)) {
      event.preventDefault(); event.stopImmediatePropagation();
      if (event.repeat || !current) return;
      notify(label(current).startsWith('Servidor') ? 'selected' : 'audio', current);
      // Some providers attach the handler to a child of the visual card.
      // Activate its label so the event bubbles through that handler.
      const children = current.querySelectorAll ? Array.from(current.querySelectorAll('button, [role="button"], [onclick], a[href], div, span')) : [];
      const target = children.find(element => label(element) === label(current) &&
        !Array.from(element.children || []).some(child => label(child) === label(current)));
      (target || current).click();
    }
  }
  document.addEventListener('keydown', keydown, true);
  document.addEventListener('focusin', event => {
    if (controls.includes(event.target) && event.target !== current) focus(event.target);
  }, true);
  window.addEventListener('pagehide', () => document.removeEventListener('keydown', keydown, true), { once: true });
})();
