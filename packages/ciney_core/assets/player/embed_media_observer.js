(function () {
  'use strict';
  // The local wrapper has its own bridge. Observe provider documents in-place.
  if (window === window.top || window.__cineyMediaObserver) return;
  window.__cineyMediaObserver = true;
  if (window.__cineyStartPlayback) window.__cineyStartPlayback(document);
  const frameId = Math.random().toString(36).slice(2);
  const identities = new WeakMap();
  let sequence = 0;

  function poll(command) {
    if (command && command.pause === true && window.__cineyCancelStartup) window.__cineyCancelStartup();
    if (window.__cineyStartPlayback) window.__cineyStartPlayback(document);
    // Short clips in advertising frames must not finish the episode.
    const videos = Array.from(document.querySelectorAll('video'))
      .filter(v => v.readyState >= 2 && Number.isFinite(v.duration) && v.duration >= 180 &&
        (!window.__cineyIsContentMedia || window.__cineyIsContentMedia(v)));
    videos.sort((a, b) => b.duration - a.duration);
    const video = videos[0];
    if (!video || !Number.isFinite(video.currentTime) || video.error) return;
    const restoring = window.__cineyRestorePlayback ? window.__cineyRestorePlayback(video) : false;
    if (window.__cineyAutoPlay) window.__cineyAutoPlay(video, restoring);
    if (command && command.pause === true) video.pause();
    const source = video.currentSrc || video.src || '';
    let identity = identities.get(video);
    if (!identity || identity.source !== source) {
      identity = { id: frameId + ':' + (++sequence), source, played: false, ended: false };
      identities.set(video, identity);
    }
    if (!video.paused && video.currentTime > 0) identity.played = true;
    if (video.ended && !identity.played) return;
    const data = { event: 'media', mediaId: identity.id, readyState: video.readyState,
      current: video.currentTime, duration: video.duration, paused: video.paused,
      ended: video.ended === true && identity.played, restoring,
      requestId: command && typeof command.requestId === 'string' ? command.requestId : null };
    // Emit completion once, with the final position from the same video.
    if (data.ended && identity.ended && !data.requestId) return;
    identity.ended = data.ended;
    try { PlayerBridge.postMessage(JSON.stringify(data)); } catch (_) {}
  }

  const report = () => poll();
  const events = ['ended', 'timeupdate', 'pause', 'seeked', 'canplay'];
  for (const name of events) document.addEventListener(name, report, true);
  const disconnect = window.__cineyConnectProgress ? window.__cineyConnectProgress(poll) : () => {};
  const interval = setInterval(poll, 1000);
  window.addEventListener('pagehide', () => {
    clearInterval(interval);
    for (const name of events) document.removeEventListener(name, report, true);
    disconnect();
  }, { once: true });
})();
