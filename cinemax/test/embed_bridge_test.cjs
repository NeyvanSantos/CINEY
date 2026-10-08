const { test } = require('node:test');
const assert = require('node:assert/strict');
const vm = require('node:vm');
const fs = require('node:fs');
const path = require('node:path');
const code = fs.readFileSync(path.join(__dirname, '../assets/player/embed_bridge.js'), 'utf8');
const resumeScript = fs.readFileSync(path.join(__dirname, '../assets/player/playback_resume.js'), 'utf8');

function setup({ videos = [], frames = [], nativeObserver = false, resume = 0 } = {}) {
  const messages = [], timers = [], intervals = [], listeners = {};
  const document = {
    baseURI: 'https://provider.test/player',
    querySelectorAll: selector => selector === 'video' ? videos : frames,
    addEventListener: (name, callback) => { listeners[name] = callback; },
    removeEventListener: name => { delete listeners[name]; },
  };
  const context = vm.createContext({ document, URL,
    __cineyNativeFrameObserver: nativeObserver,
    __cineyResumePositionSeconds: resume,
    location: { origin: 'https://provider.test' },
    PlayerBridge: { postMessage: message => messages.push(JSON.parse(message)) },
    setInterval: (callback, interval) => {
      timers.push(callback);
      intervals.push(interval);
      return timers.length;
    },
    clearInterval: () => {},
  });
  context.window = context;
  context.addEventListener = () => {};
  context.removeEventListener = () => {};
  vm.runInContext(resumeScript, context);
  vm.runInContext(code, context);
  return { context, messages, timers, intervals, listeners };
}

test('bridge válido, idempotente e não anuncia vídeo para página vazia', () => {
  const fixture = setup();
  vm.runInContext(code, fixture.context);
  assert.equal(fixture.timers.length, 1);
  assert.deepEqual(fixture.intervals, [1000]);
  assert.deepEqual(fixture.messages, [{ event: 'frame', opaque: false }]);
});

test('usa controles do fornecedor e sinaliza mídia carregada e erro uma vez', () => {
  let plays = 0;
  const video = { controls: false, readyState: 4, currentTime: 2, duration: 120, paused: false,
    play: () => { plays++; return Promise.resolve(); }, pause() {} };
  const fixture = setup({ videos: [video] });
  assert.equal(video.controls, false);
  assert.equal(plays, 1);
  assert.equal(fixture.messages.at(-1).readyState, 4);
  fixture.timers[0]();
  assert.equal(plays, 1);
  video.error = { code: 3 };
  fixture.timers[0]();
  fixture.timers[0]();
  assert.equal(fixture.messages.filter(m => m.event === 'error').length, 1);
});

test('preserva iframe externo e informa que não pode inspecioná-lo', () => {
  const frame = { contentDocument: null };
  const fixture = setup({ frames: [frame] });
  assert.deepEqual(fixture.messages, [{ event: 'frame', opaque: true }]);
});

test('autoplay bloqueado pede interação sem simular reprodução', async () => {
  const video = { readyState: 2, currentTime: 0, duration: Infinity, paused: true,
    play: () => Promise.reject(new Error('gesture required')) };
  const fixture = setup({ videos: [video] });
  await Promise.resolve();
  assert.equal(fixture.messages.at(-1).event, 'interaction');
  assert.equal(fixture.messages.find(m => m.event === 'media').paused, true);
  assert.equal(fixture.messages.find(m => m.event === 'media').duration, 0);
});

test('permite links internos do fornecedor e bloqueia anúncio externo', () => {
  const fixture = setup();
  let prevented = 0;
  function click(href) {
    fixture.listeners.click({ target: { closest: () => ({ href }) },
      preventDefault: () => prevented++, stopImmediatePropagation() {} });
  }
  click('https://provider.test/episode');
  assert.equal(prevented, 0);
  click('https://advertiser.test/popunder');
  assert.equal(prevented, 1);
});

test('sinaliza fim real sem tentar reproduzir o vídeo terminado novamente', () => {
  let plays = 0;
  const video = { readyState: 4, currentTime: 10, duration: 1200, paused: false,
    ended: false, play: () => { plays++; return Promise.resolve(); } };
  const fixture = setup({ videos: [video] });
  const identity = fixture.messages.at(-1).mediaId;
  video.currentTime = 1200;
  video.paused = true;
  video.ended = true;
  fixture.timers[0]();
  assert.equal(fixture.messages.at(-1).ended, true);
  assert.equal(fixture.messages.at(-1).mediaId, identity);
  assert.equal(plays, 1);
});

test('observação nativa evita sinais duplicados do mesmo vídeo nos frames', () => {
  const frame = {};
  Object.defineProperty(frame, 'contentDocument', { get() {
    throw new Error('o pai não deve inspecionar frames observados nativamente');
  } });
  const fixture = setup({ frames: [frame], nativeObserver: true });
  assert.deepEqual(fixture.messages, [{ event: 'frame', opaque: true }]);
});

test('ponte do documento pai retoma e consulta a posição real ao pausar', () => {
  const video = { readyState: 4, duration: 7200, currentTime: 0, paused: false,
    play: () => Promise.resolve(), pause() { this.paused = true; } };
  const fixture = setup({ videos: [video], resume: 1200.456 });
  assert.equal(video.currentTime, 1200.456);
  video.currentTime = 1500.789;
  fixture.context.__cineyRequestProgress({ event: 'ciney:progress', requestId: 'exit', pause: true });
  assert.equal(fixture.messages.at(-1).current, 1500.789);
  assert.equal(fixture.messages.at(-1).requestId, 'exit');
  assert.equal(video.paused, true);
});
