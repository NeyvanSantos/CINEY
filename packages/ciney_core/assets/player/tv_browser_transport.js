(function () {
  'use strict';
  if (window === window.top || !window.CineyNativeFetch || window.__cineyBrowserTransport) return;
  window.__cineyBrowserTransport = true;
  const jobs = new Map(), browserFetch = window.fetch.bind(window);
  let wasPlaying = [];
  let stoppedPlayer = null, stoppedPosition = 0;
  const send = value => CineyNativeFetch.postMessage(JSON.stringify(value));
  send({kind:'hello',page:location.href});
  CineyNativeFetch.onmessage = event => {
    let message; try { message=JSON.parse(event.data); } catch (_) { return; }
    if (message.kind === 'pauseLocal') {
      if (window.__cineyNativeTransportActive) return;
      window.__cineyNativeTransportActive = true;
      if (window.__cineyCancelStartup) window.__cineyCancelStartup();
      wasPlaying = Array.from(document.querySelectorAll('video')).filter(v=>!v.paused);
      wasPlaying.forEach(v=>v.pause());
      // Pausing a video retains its MediaSource buffers and hardware decoder.
      // Stop the provider engine before Media3 allocates the TV's decoder.
      try {
        const player = typeof window.jwplayer === 'function' ? window.jwplayer() : null;
        if (player && typeof player.stop === 'function') {
          stoppedPosition = Number(player.getPosition?.()) || 0;
          stoppedPlayer = player;
          player.stop();
        }
      } catch (_) { stoppedPlayer = null; }
      return;
    }
    if (message.kind === 'resumeLocal') {
      window.__cineyNativeTransportActive = false;
      if (stoppedPlayer && wasPlaying.length) {
        const player = stoppedPlayer, position = stoppedPosition;
        stoppedPlayer = null;
        try {
          if (position > 0) player.once('firstFrame',()=>player.seek(position));
          player.play(true);
          return;
        } catch (_) { /* Restore plain video playback if provider API failed. */ }
      }
      wasPlaying.forEach(v=>{try{v.play().catch(()=>{});}catch(_){}}); return;
    }
    const existing=jobs.get(message.id);
    if (message.kind === 'ack') { if(existing && existing.ack) existing.ack(); return; }
    if (message.kind === 'cancel') {
      if(existing){existing.cancelled=true;existing.controller.abort();if(existing.ack)existing.ack();}return;
    }
    if (message.kind !== 'fetch' || typeof message.id !== 'string') return;
    let url;try{url=new URL(message.url);if(!/^https?:$/.test(url.protocol)||url.username||url.password)return;}catch(_){return;}
    const job={controller:new AbortController(),ack:null,cancelled:false};jobs.set(message.id,job);
    (async()=>{
      try {
        const headers={};if(typeof message.range==='string' && /^bytes=\d+-\d*$/.test(message.range))headers.Range=message.range;
        const response=await browserFetch(url.href,{credentials:'same-origin',headers,signal:job.controller.signal});
        send({kind:'start',id:message.id,status:response.status,length:-1,url:response.url});
        if(!response.body)throw Error('Missing body');
        const reader=response.body.getReader();
        while(!job.cancelled){
          const chunk=await reader.read();if(chunk.done)break;
          for(let offset=0;offset<chunk.value.length && !job.cancelled;offset+=32768){
            const bytes=chunk.value.subarray(offset,offset+32768);
            await new Promise((resolve,reject)=>{
              const timeout=setTimeout(()=>reject(Error('Transfer timeout')),15000);
              job.ack=()=>{clearTimeout(timeout);job.ack=null;resolve();};
              send({kind:'chunk',id:message.id,data:btoa(String.fromCharCode.apply(null,bytes))});
            });
          }
        }
        if(job.cancelled)reader.cancel().catch(()=>{});else send({kind:'end',id:message.id});
      } catch (error) { if(!job.cancelled)send({kind:'error',id:message.id,reason:['TypeError','AbortError','TimeoutError'].includes(error.name)?error.name:'TransferError'}); }
      finally { jobs.delete(message.id); }
    })();
  };
  window.addEventListener('pagehide',()=>{for(const job of jobs.values())job.controller.abort();jobs.clear();},{once:true});
})();
