const test = require('node:test');
const assert = require('node:assert/strict');
const vm = require('node:vm');
const fs = require('node:fs');
const path = require('node:path');
const script = fs.readFileSync(path.join(__dirname,
  '../../packages/ciney_core/assets/player/tv_hls_observer.js'), 'utf8');

function setup(videos = [{ duration: NaN, currentSrc: 'blob:media' }], page = {}) {
  const messages = [], timers = [], events = {};
  let response;
  class Xhr {
    open() {} setRequestHeader() {} send() {}
    addEventListener(name, fn) { this.loaded = fn; }
  }
  const context = vm.createContext({
    URL, Headers, TextDecoder, Uint8Array, XMLHttpRequest: Xhr,
    location: { href: 'https://provider.test/player/1', ...page },
    document: { querySelectorAll: () => videos },
    TvMediaBridge: { postMessage: message => messages.push(JSON.parse(message)) },
    fetch: async () => response,
    setInterval: callback => { timers.push(callback); return 1; },
    clearInterval: () => {},
    addEventListener: (name, fn) => { events[name] = fn; },
  });
  context.window = context;
  context.top = {};
  vm.runInContext(script, context);
  return {
    messages, timers, events, context,
    binary(url, text) {
      const xhr = new context.XMLHttpRequest();
      xhr.open('GET', url); xhr.responseURL = url;
      xhr.responseType = 'arraybuffer';
      xhr.response = new TextEncoder().encode(text).buffer;
      xhr.send(); xhr.loaded();
    },
    async load(url, text, type = 'application/vnd.apple.mpegurl') {
      response = { url, headers: new Headers({ 'content-type': type }),
        clone: () => new Response(text) };
      await context.fetch(url, { headers: { 'X-Session': 'test' } });
      await Promise.resolve();
      await new Promise(resolve => setImmediate(resolve));
    },
  };
}
const master = '#EXTM3U\n#EXT-X-STREAM-INF:BANDWIDTH=1000000,AUDIO="pt"\n720.m3u8';
const vod = duration => `#EXTM3U\n#EXT-X-TARGETDURATION:10\n#EXTINF:${duration},\nseg.ts\n#EXT-X-ENDLIST`;

test('keeps master instead of last child playlist and emits once', async () => {
  const f = setup();
  await f.load('https://cdn.test/master?token=test', master);
  await f.load('https://cdn.test/720.m3u8', vod(600));
  f.timers[0](); f.timers[0]();
  assert.equal(f.messages.length, 1);
  assert.equal(f.messages[0].url, 'https://cdn.test/master?token=test');
  assert.equal(f.messages[0].headers['x-session'], 'test');
  assert.equal(f.messages[0].referer, 'https://provider.test/player/1');
});
test('does not promote HTML errors, short ads, blobs or frames without videos', async () => {
  const f = setup();
  await f.load('https://cdn.test/error.m3u8', '<html>Denied</html>');
  await f.load('https://cdn.test/ad.m3u8', vod(30));
  await f.load('blob:https://cdn.test/1', master);
  f.timers[0]();
  assert.equal(f.messages.length, 0);
  const noVideo = setup([]);
  await noVideo.load('https://cdn.test/master.m3u8', master);
  noVideo.timers[0]();
  assert.equal(noVideo.messages.length, 0);
});
test('supports direct video HLS and stops reporting after pagehide', async () => {
  const f = setup([{ duration: 600, currentSrc: 'https://cdn.test/film.m3u8' }]);
  f.timers[0]();
  assert.equal(f.messages[0].url, 'https://cdn.test/film.m3u8');
  f.events.pagehide();
  await f.load('https://cdn.test/next.m3u8', master);
  f.timers[0]();
  assert.equal(f.messages.length, 1);
});

 test('playing content stops menu scans and announces playback once', () => {
  const f = setup([{ duration: 600, paused: false, ended: false, currentSrc: 'blob:film' }]);
  f.timers[0](); f.timers[0]();
  assert.equal(f.messages.length, 1);
  assert.equal(f.messages[0].action, 'playing');
 });

test('binary XHR master.txt preserves HLS and rejects binary segments', () => {
  const f = setup();
  f.binary('https://cdn.test/segment', 'not a manifest');
  f.timers[0](); assert.equal(f.messages.length, 0);
  f.binary('https://cdn.test/master.txt', master);
  f.timers[0]();
  assert.equal(f.messages[0].url, 'https://cdn.test/master.txt');
});

test('challenge frames receive no media hooks or polling', () => {
  const f = setup([], { hostname: 'challenges.cloudflare.com' });
  assert.equal(f.timers.length, 0);
  assert.equal(f.context.__cineyTvHlsObserver, undefined);
});

test('JW declared HLS master.txt is detected when network runs in a worker', () => {
  const f = setup([{duration:600, currentSrc:'blob:film'}]);
  f.context.jwplayer = () => ({getPlaylistItem: () => ({sources:[
    {file:'https://cdn.test/master.txt',type:'hls'}
  ]})});
  f.timers[0]();
  assert.equal(f.messages[0].url, 'https://cdn.test/master.txt');
  const short = setup([{duration:30,currentSrc:'blob:ad'}]);
  short.context.jwplayer = f.context.jwplayer;
  short.timers[0](); assert.equal(short.messages.length,0);
});
