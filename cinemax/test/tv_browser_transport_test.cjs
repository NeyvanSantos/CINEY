const test = require('node:test');
const assert = require('node:assert/strict');
const vm = require('node:vm');
const fs = require('node:fs');
const path = require('node:path');
const script = fs.readFileSync(path.join(__dirname,'../../packages/ciney_core/assets/player/tv_browser_transport.js'),'utf8');
function setup(fetch, videos=[]) {
  const messages=[],events={};
  const bridge={postMessage(raw){const value=JSON.parse(raw);messages.push(value);
    if(value.kind==='chunk')queueMicrotask(()=>bridge.onmessage({data:JSON.stringify({kind:'ack',id:value.id})}));}};
  const context=vm.createContext({URL,AbortController,setTimeout,clearTimeout,btoa,
    location:{href:'https://provider.test/player'},fetch,
    CineyNativeFetch:bridge,document:{querySelectorAll:()=>videos},
    addEventListener:(name,fn)=>events[name]=fn});
  context.window=context;context.top={};vm.runInContext(script,context);
  return {messages,context,send:message=>bridge.onmessage({data:JSON.stringify(message)})};
}
async function waitFor(f,kind){for(let i=0;i<50;i++){if(f.messages.some(m=>m.kind===kind))return;await new Promise(r=>setImmediate(r));}throw Error('No '+kind);}
test('browser session streams binary with acknowledgements and forwards Range',async()=>{
  const bytes=Uint8Array.from({length:70000},(_,i)=>i%251);
  let options;
  const f=setup(async(url,opts)=>{options=opts;return new Response(bytes,{status:206});});
  assert.equal(f.messages[0].kind,'hello');
  f.send({kind:'fetch',id:'one',url:'https://cdn.test/segment',range:'bytes=10-70009'});
  await waitFor(f,'end');
  assert.equal(options.credentials,'same-origin');assert.equal(options.headers.Range,'bytes=10-70009');
  assert.equal(f.messages.find(m=>m.kind==='start').status,206);
  const body=Buffer.concat(f.messages.filter(m=>m.kind==='chunk').map(m=>Buffer.from(m.data,'base64')));
  assert.deepEqual(body,Buffer.from(bytes));
});
test('pause stops local decode and resume restores only previously playing video',()=>{
  let pauses=0,plays=0;
  const f=setup(async()=>new Response(''),[{paused:false,pause(){pauses++;},play(){plays++;return Promise.resolve();}},{paused:true}]);
  f.send({kind:'pauseLocal'});assert.equal(pauses,1);assert.equal(f.context.__cineyNativeTransportActive,true);
  f.send({kind:'resumeLocal'});assert.equal(plays,1);assert.equal(f.context.__cineyNativeTransportActive,false);
});
test('failed browser fetch reports failure without copying cookies',async()=>{
  const f=setup(async()=>{throw Error('denied');});f.send({kind:'fetch',id:'two',url:'https://cdn.test/master'});
  await waitFor(f,'error');assert.equal(f.messages.find(m=>m.kind==='error').id,'two');
  assert.equal(JSON.stringify(f.messages).includes('Cookie'),false);
});

test('native handoff stops provider buffers, keeps fetch alive and restores position on failure',async()=>{
  let stops=0,plays=0,seek=0,firstFrame;
  const f=setup(async()=>new Response('playlist'),[{paused:false,pause(){},play(){throw Error('stale video');}}]);
  f.context.jwplayer=()=>({getPosition:()=>125,stop(){stops++;},
    once(event,callback){assert.equal(event,'firstFrame');firstFrame=callback;},
    play(){plays++;},seek(value){seek=value;}});
  f.send({kind:'pauseLocal'});f.send({kind:'pauseLocal'});
  assert.equal(stops,1);
  f.send({kind:'fetch',id:'after-stop',url:'https://cdn.test/master'});
  await waitFor(f,'end');
  f.send({kind:'resumeLocal'});firstFrame();
  assert.equal(plays,1);assert.equal(seek,125);
});

test('cross-origin CDN uses browser default credentials so wildcard CORS stays valid',async()=>{
  const f=setup(async(url,opts)=>{
    if(opts.credentials==='include')throw new TypeError('Credentialed CORS rejected');
    return new Response(Uint8Array.from([0x47,0x40,0x11]));
  });
  f.send({kind:'fetch',id:'cdn',url:'https://cdn.test/video.ts'});
  await waitFor(f,'end');
  assert.equal(f.messages.some(m=>m.kind==='error'),false);
  assert.equal(f.messages.find(m=>m.kind==='start').status,200);
});
