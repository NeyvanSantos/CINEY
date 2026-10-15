(function () {
  'use strict';
  const target = Number(window.__cineyResumePositionSeconds) || 0;
  const expectedDuration = Number(window.__cineyExpectedDurationSeconds) || 0;
  let restored = target <= 0;
  let lastAttempt = null;

  // Keep an advertising clip from replacing a saved feature film's progress.
  window.__cineyIsContentMedia = function (video) {
    return expectedDuration <= 0 || video.duration >= Math.max(180, expectedDuration * 0.5);
  };

  // Wait for a seekable range and confirm the seek, then leave user seeks alone.
  window.__cineyRestorePlayback = function (video) {
    if (restored) return false;
    if (video.readyState < 2 || !Number.isFinite(video.duration) || video.duration < 180) return true;
    if (target >= video.duration) { restored = true; return false; }
    if (lastAttempt !== null && !video.seeking && Math.abs(video.currentTime - target) <= 1) {
      restored = true;
      return false;
    }
    const ranges = video.seekable;
    if (ranges) {
      let available = false;
      for (let index = 0; index < ranges.length; index++) {
        if (ranges.start(index) <= target && ranges.end(index) >= target) available = true;
      }
      if (!available) return true;
    }
    const now = Date.now();
    if (lastAttempt !== null && now - lastAttempt < 2000) return true;
    lastAttempt = now;
    try {
      video.currentTime = target;
      if (!video.seeking && Math.abs(video.currentTime - target) <= 1) restored = true;
    } catch (_) { /* Metadata or adaptive seek range may not be ready yet. */ }
    return !restored;
  };

  window.__cineyConnectProgress = function (poll) {
    function request(command) {
      poll(command);
      for (const frame of document.querySelectorAll('iframe')) {
        try { frame.contentWindow.postMessage(command, '*'); } catch (_) {}
      }
    }
    function receive(event) {
      if (event.source !== window.parent || !event.data ||
          event.data.event !== 'ciney:progress' || typeof event.data.requestId !== 'string') return;
      request(event.data);
    }
    window.__cineyRequestProgress = request;
    window.addEventListener('message', receive);
    return () => window.removeEventListener('message', receive);
  };
})();
