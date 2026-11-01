const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const script = fs.readFileSync(path.join(__dirname, '../../main/assets/media_observer.js'), 'utf8');

test('browser credentials are included only when explicitly requested by native transport', async () => {
    for (const mode of ['include', undefined]) {
        let options;
        const page = frame({ fetch: async (url, request) => {
            options = request;
            return { status: 200, url, headers: new Map(),
                body: { getReader: () => ({ read: async () => ({ done: true }) }) } };
        } });
        page.bridge.onmessage({ data: JSON.stringify({ kind: 'fetch', id: 'cookies', pageId: 1,
            url: 'https://cdn.example/segment', credentials: mode }) });
        await new Promise(setImmediate);
        assert.equal(options.credentials, mode === 'include' ? 'include' : 'same-origin');
    }
});

function frame({ playlist = [], elements = [], href = 'https://player.example/video/123', fetch: fetchImpl } = {}) {
    const messages = [];
    const events = new Map();
    const intervals = new Map();
    let epoch = 1;
    let intervalId = 0;
    const children = [];
    const document = {
        baseURI: href, documentElement: {}, hidden: false,
        querySelectorAll(selector) {
            if (selector === 'video, source') return elements;
            if (selector === 'iframe, frame') return children;
            return [];
        },
        addEventListener(name, callback) { events.set('document:' + name, callback); }
    };
    const bridge = {
        postMessage(text) {
            const data = JSON.parse(text);
            messages.push(data);
            if (data.kind === 'ready') bridge.onmessage({ data: String(epoch) });
        }
    };
    const window = {
        CastLiteMedia: bridge, parent: {}, jwplayer: () => ({ getPlaylist: () => playlist }),
        addEventListener(name, callback) { events.set(name, callback); }
    };
    const context = {
        window, document, location: { href }, URL,
        fetch: fetchImpl, AbortController, setTimeout, clearTimeout,
        btoa: value => Buffer.from(value, 'binary').toString('base64'),
        MutationObserver: class { observe() {} disconnect() {} },
        setInterval(callback) { intervals.set(++intervalId, callback); return intervalId; },
        clearInterval(id) { intervals.delete(id); }
    };
    vm.runInNewContext(script, context);
    return {
        window, bridge, document, children, messages, intervals,
        media: () => messages.filter(message => message.kind === 'media'),
        poll: () => [...intervals.values()].forEach(callback => callback()),
        event: (name, event = {}) => events.get(name)?.(event),
        epoch: value => { epoch = value; }
    };
}

test('finds the HLS master.txt declared inside a frame with a blob video', () => {
    const url = 'https://player.example/signed/master.txt?token=Ab%2BC&signature=X%2fY';
    const page = frame({
        playlist: [{ sources: [{ file: url, type: 'hls' }] }],
        elements: [{ currentSrc: 'blob:https://player.example/id', src: '', getAttribute: () => '' }]
    });
    const [message] = page.media();
    assert.equal(message.pageUrl, 'https://player.example/video/123');
    assert.equal(message.pageId, 1);
    assert.deepEqual(message.sources, [{ url, type: 'hls' }]);
    page.poll();
    assert.equal(page.media().length, 1);
});

test('browser transport preserves signed URLs, bytes and range response metadata', async () => {
    const bytes = Uint8Array.from({ length: 55000 }, (_, index) => index % 256);
    let requested;
    const url = 'https://player.example/md/token?sig=a%2Fb+C';
    const page = frame({ fetch: async (target, options) => {
        requested = { target, options };
        let sent = false;
        return { status: 206, url: target,
            headers: new Map([['content-type', 'video/mp2t'], ['content-range', 'bytes 0-54999/100000']]),
            body: { getReader: () => ({ read: async () => sent ? { done: true } : (sent = true, { value: bytes }) }) }
        };
    } });
    page.bridge.onmessage({ data: JSON.stringify({ kind: 'fetch', id: 'request', pageId: 1, url, range: 'bytes=0-54999' }) });
    await new Promise(setImmediate);
    const messages = page.messages.filter(message => message.kind.startsWith('fetch'));
    assert.equal(requested.target, url);
    assert.equal(requested.options.headers.Range, 'bytes=0-54999');
    assert.equal(messages[0].contentRange, 'bytes 0-54999/100000');
    assert.equal(messages[0].status, 206);
    const chunks = messages.filter(message => message.kind === 'fetchChunk');
    assert.equal(chunks.length, 3);
    assert.deepEqual(Buffer.concat(chunks.map(message => Buffer.from(message.data, 'base64'))), Buffer.from(bytes));
    assert.equal(messages.at(-1).kind, 'fetchEnd');
});

test('browser transport rejects stale navigation and unsafe URL schemes before fetching', async () => {
    let calls = 0;
    const page = frame({ fetch: async () => { calls++; throw new Error('Unexpected request'); } });
    for (const request of [
        { pageId: 0, url: 'https://player.example/master' },
        { pageId: 1, url: 'file:///secret' },
        { pageId: 1, url: 'https://user:secret@player.example/master' }
    ]) page.bridge.onmessage({ data: JSON.stringify({ kind: 'fetch', id: 'request', ...request }) });
    await new Promise(setImmediate);
    assert.equal(calls, 0);
    assert.equal(page.messages.filter(message => message.kind === 'fetchError').length, 3);
});

