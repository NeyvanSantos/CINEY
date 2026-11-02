(function () {
  'use strict';
  if (window === window.top || window.__cineyTvPrepareMenu) return;
  let controls = [], current = null, announced = false;
  let pointer = null, pointerX = 0, pointerY = 0;
  const mouseMode = () => ['superflixapi.quest', 'superflixapi.fun'].includes(location.hostname) || /superflix/i.test(location.hostname);
  function hidePointer() { if (pointer) pointer.style.display = 'none'; }
  function paintPointer() {
    if (!pointer) {
      pointer = document.createElement('div');
      pointer.setAttribute('aria-hidden', 'true');
      pointer.style.cssText = 'position:fixed;width:18px;height:18px;border:3px solid white;border-radius:50%;background:#ff6b00;box-shadow:0 1px 6px black;pointer-events:none;z-index:2147483647;transform:translate(-50%,-50%);';
      (document.body || document.documentElement).appendChild(pointer);
    }
    pointer.style.display = 'block';
    pointer.style.left = pointerX + 'px'; pointer.style.top = pointerY + 'px';
  }
  const labels = ['Dublado', 'Legendado', 'Servidor Principal', 'Servidor Alternativo'];
  function label(element) { return (element.textContent || '').replace(/\s+/g, ' ').trim(); }
  function visible(element) {
    const style = getComputedStyle(element);
    return !element.disabled && element.getAttribute('aria-disabled') !== 'true' &&
      style.display !== 'none' && style.visibility !== 'hidden' && element.getClientRects().length > 0;
  }
  function menuHit(x, y) {
    let hit = document.elementFromPoint(x, y);
    // Some providers place an empty, transparent external link over the whole
    // menu. It is not a player/control: let genuine pointer input reach the
    // verified menu below it. Never alter frames, visible content or challenges.
    for (let attempt = 0; hit && attempt < 3; attempt++) {
      const style = getComputedStyle(hit);
      const wrapper = hit.tagName === 'DIV' && !label(hit) && hit.children.length === 1 &&
        style.position === 'fixed' && Number(style.opacity) <= 0.05;
      const link = wrapper ? hit.children[0] : hit;
      if (link.tagName !== 'A' || label(link) || link.children.length) break;
      let destination;
      try { destination = new URL(link.href, location.href); } catch (_) { break; }
      if (!/^https?:$/.test(destination.protocol) ||
          destination.hostname === location.hostname ||
          /(^|\.)cloudflare\.com$/i.test(destination.hostname)) break;
      const rect = hit.getBoundingClientRect();
      if (rect.left > 10 || rect.top > 10 ||
          rect.left + rect.width < window.innerWidth - 10 ||
          rect.top + rect.height < window.innerHeight - 10 ||
          (!wrapper && !['transparent', 'rgba(0, 0, 0, 0)'].includes(style.backgroundColor)) ||
          style.backgroundImage !== 'none') break;
      hit.style.setProperty('pointer-events', 'none', 'important');
      hit = document.elementFromPoint(x, y);
    }
    return hit;
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
    if (doc !== document || (!['myembed.biz', 'playerflix.ink', 'superflixapi.quest', 'superflixapi.fun'].includes(location.hostname) && !/superflix|myembed|playerflix/i.test(location.hostname)) || location.pathname !== window.__cineyProviderPath) { hidePointer(); return false; }
    const candidates = Array.from(doc.querySelectorAll('button, [role="button"], [onclick], a[href], div, span'));
    controls = candidates.filter(element => labels.includes(label(element)) && visible(element) &&
      (!element.parentElement || label(element.parentElement) !== label(element)));
    if (!controls.some(element => label(element) === 'Servidor Principal') ||
        !controls.some(element => ['Dublado', 'Legendado'].includes(label(element)))) { hidePointer(); return false; }
    if (mouseMode() && doc.elementFromPoint && !controls.some(element => {
      const rect = element.getBoundingClientRect();
      const hit = menuHit(rect.left + rect.width / 2, rect.top + rect.height / 2);
      return hit && (hit === element || element.contains(hit));
    })) { hidePointer(); return false; }
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
    if (!controls.includes(current)) {
      focus(controls.find(element => label(element) === 'Servidor Principal'));
      const rect = current.getBoundingClientRect();
      pointerX = rect.left + rect.width / 2; pointerY = rect.top + rect.height / 2;
    }
    if (mouseMode()) paintPointer();
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
    const confirm = ['Enter', 'Select', 'Accept', ' ', 'Spacebar'].includes(key) ||
      event.keyCode === 23 || event.keyCode === 66 || event.keyCode === 13;
    if (['ArrowUp', 'ArrowDown', 'ArrowLeft', 'ArrowRight'].includes(key)) {
      event.preventDefault(); event.stopImmediatePropagation();
      if (mouseMode()) {
        const step = event.repeat ? 28 : 18;
        pointerX = Math.max(10, Math.min(window.innerWidth - 10, pointerX + (key === 'ArrowRight' ? step : key === 'ArrowLeft' ? -step : 0)));
        pointerY = Math.max(10, Math.min(window.innerHeight - 10, pointerY + (key === 'ArrowDown' ? step : key === 'ArrowUp' ? -step : 0)));
        paintPointer();
      } else move(key);
    } else if (confirm) {
      event.preventDefault(); event.stopImmediatePropagation();
      if (event.repeat || !current) return;
      if (mouseMode()) {
        const target = controls.find(element => {
          const rect = element.getBoundingClientRect();
          return pointerX >= rect.left && pointerX <= rect.left + rect.width &&
            pointerY >= rect.top && pointerY <= rect.top + rect.height;
        });
        if (!target) return;
        if (document.elementFromPoint) {
          const hit = menuHit(pointerX, pointerY);
          if (!hit || (hit !== target && !target.contains(hit))) return;
        }
        if (label(target).startsWith('Servidor')) hidePointer();
        notify(label(target).startsWith('Servidor') ? 'selected' : 'audio', target);
        try {
          TvMediaBridge.postMessage(JSON.stringify({event:'remoteMenu', action:'activate',
            label:label(target), x:pointerX/window.innerWidth, y:pointerY/window.innerHeight}));
        } catch (_) {}
        return;
      }
      notify(label(current).startsWith('Servidor') ? 'selected' : 'audio', current);
      // Some providers attach the handler to a child of the visual card.
      // Activate its label so the event bubbles through that handler.
      const children = current.querySelectorAll ? Array.from(current.querySelectorAll('button, [role="button"], [onclick], a[href], div, span')) : [];
      const target = children.find(element => label(element) === label(current) &&
        !Array.from(element.children || []).some(child => label(child) === label(current)));
      (target || current).click();
    }
  }
  const pointerTimer = window.setInterval ? window.setInterval(() => {
    if (pointer && pointer.style.display !== 'none' &&
        (!window.__cineyTvPrepareMenu(document) ||
         document.querySelector('video') && Array.from(document.querySelectorAll('video')).some(video => !video.paused && video.duration > 180))) hidePointer();
  }, 500) : null;
  document.addEventListener('keydown', keydown, true);
  document.addEventListener('focusin', event => {
    if (controls.includes(event.target) && event.target !== current) focus(event.target);
  }, true);
  window.addEventListener('pagehide', () => { hidePointer(); if (pointerTimer) window.clearInterval(pointerTimer); document.removeEventListener('keydown', keydown, true); }, { once: true });
})();
