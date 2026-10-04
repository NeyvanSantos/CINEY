(function () {
  'use strict';
  if (window.__cinemaxBridge) return;
  window.__cinemaxBridge = true;

  function post(data) {
    PlayerBridge.postMessage(JSON.stringify(data));
  }

  // Block new windows without removing legitimate video elements or frames.
  window.open = function () { return null; };
  document.addEventListener('click', function (event) {
    const anchor = event.target.closest && event.target.closest('a');
    if (!anchor) return;
    try {
      const url = new URL(anchor.href, document.baseURI);
      if (!['http:', 'https:', 'javascript:'].includes(url.protocol) ||
          (url.protocol !== 'javascript:' && url.origin !== location.origin)) {
        event.preventDefault();
        event.stopImmediatePropagation();
      }
    } catch (_) { /* Let WebView validate malformed destinations. */ }
  }, true);

  let video = null;
  let opaque = false;
  let reportedOpaque = null;
  let reportedError = null;
  let attemptedVideo = null;

  function findVideo(doc, depth) {
    const candidates = Array.from(doc.querySelectorAll('video'));
    const result = candidates.find(v => !v.paused && v.readyState >= 2) ||
      candidates.find(v => v.readyState >= 2) || candidates[0];
    if (result) return result;
    if (depth >= 5) return null;
    for (const frame of doc.querySelectorAll('iframe')) {
      try {
        const child = frame.contentDocument;
        if (!child) { opaque = true; continue; }
        const found = findVideo(child, depth + 1);
        if (found) return found;
      } catch (_) { opaque = true; }
    }
    return null;
  }

  function play() {
    if (!video) { post({ event: 'interaction' }); return; }
    try {
      const pending = video.play();
      if (pending && pending.catch) {
        pending.catch(() => post({ event: 'interaction' }));
      }
    } catch (_) { post({ event: 'interaction' }); }
  }

  function poll() {
    opaque = false;
    video = findVideo(document, 0);
    if (reportedOpaque !== opaque) {
      reportedOpaque = opaque;
      post({ event: 'frame', opaque });
    }
    if (!video) return;
    // Preserve the provider's choice of native or custom video controls.
    video.playsInline = true;
    if (video.error) {
      if (reportedError !== video.error) {
        reportedError = video.error;
        post({ event: 'error', code: video.error.code });
      }
      return;
    }
    if (video.readyState >= 2 && attemptedVideo !== video) {
      attemptedVideo = video;
      play();
    }
    post({ event: 'media', readyState: video.readyState,
      current: Number.isFinite(video.currentTime) ? video.currentTime : 0,
      duration: Number.isFinite(video.duration) ? video.duration : 0,
      paused: video.paused });
  }

  poll();
  const interval = setInterval(poll, 500);
  window.addEventListener('pagehide', () => clearInterval(interval), { once: true });
})();
