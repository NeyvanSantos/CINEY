(function () {
    'use strict';
    if (window.__castLiteMediaObserver || !window.CastLiteMedia) return;

    var bridge = window.CastLiteMedia;
    var pageId = null;
    var reported = new Set();
    var timer;
    var observer;
    var active = true;

    function sources() {
        var found = new Map();
        function add(value, type) {
            if (typeof value !== 'string' || !value.trim()) return;
            try {
                var url = new URL(value, document.baseURI);
                if (!/^https?:$/.test(url.protocol) || url.username || url.password) return;
                // Keep signed absolute URLs byte-for-byte; only resolve relative sources.
                var original = /^https?:\/\//i.test(value) ? value : url.href;
                var declared = typeof type === 'string' ? type : '';
                found.set(original + '\n' + declared, { url: original, type: declared });
            } catch (_) {}
        }
        document.querySelectorAll('video, source').forEach(function (element) {
            var type = element.getAttribute('type') || '';
            add(element.currentSrc, type);
            add(element.src, type);
        });
        if (typeof window.jwplayer === 'function') {
            var players = new Set();
            try { players.add(window.jwplayer()); } catch (_) {}
            document.querySelectorAll('.jwplayer[id]').forEach(function (element) {
                try { players.add(window.jwplayer(element.id)); } catch (_) {}
            });
            players.forEach(function (player) {
                try {
                    (player.getPlaylist() || []).forEach(function (item) {
                        add(item.file, item.type);
                        (item.sources || []).forEach(function (source) {
                            add(source.file || source.src, source.type || item.type);
                        });
                    });
                } catch (_) {}
            });
        }
        return Array.from(found.values()).slice(0, 64);
    }

    function scan() {
        if (!active || pageId === null || document.hidden) return;
        var fresh = sources().filter(function (source) {
            return !reported.has(source.url + '\n' + source.type);
        });
        if (!fresh.length) return;
        try {
            bridge.postMessage(JSON.stringify({
                kind: 'media', pageId: pageId, pageUrl: location.href, sources: fresh
            }));
            fresh.forEach(function (source) { reported.add(source.url + '\n' + source.type); });
        } catch (_) {}
    }

    function refresh() {
        if (!active) return;
        pageId = null;
        reported.clear();
        bridge.postMessage(JSON.stringify({ kind: 'ready' }));
        document.querySelectorAll('iframe, frame').forEach(function (frame) {
            try { frame.contentWindow.postMessage('CastLiteMediaRefresh', '*'); } catch (_) {}
        });
    }

    var fetchControllers = Object.create(null);

    async function fetchMedia(request) {
        var controller = new AbortController();
        fetchControllers[request.id] = controller;
        var timeout;
        function resetTimeout() {
            clearTimeout(timeout);
            timeout = setTimeout(function () { controller.abort(); }, 40000);
        }
        resetTimeout();
        function send(kind, extra) {
            bridge.postMessage(JSON.stringify(Object.assign({ kind: kind, id: request.id, pageId: request.pageId }, extra)));
        }
        try {
            if (request.pageId !== pageId) throw new Error('Navigation changed');
            var url = new URL(request.url);
            if (!/^https?:$/.test(url.protocol) || url.username || url.password) throw new Error('Unsupported URL');
            var response = await fetch(url.href, {
                signal: controller.signal,
                credentials: request.credentials === 'include' ? 'include' : 'same-origin',
                headers: request.range ? { Range: request.range } : {}
            });
            send('fetchStart', { status: response.status, type: response.headers.get('content-type') || '',
                url: response.url, contentRange: response.headers.get('content-range') || '' });
            var reader = response.body.getReader();
            var total = 0;
            while (true) {
                var part = await reader.read();
                if (part.done) break;
                resetTimeout();
                total += part.value.length;
                if (total > 128 * 1024 * 1024) { controller.abort(); throw new Error('Resource too large'); }
                for (var offset = 0; offset < part.value.length; offset += 24000) {
                    var chunk = part.value.subarray(offset, offset + 24000);
                    send('fetchChunk', { data: btoa(String.fromCharCode.apply(null, chunk)) });
                }
            }
            send('fetchEnd');
        } catch (_) { send('fetchError'); }
        finally { clearTimeout(timeout); delete fetchControllers[request.id]; }
    }

    bridge.onmessage = function (event) {
        if (typeof event.data === 'string' && event.data.charAt(0) === '{') {
            try {
                var request = JSON.parse(event.data);
                if (active && request.kind === 'pauseLocal') {
                    document.querySelectorAll('video,audio').forEach(function (media) {
                        media.pause();
                        media.preload = 'none';
                    });
                }
                if (request.kind === 'cancelFetch') {
                    if (fetchControllers[request.id]) fetchControllers[request.id].abort();
                } else if (active && request.kind === 'fetch') fetchMedia(request);
            } catch (_) {}
            return;
        }
        var value = Number(event.data);
        if (!active || !Number.isSafeInteger(value) || value < 0) return;
        pageId = value;
        scan();
    };
    window.addEventListener('message', function (event) {
        if (window.parent !== window && event.source === window.parent &&
            event.data === 'CastLiteMediaRefresh'
        ) refresh();
    });
    function observe() {
        if (!document.documentElement || observer) return;
        observer = new MutationObserver(scan);
        observer.observe(document.documentElement, {
            childList: true, subtree: true, attributes: true, attributeFilter: ['src', 'type']
        });
        scan();
    }
    document.addEventListener('DOMContentLoaded', observe);
    ['loadedmetadata', 'play', 'visibilitychange'].forEach(function (event) {
        document.addEventListener(event, scan, true);
    });
    window.addEventListener('pagehide', function () {
        active = false;
        clearInterval(timer);
        if (observer) observer.disconnect();
    });
    window.addEventListener('pageshow', function () {
        if (active) return;
        active = true;
        observer = null;
        observe();
        timer = setInterval(scan, 1500);
        refresh();
    });
    window.__castLiteMediaObserver = { refresh: refresh, sources: sources };
    observe();
    timer = setInterval(scan, 1500);
    refresh();
})();