test('browser transport aborts oversized resources', async () => {
    let signal;
    const page = frame({ fetch: async (url, options) => {
        signal = options.signal;
        return { status: 200, url, headers: new Map(),
            body: { getReader: () => ({ read: async () => ({ value: new Uint8Array(128 * 1024 * 1024 + 1) }) }) } };
    } });
    page.bridge.onmessage({ data: JSON.stringify({ kind: 'fetch', id: 'large', pageId: 1, url: 'https://player.example/md/segment' }) });
    await new Promise(setImmediate);
    assert.equal(signal.aborted, true);
    assert.equal(page.messages.at(-1).kind, 'fetchError');
    assert.equal(page.messages.filter(message => message.kind === 'fetchChunk').length, 0);
});

test('finds a player initialized after document loading and resolves relative URLs', () => {
    const playlist = [];
    const page = frame({ playlist });
    assert.equal(page.media().length, 0);
    playlist.push({ type: 'dash', sources: [{ file: '/md/token' }] });
    page.poll();
    assert.deepEqual(page.media()[0].sources, [{ url: 'https://player.example/md/token', type: 'dash' }]);
});

test('does not expose blob, credential URLs or non HTTP schemes as media', () => {
    const page = frame({ playlist: [{ sources: [
        { file: 'blob:https://player.example/video', type: 'hls' },
        { file: 'https://user:password@player.example/master.txt', type: 'hls' },
        { file: 'javascript:alert(1)', type: 'mp4' },
        { file: 'file:///video.mp4' }
    ] }] });
    assert.equal(page.media().length, 0);
});

test('refresh tags new observations with the current navigation and reaches child frames', () => {
    const page = frame({ playlist: [{ sources: [{ file: '/master.txt', type: 'hls' }] }] });
    const childMessages = [];
    page.children.push({ contentWindow: { postMessage: message => childMessages.push(message) } });
    page.epoch(2);
    page.window.__castLiteMediaObserver.refresh();
    assert.equal(page.media()[1].pageId, 2);
    assert.deepEqual(childMessages, ['CastLiteMediaRefresh']);
    const before = page.media().length;
    page.event('message', { source: {}, data: 'CastLiteMediaRefresh' });
    assert.equal(page.media().length, before);
    page.event('message', { source: page.window.parent, data: 'CastLiteMediaRefresh' });
    assert.equal(page.media().length, before + 1);
});

test('stops polling after leaving the frame and restores observation on pageshow', () => {
    const page = frame();
    assert.equal(page.intervals.size, 1);
    page.event('pagehide');
    assert.equal(page.intervals.size, 0);
    const count = page.messages.length;
    page.window.__castLiteMediaObserver.refresh();
    assert.equal(page.messages.length, count);
    page.event('pageshow');
    assert.equal(page.intervals.size, 1);
});

test('bounds a frame report and ignores invalid navigation acknowledgements', () => {
    const sources = Array.from({ length: 100 }, (_, i) => ({ file: '/video-' + i + '.mp4' }));
    const page = frame({ playlist: [{ sources }] });
    assert.equal(page.media()[0].sources.length, 64);
    const before = page.messages.length;
    page.bridge.onmessage({ data: '-1' });
    page.bridge.onmessage({ data: 'NaN' });
    assert.equal(page.messages.length, before);
});


test('streams the first browser chunk before the segment finishes and accepts cancellation', async () => {
    let finishRead;
    let signal;
    let reads = 0;
    const page = frame({ fetch: async (url, options) => {
        signal = options.signal;
        return { status: 200, url, headers: new Map([['content-type', 'video/mp2t']]),
            body: { getReader: () => ({ read: async () => {
                if (reads++ === 0) return { value: Uint8Array.of(1, 2, 3) };
                return new Promise(resolve => { finishRead = resolve; });
            } }) } };
    } });
    page.bridge.onmessage({ data: JSON.stringify({ kind: 'fetch', id: 'stream', pageId: 1, url: 'https://player.example/segment' }) });
    await new Promise(setImmediate);
    assert.equal(page.messages.filter(message => message.kind === 'fetchChunk').length, 1);
    assert.equal(page.messages.filter(message => message.kind === 'fetchEnd').length, 0);
    page.bridge.onmessage({ data: JSON.stringify({ kind: 'cancelFetch', id: 'stream' }) });
    assert.equal(signal.aborted, true);
    finishRead({ done: true });
    await new Promise(setImmediate);
});

test('accepts high quality segments above sixteen megabytes without changing bytes', async () => {
    let reads = 0;
    const block = new Uint8Array(1024 * 1024).fill(71);
    const page = frame({ fetch: async url => ({ status: 200, url, headers: new Map(),
        body: { getReader: () => ({ read: async () => reads++ < 17 ? { value: block } : { done: true } }) } }) });
    page.bridge.onmessage({ data: JSON.stringify({ kind: 'fetch', id: 'quality', pageId: 1, url: 'https://player.example/segment' }) });
    await new Promise(setImmediate);
    assert.equal(page.messages.at(-1).kind, 'fetchEnd');
    const chunks = page.messages.filter(message => message.kind === 'fetchChunk');
    assert.equal(chunks.reduce((count, chunk) => count + Buffer.from(chunk.data, 'base64').length, 0), 17 * 1024 * 1024);
    assert.ok(chunks.every(chunk => Buffer.from(chunk.data, 'base64').every(byte => byte === 71)));
});
