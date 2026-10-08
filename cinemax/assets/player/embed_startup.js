(function () {
  'use strict';
  if (window.__cineyStartPlayback) return;
  const enabled = window.__cineyAutoStart === true;
  const providerHost = window.__cineyProviderHost;
  const providerPath = window.__cineyProviderPath;
  const states = new WeakMap();
  const attemptedVideos = new WeakSet();
  const preferenceKey = 'ciney-player-selection-v1';
  let cancelled = false;

  function label(row) {
    return (row.textContent || '').replace(/\s+/g, ' ').trim().slice(0, 80);
  }

  function visible(element, doc) {
    if (element.disabled || element.getAttribute('aria-disabled') === 'true') return false;
    const style = doc.defaultView.getComputedStyle(element);
    return style.display !== 'none' && style.visibility !== 'hidden' &&
      element.getClientRects().length > 0;
  }

  function providerMenu(doc) {
    const location = doc.location;
    if (!location || location.pathname !== providerPath) return [];
    const knownHost = location.hostname === providerHost ||
      (providerHost === 'myembed.biz' && location.hostname === 'playerflix.ink');
    if (!knownHost || !['myembed.biz', 'superflixapi.quest'].includes(providerHost)) return [];
    // Verified EmbedMovies/PlayerFlix menu: only invoke existing provider controls.
    const rows = Array.from(doc.querySelectorAll('#optionList .option[data-embed][data-audio]'));
    if (rows.length) return rows;
    // The compact menu uses a principal-server control and audio tabs.
    const controls = Array.from(doc.querySelectorAll('button, [role="button"], [onclick], a[href]'));
    const hasAudioTabs = ['Dublado', 'Legendado'].every(text =>
      controls.some(element => label(element) === text && visible(element, doc)));
    if (!hasAudioTabs) return [];
    // Compact menus can use delegated events on a div rather than a button.
    // Click the exact label once; its event bubbles to the provider's row.
    const candidates = Array.from(new Set(controls.concat(
      Array.from(doc.querySelectorAll('div, span')))));
    const principal = candidates.filter(element => label(element) === 'Servidor Principal' &&
      !Array.from(element.children || []).some(child => label(child) === 'Servidor Principal') &&
      visible(element, doc));
    return principal.length === 1 ? principal : [];
  }

  function attach(doc) {
    let state = states.get(doc);
    if (state) return state;
    state = { started: Date.now(), selected: false, cancelled: false, preference: null };
    states.set(doc, state);
    try {
      const saved = JSON.parse(doc.defaultView.localStorage.getItem(preferenceKey));
      if (saved && typeof saved.label === 'string' && saved.label.length <= 80 &&
          ['pt-br', 'en-us', null].includes(saved.audio)) state.preference = saved;
    } catch (_) { /* A provider can disable storage; selection still works. */ }
    function stop(event) {
      if (event.isTrusted) state.cancelled = true;
    }
    function remember(event) {
      if (!event.isTrusted) return;
      state.cancelled = true;
      const rows = providerMenu(doc);
      const row = rows.find(element => element === event.target || element.contains(event.target));
      if (!row) return;
      const audio = row.getAttribute('data-audio');
      const preference = { label: label(row), audio: ['pt-br', 'en-us'].includes(audio) ? audio : null };
      try { doc.defaultView.localStorage.setItem(preferenceKey, JSON.stringify(preference)); } catch (_) {}
    }
    doc.addEventListener('pointerdown', stop, true);
    doc.addEventListener('keydown', stop, true);
    doc.addEventListener('click', remember, true);
    doc.defaultView.addEventListener('pagehide', () => {
      doc.removeEventListener('pointerdown', stop, true);
      doc.removeEventListener('keydown', stop, true);
      doc.removeEventListener('click', remember, true);
    }, { once: true });
    return state;
  }

  window.__cineyCancelStartup = function () { cancelled = true; };

  window.__cineyStartPlayback = function (doc) {
    const state = attach(doc);
    if (!enabled || cancelled || state.cancelled || state.selected ||
        doc.readyState === 'loading' || Date.now() - state.started > 20000) return;
    const rows = providerMenu(doc);
    if (!rows.length) return;
    // Restore a manually chosen audio/server when it still exists; otherwise
    // respect the provider's currently visible audio group.
    const preference = state.preference;
    let chosen = preference && rows.find(row => label(row) === preference.label &&
      row.getAttribute('data-audio') === preference.audio);
    if (chosen && !visible(chosen, doc)) {
      const selector = doc.querySelector('#selectorOpt');
      if (selector && Array.from(selector.options).some(option => option.value === preference.audio)) {
        selector.value = preference.audio;
        selector.dispatchEvent(new doc.defaultView.Event('change', { bubbles: true }));
      }
    }
    if (!chosen || !visible(chosen, doc)) chosen = rows.find(row => visible(row, doc));
    if (!chosen) return;
    state.selected = true;
    chosen.click();
  };

  window.__cineyAutoPlay = function (video, restoring) {
    const state = attach(video.ownerDocument || document);
    // Some providers only populate seekable ranges after play. Bootstrap once
    // in that case; restoring remains true so the saved checkpoint is protected.
    const needsStart = restoring && video.seekable && video.seekable.length === 0;
    if (!enabled || cancelled || state.cancelled || (restoring && !needsStart) || !video.paused ||
        video.ended || video.error || video.readyState < 2 ||
        !Number.isFinite(video.duration) || video.duration < 180 ||
        attemptedVideos.has(video) ||
        (window.__cineyIsContentMedia && !window.__cineyIsContentMedia(video))) return;
    attemptedVideos.add(video);
    function interaction() {
      try { PlayerBridge.postMessage(JSON.stringify({ event: 'interaction' })); } catch (_) {}
    }
    try {
      const pending = video.play();
      if (pending && pending.catch) pending.catch(interaction);
    } catch (_) { interaction(); }
  };
})();
