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
  let mediaSequence = 0;
  let mediaSource = null;
  let mediaId = null;
  let hasPlayed = false;
  let suppressAutoplay = false;

  function findVideo(doc, depth) {
    const candidates = Array.from(doc.querySelectorAll('video'));
    const result = candidates.find(v => !v.paused && v.readyState >= 2) ||
      candidates.find(v => v.readyState >= 2) || candidates[0];
    if (result) return result;
    if (window.__cineyNativeFrameObserver) {
      opaque = doc.querySelectorAll('iframe').length > 0;
      return null;
    }
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

  function poll(command) {
    if (command && command.pause === true) suppressAutoplay = true;
    opaque = false;
    video = findVideo(document, 0);
    if (reportedOpaque !== opaque) {
      reportedOpaque = opaque;
      post({ event: 'frame', opaque });
    }
    if (!video) return;
    if (window.__cineyIsContentMedia && !window.__cineyIsContentMedia(video)) return;
    const restoring = window.__cineyRestorePlayback ? window.__cineyRestorePlayback(video) : false;
    if (command && command.pause === true) video.pause();
    const source = video.currentSrc || video.src || '';
    if (attemptedVideo !== video || mediaSource !== source) {
      mediaSource = source;
      mediaId = 'parent:' + (++mediaSequence);
      hasPlayed = false;
    }
    if (!video.paused && video.currentTime > 0) hasPlayed = true;
    // Preserve the provider's choice of native or custom video controls.
    video.playsInline = true;
    if (video.error) {
      if (reportedError !== video.error) {
        reportedError = video.error;
        post({ event: 'error', code: video.error.code });
      }
      return;
    }
    if (!suppressAutoplay && !video.ended && video.readyState >= 2 && attemptedVideo !== video) {
      attemptedVideo = video;
      play();
    }
    post({ event: 'media', mediaId, readyState: video.readyState,
      current: Number.isFinite(video.currentTime) ? video.currentTime : 0,
      duration: Number.isFinite(video.duration) ? video.duration : 0,
      paused: video.paused, ended: video.ended === true && hasPlayed, restoring,
      requestId: command && typeof command.requestId === 'string' ? command.requestId : null });
  }

  const report = () => poll();
  const events = ['pause', 'seeked', 'timeupdate'];
  for (const name of events) document.addEventListener(name, report, true);
  const disconnect = window.__cineyConnectProgress ? window.__cineyConnectProgress(poll) : () => {};
  poll();
  const interval = setInterval(poll, 1000);
  window.addEventListener('pagehide', () => {
    clearInterval(interval);
    for (const name of events) document.removeEventListener(name, report, true);
    disconnect();
  }, { once: true });
})();
