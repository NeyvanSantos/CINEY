const test = require('node:test');
const assert = require('node:assert/strict');
const vm = require('node:vm');
const fs = require('node:fs');
const path = require('node:path');
const read = name => fs.readFileSync(path.join(__dirname, '../assets/player', name), 'utf8');
const startup = read('embed_startup.js');

function row(text, audio = 'pt-br', hidden = false) {
  return {
    textContent: text, audio, hidden, clicks: 0,
    getAttribute(name) { return name === 'data-audio' ? this.audio : null; },
    getClientRects() { return this.hidden ? [] : [{}]; },
    click() { this.clicks++; },
    contains(target) { return target === this; },
  };
}

function setup({ rows = [], controls = [], enabled = true, host = 'playerflix.ink',
  pathname = '/serie/1/1/1', saved = null, selector = null, resume = 300.123 } = {}) {
  const events = {}, windowEvents = {}, messages = [], timers = [], videos = [];
  const stored = new Map(saved ? [['ciney-player-selection-v1', JSON.stringify(saved)]] : []);
  let now = 0;
  const document = {
    readyState: 'complete', location: { hostname: host, pathname },
    querySelectorAll(query) {
      if (query === '#optionList .option[data-embed][data-audio]') return rows;
      if (query === 'video') return videos;
      if (query === 'iframe') return [];
      return controls;
    },
    querySelector: () => selector,
    addEventListener: (name, handler) => { events[name] = handler; },
    removeEventListener: name => { delete events[name]; },
  };
  const context = vm.createContext({ document, Date: { now: () => now },
    __cineyAutoStart: enabled, __cineyProviderHost: 'myembed.biz',
    __cineyProviderPath: '/serie/1/1/1', __cineyResumePositionSeconds: resume,
    getComputedStyle: element => ({ display: element.hidden ? 'none' : 'block', visibility: 'visible' }),
    localStorage: { getItem: key => stored.get(key) || null, setItem: (key, value) => stored.set(key, value) },
    Event: class { constructor(type) { this.type = type; } },
    addEventListener: (name, handler) => { windowEvents[name] = handler; },
    removeEventListener: name => { delete windowEvents[name]; },
    PlayerBridge: { postMessage: value => messages.push(JSON.parse(value)) },
    setInterval: callback => { timers.push(callback); return 1; }, clearInterval() {},
  });
  context.window = context;
  context.top = {};
  context.parent = {};
  document.defaultView = context;
  vm.runInContext(read('playback_resume.js'), context);
  vm.runInContext(startup, context);
  const start = () => context.__cineyStartPlayback(document);
  return { context, document, events, windowEvents, stored, messages, timers, videos,
    start, advance: milliseconds => { now += milliseconds; } };
}

test('retomada escolhe opção visível uma vez, sem trocar a aba de áudio atual', () => {
  const dubbed = row('Servidor Principal', 'pt-br', true);
  const subtitled = row('Legendado', 'en-us');
  const fixture = setup({ rows: [dubbed, subtitled] });
  fixture.start();
  fixture.start();
  assert.equal(dubbed.clicks, 0);
  assert.equal(subtitled.clicks, 1);
});

test('primeira reprodução ou retomada desligada mantém escolha manual', () => {
  const server = row('Servidor Principal');
  const fixture = setup({ rows: [server], enabled: false });
  fixture.start();
  assert.equal(server.clicks, 0);
});

test('aguarda criação assíncrona do menu sem clicar em links externos', () => {
  const telegram = row('Telegram');
  const rows = [];
  const fixture = setup({ rows, controls: [telegram] });
  fixture.start();
  assert.equal(telegram.clicks, 0);
  const server = row('Servidor Principal');
  rows.push(server);
  fixture.start();
  assert.equal(server.clicks, 1);
});

test('menu compacto reconhece abas e aciona apenas Servidor Principal', () => {
  const controls = ['Dublado', 'Legendado', 'Servidor Principal', 'Telegram', 'Copiar Link'].map(text => row(text, null));
  const fixture = setup({ controls });
  fixture.start();
  assert.deepEqual(controls.map(control => control.clicks), [0, 0, 1, 0, 0]);
});

