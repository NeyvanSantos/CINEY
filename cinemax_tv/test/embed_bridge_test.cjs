const { test } = require('node:test');
const assert = require('node:assert/strict');
const vm = require('node:vm');
const fs = require('node:fs');
const path = require('node:path');
const code = fs.readFileSync(path.join(__dirname, '../assets/player/embed_bridge.js'), 'utf8');

function setup({ videos = [], frames = [] } = {}) {
  const messages = [], timers = [], listeners = {};
  const document = {
    baseURI: 'https://provider.test/player',
    querySelectorAll: selector => selector === 'video' ? videos : frames,
    addEventListener: (name, callback) => { listeners[name] = callback; },
  };
  const context = vm.createContext({ document, URL,
    location: { origin: 'https://provider.test' },
    PlayerBridge: { postMessage: message => messages.push(JSON.parse(message)) },
    setInterval: callback => { timers.push(callback); return timers.length; },
    clearInterval: () => {},
  });
  context.window = context;
  context.addEventListener = () => {};
  vm.runInContext(code, context);
  return { context, messages, timers, listeners };
}

test('bridge válido, idempotente e não anuncia vídeo para página vazia', () => {
  const fixture = setup();
  vm.runInContext(code, fixture.context);
  assert.equal(fixture.timers.length, 1);
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
