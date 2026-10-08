const test = require('node:test');
const assert = require('node:assert/strict');
const vm = require('node:vm');
const fs = require('node:fs');
const path = require('node:path');
const script = fs.readFileSync(path.join(__dirname, '../assets/player/embed_media_observer.js'), 'utf8');
const resumeScript = fs.readFileSync(path.join(__dirname, '../assets/player/playback_resume.js'), 'utf8');

function setup(videos = [], mainFrame = false, resume = 0, frames = [], expectedDuration = 0) {
  const messages = [], timers = [], documentEvents = {}, windowEvents = {};
  let cleared = false;
  const context = vm.createContext({
    document: {
      querySelectorAll: selector => selector === 'video' ? videos : frames,
      addEventListener: (name, handler) => { documentEvents[name] = handler; },
      removeEventListener: name => { delete documentEvents[name]; },
    },
    PlayerBridge: { postMessage: value => messages.push(JSON.parse(value)) },
    setInterval: callback => { timers.push(callback); return 1; },
    clearInterval: () => { cleared = true; },
    addEventListener: (name, handler) => { windowEvents[name] = handler; },
    removeEventListener: name => { delete windowEvents[name]; },
    __cineyResumePositionSeconds: resume,
    __cineyExpectedDurationSeconds: expectedDuration,
  });
  context.window = context;
  context.top = mainFrame ? context : {};
  context.parent = {};
  vm.runInContext(resumeScript, context);
  vm.runInContext(script, context);
  return { context, messages, timers, documentEvents, windowEvents, isCleared: () => cleared };
}

test('observa vídeo no próprio iframe externo e detecta término sem reiniciar', () => {
  let plays = 0;
  const video = { readyState: 4, duration: 1200, currentTime: 10, paused: false,
    currentSrc: 'blob:episode', ended: false, play: () => plays++ };
  const fixture = setup([video]);
  fixture.timers[0]();
  const identity = fixture.messages[0].mediaId;
  video.currentTime = 1200;
  video.paused = true;
  video.ended = true;
  fixture.documentEvents.ended();
  fixture.timers[0]();
  assert.equal(fixture.messages.filter(m => m.ended).length, 1);
  assert.equal(fixture.messages.at(-1).mediaId, identity);
  assert.equal(plays, 0);
});

test('não transforma pausa, anúncio, live ou erro em fim de episódio', () => {
  const ad = { readyState: 4, duration: 30, currentTime: 30, paused: true, ended: true };
  const live = { readyState: 4, duration: Infinity, currentTime: 600, paused: false };
  const episode = { readyState: 4, duration: 1200, currentTime: 1199, paused: true, ended: false };
  const fixture = setup([ad, live, episode]);
  fixture.timers[0]();
  assert.equal(fixture.messages.length, 1);
  assert.equal(fixture.messages[0].ended, false);
  assert.equal(fixture.messages[0].duration, 1200);
  episode.error = { code: 3 };
  episode.ended = true;
  fixture.timers[0]();
  assert.equal(fixture.messages.length, 1);
});

test('mudar a fonte limpa a identidade e não aceita término de mídia não assistida', () => {
  const video = { readyState: 4, duration: 1200, currentTime: 10, paused: false, currentSrc: 'first' };
  const fixture = setup([video]);
  fixture.timers[0]();
  const oldId = fixture.messages[0].mediaId;
  video.currentSrc = 'second';
  video.currentTime = 1200;
  video.paused = true;
  video.ended = true;
  fixture.timers[0]();
  assert.equal(fixture.messages.length, 1);
  video.currentTime = 10;
  video.paused = false;
  video.ended = false;
  fixture.timers[0]();
  assert.notEqual(fixture.messages.at(-1).mediaId, oldId);
});

test('não duplica observador e libera eventos ao sair da página', () => {
  const fixture = setup();
  vm.runInContext(script, fixture.context);
  assert.equal(fixture.timers.length, 1);
  fixture.windowEvents.pagehide();
  assert.equal(fixture.isCleared(), true);
  assert.deepEqual(Object.keys(fixture.documentEvents), []);
  assert.equal(setup([], true).timers.length, 0);
});

test('retoma milissegundos no iframe e preserva buscas manuais posteriores', () => {
  const video = { readyState: 4, duration: 7200, currentTime: 0, paused: false, currentSrc: 'film' };
  const fixture = setup([video], false, 2456.789);
  fixture.timers[0]();
  assert.equal(video.currentTime, 2456.789);
  assert.equal(fixture.messages.at(-1).restoring, false);
  video.currentTime = 800;
  fixture.documentEvents.seeked();
  assert.equal(video.currentTime, 800);
});

test('aguarda seekable e confirmação sem anunciar retomada no início do filme', () => {
  const ranges = { length: 0, start: () => 0, end: () => 7200 };
  const video = { readyState: 4, duration: 7200, currentTime: 0, paused: false, seekable: ranges };
  const fixture = setup([video], false, 987.654);
  fixture.timers[0]();
  assert.equal(fixture.messages.at(-1).restoring, true);
  assert.equal(video.currentTime, 0);
  ranges.length = 1;
  fixture.documentEvents.canplay();
  assert.equal(video.currentTime, 987.654);
  assert.equal(fixture.messages.at(-1).restoring, false);
});

test('consulta atual congela e informa ponto exato antes de sair, sem depender do poll', () => {
  const video = { readyState: 4, duration: 7200, currentTime: 1, paused: false,
    pause() { this.paused = true; } };
  const commands = [];
  const fixture = setup([video], false, 0, [{ contentWindow: { postMessage: value => commands.push(value) } }]);
  fixture.timers[0]();
  video.currentTime = 3000.123;
  const command = { event: 'ciney:progress', requestId: 'close-1', pause: true };
  fixture.windowEvents.message({ source: fixture.context.parent, data: command });
  assert.equal(fixture.messages.at(-1).current, 3000.123);
  assert.equal(fixture.messages.at(-1).requestId, 'close-1');
  assert.equal(video.paused, true);
  assert.deepEqual(commands, [command]);
});

test('ignora comandos de janela externa e não busca em anúncios curtos', () => {
  const video = { readyState: 4, duration: 30, currentTime: 1, paused: false };
  const fixture = setup([video], false, 1234);
  fixture.windowEvents.message({ source: {}, data: { event: 'ciney:progress', requestId: 'ad' } });
  fixture.timers[0]();
  assert.equal(video.currentTime, 1);
  assert.equal(fixture.messages.length, 0);
});

test('anúncio maior que três minutos não sobrescreve filme com duração conhecida', () => {
  const ad = { readyState: 4, duration: 240, currentTime: 10, paused: false };
  const videos = [ad];
  const fixture = setup(videos, false, 60.123, [], 7200);
  fixture.timers[0]();
  assert.equal(ad.currentTime, 10);
  assert.equal(fixture.messages.length, 0);
  const film = { readyState: 4, duration: 7200, currentTime: 0, paused: false };
  videos.push(film);
  fixture.timers[0]();
  assert.equal(film.currentTime, 60.123);
  assert.equal(fixture.messages.at(-1).duration, 7200);
});