test('recusa menu em anúncio, fornecedor desconhecido ou outro episódio', () => {
  for (const options of [{ host: 'ad.test' }, { pathname: '/serie/1/1/2' }, { pathname: '/verificacao' }]) {
    const server = row('Servidor Principal');
    const fixture = setup({ rows: [server], ...options });
    fixture.start();
    assert.equal(server.clicks, 0);
  }
});

test('seleção expira em 20 segundos e intervenção da pessoa cancela automação', () => {
  for (const action of [fixture => fixture.advance(20001),
    fixture => fixture.events.pointerdown({ isTrusted: true }),
    fixture => fixture.events.keydown({ isTrusted: true })]) {
    const rows = [];
    const fixture = setup({ rows });
    fixture.start();
    action(fixture);
    const server = row('Servidor Principal');
    rows.push(server);
    fixture.start();
    assert.equal(server.clicks, 0);
  }
});

test('guarda seleção manual e reutiliza servidor e áudio ao retomar', () => {
  const chosen = row('Legendado', 'en-us');
  const first = setup({ rows: [chosen], enabled: false });
  first.start();
  first.events.click({ isTrusted: true, target: chosen });
  const saved = JSON.parse(first.stored.get('ciney-player-selection-v1'));
  assert.deepEqual(saved, { label: 'Legendado', audio: 'en-us' });
  const dubbed = row('Servidor Principal');
  const subtitled = row('Legendado', 'en-us', true);
  const selector = { options: [{ value: 'pt-br' }, { value: 'en-us' }],
    dispatchEvent() { dubbed.hidden = true; subtitled.hidden = false; } };
  const second = setup({ rows: [dubbed, subtitled], selector, saved });
  second.start();
  assert.equal(selector.value, 'en-us');
  assert.equal(dubbed.clicks, 0);
  assert.equal(subtitled.clicks, 1);
});

test('seleção antiga indisponível usa opção atual e não grava cliques automáticos', () => {
  const server = row('Servidor Principal');
  const fixture = setup({ rows: [server], saved: { label: 'Antigo', audio: 'en-us' } });
  fixture.start();
  fixture.events.click({ isTrusted: false, target: server });
  assert.equal(server.clicks, 1);
  assert.equal(JSON.parse(fixture.stored.get('ciney-player-selection-v1')).label, 'Antigo');
});

test('seleção automática e retomada funcionam juntas no observador do iframe', () => {
  const server = row('Servidor Principal');
  const fixture = setup({ rows: [server] });
  server.click = function () {
    this.clicks++;
    fixture.videos.push({ ownerDocument: fixture.document, readyState: 4,
      duration: 1200, currentTime: 0, paused: true, ended: false, plays: 0,
      play() { this.plays++; this.paused = false; return Promise.resolve(); } });
  };
  vm.runInContext(read('embed_media_observer.js'), fixture.context);
  fixture.timers[0]();
  fixture.timers[0]();
  assert.equal(server.clicks, 1);
  assert.equal(fixture.videos[0].currentTime, 300.123);
  assert.equal(fixture.videos[0].plays, 1);
  assert.equal(fixture.messages.at(-1).restoring, false);
  assert.equal(fixture.messages.at(-1).paused, false);
});

test('aguarda confirmação do seek antes de reproduzir e respeita pausa posterior', () => {
  const fixture = setup();
  const video = { readyState: 4, duration: 1200, currentTime: 300.123,
    paused: true, ended: false, plays: 0,
    play() { this.plays++; this.paused = false; } };
  fixture.context.__cineyAutoPlay(video, true);
  assert.equal(video.plays, 0);
  fixture.context.__cineyAutoPlay(video, false);
  assert.equal(video.plays, 1);
  video.paused = true;
  fixture.context.__cineyAutoPlay(video, false);
  assert.equal(video.plays, 1);
});

