(function () {
  'use strict';
  if (window === window.top || window.__cineyTvHlsObserver ||
      /(^|\.)challenges\.cloudflare\.com$/i.test(location.hostname || '')) return;
  window.__cineyTvHlsObserver = true;
  let stopped = false;
  let playbackAnnounced = false;
  const candidates = new Map();
  const emitted = new Set();
  const requests = new WeakMap();
  const maxManifest = 2 * 1024 * 1024;

  function httpUrl(value) {
    try {
      const url = new URL(value, location.href);
      return /^(https?:)$/.test(url.protocol) && !url.username && !url.password ? url.href : null;
    } catch (_) { return null; }
  }
  function headers(value) {
    const result = {};
    try {
      new Headers(value).forEach((v, k) => {
        if (k === 'authorization' || k.startsWith('x-')) result[k] = v;
      });
    } catch (_) {}
    return result;
  }
  function remember(url, text, requestHeaders) {
    if (stopped || typeof text !== 'string' || text.length > maxManifest ||
        !text.trimStart().startsWith('#EXTM3U')) return;
    url = httpUrl(url);
    if (!url) return;
    const master = /#EXT-X-STREAM-INF:/.test(text);
    if (!master && !/#EXT-X-TARGETDURATION:/.test(text)) return;
    const duration = Array.from(text.matchAll(/#EXTINF:([\d.]+)/g))
      .reduce((sum, match) => sum + Number(match[1]), 0);
    // Do not promote short advertisements or trailers to the film player.
    if (!master && /#EXT-X-ENDLIST/.test(text) && duration < 180) return;
    if (candidates.size >= 24 && !candidates.has(url)) return;
    candidates.set(url, { url, master, headers: requestHeaders || {} });
  }
  async function inspectResponse(response, url, requestHeaders) {
    const reader = response.body.getReader();
    const decoder = new TextDecoder();
    let text = '', bytes = 0;
    try {
      while (!stopped) {
        const chunk = await reader.read();
        if (chunk.done) break;
        bytes += chunk.value.byteLength;
        if (bytes > maxManifest) return;
        text += decoder.decode(chunk.value, { stream: true });
        if (text.length >= 16 && !text.trimStart().startsWith('#EXTM3U')) return;
      }
      remember(url, text + decoder.decode(), requestHeaders);
    } finally {
      // A tee's cancel promise may wait for the provider to consume its copy.
      reader.cancel().catch(() => {});
    }
  }

  // Keep the selector/validation page's browser networking unmodified.
  // Media frames still report the authenticated HLS session.
  const providerMenuPage = location.pathname === window.__cineyProviderPath &&
    (['superflixapi.quest', 'superflixapi.fun', 'myembed.biz', 'playerflix.ink'].includes(location.hostname) || /superflix|myembed|playerflix/i.test(location.hostname));
  const originalFetch = window.fetch;
  if (originalFetch && !providerMenuPage) window.fetch = async function (input, options) {
    const response = await originalFetch.apply(this, arguments);
    const url = response.url || (typeof input === 'string' ? input : input.url);
    const type = response.headers.get('content-type') || '';
    const size = Number(response.headers.get('content-length') || 0);
    if (size <= maxManifest && (/mpegurl|text\/|javascript|octet-stream/i.test(type) ||
        /\.m3u8(?:[?#]|$)/i.test(url))) {
      // Clone only plausible manifests, never video segments.
      if (!/\.(?:ts|m4s|mp4|aac)(?:[?#]|$)/i.test(url)) {
        inspectResponse(response.clone(), url,
          headers(options && options.headers || input && input.headers)).catch(() => {});
      }
    }
    return response;
  };
  const xhr = window.XMLHttpRequest && window.XMLHttpRequest.prototype;
  if (xhr && !providerMenuPage) {
    const open = xhr.open, send = xhr.send, setHeader = xhr.setRequestHeader;
    xhr.open = function (method, url) {
      requests.set(this, { url, headers: {} });
      return open.apply(this, arguments);
    };
    xhr.setRequestHeader = function (name, value) {
      const request = requests.get(this);
      if (request && /^(authorization|x-.+)$/i.test(name)) request.headers[name] = value;
      return setHeader.apply(this, arguments);
    };
    xhr.send = function () {
      this.addEventListener('load', () => {
        const request = requests.get(this);
        if (!request) return;
        try {
          let text;
          if (!this.responseType || this.responseType === 'text') {
            text = this.responseText;
          } else if (this.responseType === 'arraybuffer' && this.response &&
                     this.response.byteLength <= maxManifest) {
            // HLS libraries may request even master.txt as binary data.
            const prefix = new TextDecoder().decode(new Uint8Array(this.response, 0,
              Math.min(this.response.byteLength, 32)));
            if (!prefix.trimStart().startsWith('#EXTM3U')) return;
            text = new TextDecoder().decode(this.response);
          } else return;
          remember(this.responseURL || request.url, text, request.headers);
        } catch (_) {}
      }, { once: true });
      return send.apply(this, arguments);
    };
  }
  function poll() {
    if (stopped || window.__cineyNativeTransportActive) return;
    const videos = Array.from(document.querySelectorAll('video'));
    // Provider menus require expensive DOM/layout scans. Once content is
    // playing, keep observing manifests without scanning those menus.
    const playing = videos.some(v => Number.isFinite(v.duration) &&
      v.duration >= 180 && v.paused === false && !v.ended);
    if (playing && !playbackAnnounced) {
      playbackAnnounced = true;
      // Hide only the provider's exact back control once content is playing.
      // Android Back remains handled by the host.
      for (const control of document.querySelectorAll('button, a, [role="button"]')) {
        if ((control.textContent || '').replace(/\s+/g, ' ').trim() === 'Voltar') {
          control.style.setProperty('display', 'none', 'important');
        }
      }
      try { TvMediaBridge.postMessage(JSON.stringify({ event: 'remoteMenu', action: 'playing' })); } catch (_) {}
    }
    if (!playing && window.__cineyStartPlayback) window.__cineyStartPlayback(document);
    // A network request in an unrelated analytics frame is not a player.
    if (!videos.length) return;
    const content = videos.filter(v => !Number.isFinite(v.duration) || v.duration >= 180);
    if (!content.length) return;
    for (const video of content) {
      const url = httpUrl(video.currentSrc || video.src || '');
      if (url && /\.m3u8(?:[?#]|$)/i.test(url) && !candidates.has(url)) {
        candidates.set(url, { url, master: false, headers: {} });
      }
    }
    // JW Player can load HLS through a worker, outside page fetch/XHR hooks.
    // Accept its declared HLS source only after a full-length video is known.
    if (content.some(v => Number.isFinite(v.duration) && v.duration >= 180) &&
        typeof window.jwplayer === 'function') {
      try {
        const item = window.jwplayer().getPlaylistItem();
        const sources = item.sources || [{file:item.file, type:item.type}];
        for (const source of sources) {
          const url = httpUrl(source.file);
          if (url && /^(hls|application\/(?:vnd\.apple\.mpegurl|x-mpegurl))$/i.test(source.type || '') &&
              !candidates.has(url) && candidates.size < 24) {
            candidates.set(url, {url, master:true, headers:{}});
          }
        }
      } catch (_) {}
    }
    // Preserve the multivariant playlist, including alternate audio renditions.
    const candidate = Array.from(candidates.values()).sort((a, b) => Number(b.master) - Number(a.master))[0];
    if (candidate && !emitted.has(candidate.url)) {
      emitted.add(candidate.url);
      try {
        TvMediaBridge.postMessage(JSON.stringify({
          event: 'hls', url: candidate.url, referer: location.href, headers: candidate.headers
        }));
      } catch (_) {}
    }
    for (const video of content) {
      if (window.__cineyAutoPlay) window.__cineyAutoPlay(video, false);
    }
  }
  const interval = setInterval(poll, 500);
  window.addEventListener('pagehide', () => {
    stopped = true;
    clearInterval(interval);
    candidates.clear();
  }, { once: true });
})();
