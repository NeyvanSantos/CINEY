const test = require('node:test');
const assert = require('node:assert/strict');
const vm = require('node:vm');
const fs = require('node:fs');
const path = require('node:path');
const script = fs.readFileSync(path.join(__dirname,
  '../../packages/ciney_core/assets/player/tv_remote_navigation.js'), 'utf8');
function setup(disableSubtitles = false) {
  const messages = [], events = {}, styles = [], nodes = [];
  const controls = ['Dublado', 'Legendado', 'Servidor Principal', 'Servidor Alternativo'].map((text, i) => ({
    textContent: text, children: [], clicks: 0, attributes: {},
    disabled: disableSubtitles && i === 1,
    setAttribute(k,v) { this.attributes[k] = v; },
    removeAttribute(k) { delete this.attributes[k]; },
    getAttribute(k) { return this.attributes[k]; },
    getClientRects() { return [{}]; },
    getBoundingClientRect() { return { left: i === 1 ? 310 : 0, top: i < 2 ? 0 : (i - 1) * 100,
      width: i < 2 ? 290 : 600, height: 70 }; },
    focus() {}, scrollIntoView() {}, click() { this.clicks++; }, contains() { return false; },
  }));
  const document = { querySelectorAll: () => controls,
    createElement: () => ({style:{}, setAttribute() {}}), body: {appendChild(node) { nodes.push(node); }}, head: { appendChild: style => styles.push(style) },
    addEventListener: (name, fn) => { events[name] = fn; }, removeEventListener() {} };
  const context = vm.createContext({ URL, document, location: { hostname: 'myembed.biz', pathname: '/filme/1' },
    __cineyProviderPath: '/filme/1', innerWidth:1280, innerHeight:720,
    getComputedStyle: element => ({ display: 'block', visibility: 'visible',
      backgroundColor:'rgba(0, 0, 0, 0)',backgroundImage:'none',...element.computedStyle }),
    TvMediaBridge: { postMessage: message => messages.push(JSON.parse(message)) },
    addEventListener() {} });
  context.window = context; context.top = {};
  vm.runInContext(script, context);
  return { controls, messages, styles, nodes, context,
    prepare: () => context.__cineyTvPrepareMenu(document),
    key(key, repeat = false) { events.keydown({ key, repeat, preventDefault() {}, stopImmediatePropagation() {} }); },
    focused: () => controls.find(c => c.attributes['data-ciney-tv-focus'] === 'true')?.textContent };
}
test('D-pad highlights audio and server choices; OK activates exactly once', () => {
  const f = setup();
  assert.equal(f.prepare(), true);
  assert.equal(f.focused(), 'Servidor Principal');
  f.key('ArrowDown'); assert.equal(f.focused(), 'Servidor Alternativo');
  f.key('ArrowUp'); assert.equal(f.focused(), 'Servidor Principal');
  f.key('ArrowUp'); assert.equal(f.focused(), 'Dublado');
  f.key('ArrowRight'); assert.equal(f.focused(), 'Legendado');
  f.key('Enter'); f.key('Enter', true);
  assert.equal(f.controls[1].clicks, 1);
  f.key('ArrowLeft'); f.key('ArrowDown'); f.key('Enter');
  assert.equal(f.controls[2].clicks, 1);
  assert.equal(f.messages.filter(m => m.action === 'ready').length, 1);
  assert.equal(f.messages.filter(m => m.action === 'selected').length, 1);
  assert.match(f.styles[0].textContent, /outline:4px solid #ff6b00/);
});

function overlayFixture(options = {}) {
  const f=setup();f.context.location.hostname='superflixapi.fun';
  const overlay={tagName:'A',textContent:'',children:[],href:'https://advert.test/open',
    style:{setProperty(name,value){this[name]=value;}},
    getBoundingClientRect:()=>({left:0,top:0,width:1280,height:720}),...options};
  f.context.document.elementFromPoint=(x,y)=>{
    if(overlay.style['pointer-events']!=='none')return overlay;
    return f.controls.find(c=>{const r=c.getBoundingClientRect();return x>=r.left&&x<=r.left+r.width&&y>=r.top&&y<=r.top+r.height;});
  };
  return {...f,overlay};
}

test('transparent external full-screen ad does not hide the cursor or capture server activation',()=>{
  const f=overlayFixture();
  assert.equal(f.prepare(),true);
  assert.equal(f.overlay.style['pointer-events'],'none');
  assert.equal(f.nodes[0].style.display,'block');
  f.key('ArrowDown');f.key('Enter');
  assert.equal(f.messages.filter(m=>m.action==='activate').length,1);
  assert.equal(f.messages.find(m=>m.action==='activate').label,'Servidor Principal');
});

test('verification frames, visible links and same-origin controls remain untouched',()=>{
  for(const options of [{tagName:'IFRAME'}, {textContent:'Verifique que você é humano'},
    {href:'https://superflixapi.fun/confirm'}, {href:'https://challenges.cloudflare.com/verify'},
    {computedStyle:{backgroundColor:'rgb(0, 0, 0)'}}, {children:[{tagName:'IMG'}]}]){
    const f=overlayFixture(options);
    assert.equal(f.prepare(),false);
    assert.equal(f.overlay.style['pointer-events'],undefined);
    f.key('Enter');assert.equal(f.messages.some(m=>m.action==='activate'),false);
  }
});

test('cursor reaches the alternative server and OK requests exactly one real tap',()=>{
  const f=overlayFixture();f.prepare();
  for(let step=0;step<6;step++)f.key('ArrowDown');
  f.key('Enter');f.key('Enter',true);
  const taps=f.messages.filter(m=>m.action==='activate');
  assert.equal(taps.length,1);
  assert.equal(taps[0].label,'Servidor Alternativo');
  assert.equal(f.controls[3].clicks,0);
});

test('nearly invisible ad wrapper also stops intercepting the verified menu',()=>{
  const f=overlayFixture();
  const wrapper={tagName:'DIV',textContent:'',children:[f.overlay],
    computedStyle:{backgroundColor:'rgb(0, 0, 0)',opacity:'0.01',position:'fixed'},
    style:{setProperty(name,value){this[name]=value;}},
    getBoundingClientRect:f.overlay.getBoundingClientRect};
  f.context.document.elementFromPoint=(x,y)=>{
    if(f.overlay.style['pointer-events']!=='none')return f.overlay;
    if(wrapper.style['pointer-events']!=='none')return wrapper;
    return f.controls.find(c=>{const r=c.getBoundingClientRect();return x>=r.left&&x<=r.left+r.width&&y>=r.top&&y<=r.top+r.height;});
  };
  assert.equal(f.prepare(),true);
  assert.equal(wrapper.style['pointer-events'],'none');
  f.key('Enter');assert.equal(f.messages.filter(m=>m.action==='activate').length,1);
});

test('a partially covered menu does not send a native tap into an unrelated overlay',()=>{
  const f=overlayFixture({textContent:'Player'});
  const overlay=f.overlay;
  f.context.document.elementFromPoint=(x,y)=>y<100?f.controls[0]:overlay;
  assert.equal(f.prepare(),true);
  f.key('Enter');
  assert.equal(f.messages.some(m=>m.action==='activate'),false);
});
test('disabled audio options are skipped and unrelated pages retain their keys', () => {
  const f = setup(true);
  f.prepare(); f.key('ArrowUp'); f.key('ArrowRight');
  assert.equal(f.focused(), 'Dublado');
  f.context.location.hostname = 'unrelated.test';
  assert.equal(f.prepare(), false);
  f.key('Enter');
  assert.equal(f.controls[0].clicks, 0);
});
test('OK activates the nested provider control while highlighting the whole card', () => {
  const f = setup();
  const inner = {textContent: 'Servidor Principal', children: [], clicks: 0,
    click() { this.clicks++; }};
  f.controls[2].querySelectorAll = () => [inner];
  f.prepare(); f.key('Enter');
  assert.equal(inner.clicks, 1);
  assert.equal(f.controls[2].clicks, 0);
  assert.equal(f.focused(), 'Servidor Principal');
});

test('SuperFlix OK requests a pointer click on the highlighted server', () => {
  const f = setup(); f.context.location.hostname = 'superflixapi.fun';
  f.prepare(); f.key('Enter'); f.key('Enter', true);
  assert.equal(f.controls[2].clicks, 0);
  const taps = f.messages.filter(m => m.action === 'activate');
  assert.equal(taps.length, 1);
  assert.equal(taps[0].label, 'Servidor Principal');
  assert.equal(taps[0].x, 300/1280);
  assert.equal(taps[0].y, 135/720);
});

test('SuperFlix cursor moves freely and disappears outside the server screen', () => {
  const f = setup(); f.context.location.hostname = 'superflixapi.fun';
  f.prepare(); f.key('ArrowRight'); f.key('ArrowDown'); f.key('Enter');
  const tap = f.messages.find(m => m.action === 'activate');
  assert.equal(tap.x, 318/1280); assert.equal(tap.y, 153/720);
  f.context.location.pathname = '/player';
  assert.equal(f.prepare(), false);
  f.key('Enter');
  assert.equal(f.messages.filter(m => m.action === 'activate').length, 1);
});

test('SuperFlix stops intercepting keys when a player covers the menu', () => {
  const f = setup(); f.context.location.hostname = 'superflixapi.fun';
  f.prepare();
  f.context.document.elementFromPoint = () => ({tagName:'IFRAME'});
  f.controls.forEach(c => c.contains = () => false);
  assert.equal(f.prepare(), false);
  f.key('Enter');
  assert.equal(f.messages.filter(m => m.action === 'activate').length, 0);
});