test('ponte sem observador nativo também abre, retoma e mantém identidade estável', () => {
  const server = row('Servidor Principal');
  const fixture = setup({ rows: [server] });
  server.click = function () {
    this.clicks++;
    fixture.videos.push({ ownerDocument: fixture.document, readyState: 4,
      duration: 1200, currentTime: 0, paused: true, ended: false, plays: 0,
      play() { this.plays++; this.paused = false; return Promise.resolve(); } });
  };
  vm.runInContext(read('embed_bridge.js'), fixture.context);
  const identity = fixture.messages.at(-1).mediaId;
  fixture.timers[0]();
  assert.equal(server.clicks, 1);
  assert.equal(fixture.videos[0].currentTime, 300.123);
  assert.equal(fixture.videos[0].plays, 1);
  assert.equal(fixture.messages.at(-1).mediaId, identity);
});

test('inicia uma vez quando o fornecedor só libera seekable depois de play', () => {
  const fixture = setup();
  const ranges = { length: 0, start: () => 0, end: () => 1200 };
  const video = { readyState: 4, duration: 1200, currentTime: 0, paused: true,
    seekable: ranges, plays: 0,
    play() { this.plays++; this.paused = false; return Promise.resolve(); } };
  fixture.videos.push(video);
  vm.runInContext(read('embed_media_observer.js'), fixture.context);
  fixture.timers[0]();
  assert.equal(video.plays, 1);
  assert.equal(fixture.messages.at(-1).restoring, true);
  ranges.length = 1;
  fixture.timers[0]();
  assert.equal(video.currentTime, 300.123);
  assert.equal(video.plays, 1);
  assert.equal(fixture.messages.at(-1).restoring, false);
});

test('bloqueio de autoplay sinaliza toque necessário e não insiste', async () => {
  const fixture = setup();
  let plays = 0;
  const video = { readyState: 4, duration: 1200, paused: true,
    play() { plays++; return Promise.reject(new Error('NotAllowedError')); } };
  fixture.context.__cineyAutoPlay(video, false);
  await Promise.resolve();
  fixture.context.__cineyAutoPlay(video, false);
  assert.equal(plays, 1);
  assert.deepEqual(fixture.messages, [{ event: 'interaction' }]);
});

test('comando de pausa antes do vídeo cancela seleção e autoplay pendentes', () => {
  const rows = [];
  const fixture = setup({ rows });
  vm.runInContext(read('embed_media_observer.js'), fixture.context);
  fixture.context.__cineyRequestProgress({ event: 'ciney:progress', requestId: 'exit', pause: true });
  const server = row('Servidor Principal');
  rows.push(server);
  const video = { readyState: 4, duration: 1200, currentTime: 300.123, paused: true,
    play() { throw new Error('não deve reproduzir'); } };
  fixture.videos.push(video);
  fixture.timers[0]();
  assert.equal(server.clicks, 0);
  assert.equal(video.paused, true);
});

test('não reproduz anúncio curto, vídeo terminado ou após intervenção manual', () => {
  const fixture = setup();
  const fail = () => { throw new Error('não deve reproduzir'); };
  fixture.context.__cineyAutoPlay({ readyState: 4, duration: 30, paused: true, play: fail }, false);
  fixture.context.__cineyAutoPlay({ readyState: 4, duration: 1200, paused: true, ended: true, play: fail }, false);
  fixture.start();
  fixture.events.pointerdown({ isTrusted: true });
  fixture.context.__cineyAutoPlay({ readyState: 4, duration: 1200, paused: true, play: fail }, false);
});

test('script idempotente e eventos liberados na saída', () => {
  const fixture = setup();
  fixture.start();
  const start = fixture.context.__cineyStartPlayback;
  vm.runInContext(startup, fixture.context);
  assert.equal(fixture.context.__cineyStartPlayback, start);
  fixture.windowEvents.pagehide();
  assert.deepEqual(Object.keys(fixture.events), []);
});
