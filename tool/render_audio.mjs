// Uses Chromium's OfflineAudioContext and the original synthesizer, not replacement music.
import fs from 'node:fs';
import {masterClip} from './master_audio.mjs';
import http from 'node:http';
import os from 'node:os';
import path from 'node:path';
import {spawn} from 'node:child_process';
import {fileURLToPath} from 'node:url';
const root=fileURLToPath(new URL('../',import.meta.url));
const source=fs.readFileSync(root+'reference/src/engine/audio.js','utf8').replace('function tone(', 'export function tone(');
const html=`<!doctype html><body>Rendering audio<script type="module">
const source=await (await fetch('/source')).text();
async function synth(name,run,duration=1.1) {
  const context=new OfflineAudioContext(1,Math.ceil(22050*duration),22050);
  window.AudioContext=function(){return context};
  const url=URL.createObjectURL(new Blob([source],{type:'text/javascript'}));
  const m=await import(url);m.setVolume(1);run(m);
  const b=await context.startRendering(),samples=b.getChannelData(0);
  const buf=new ArrayBuffer(44+samples.length*2),v=new DataView(buf);
  const str=(at,s)=>[...s].forEach((c,i)=>v.setUint8(at+i,c.charCodeAt(0)));
  str(0,'RIFF');v.setUint32(4,36+samples.length*2,true);str(8,'WAVE');str(12,'fmt ');
  v.setUint32(16,16,true);v.setUint16(20,1,true);v.setUint16(22,1,true);
  v.setUint32(24,22050,true);v.setUint32(28,44100,true);v.setUint16(32,2,true);v.setUint16(34,16,true);
  str(36,'data');v.setUint32(40,samples.length*2,true);
  for(let i=0;i<samples.length;i++)v.setInt16(44+i*2,Math.max(-1,Math.min(1,samples[i]))*32767,true);
  await fetch('/save/'+name+'.wav',{method:'POST',body:buf});URL.revokeObjectURL(url);
}
try {
  const url=URL.createObjectURL(new Blob([source],{type:'text/javascript'}));const ref=await import(url);
  const manifest={tracks:{},effects:Object.keys(ref.sfx)};
  for(const name of manifest.effects) await synth('sfx-'+name,m=>m.sfx[name](),name==='win'?1.3:name==='death'?1.1:.65);
  for(let floor=0;floor<=50;floor++) {
    const boss=[10,20,30,40,50].includes(floor),track=ref.trackFor(floor,boss);
    manifest.tracks[floor]={...track,stepMs:floor===0?track.stepMs*2:track.stepMs};
    for(let step=0;step<8;step++) {
      const idx=track.pattern[step];
      await synth('bgm-'+floor+'-'+step,m=>{
        m.tone(track.scale[idx],{dur:boss?.3:.46,vol:boss?.04:.035,type:boss?'sawtooth':'triangle'});
        if(step%4===0)m.tone(track.scale[0]/2,{dur:.9,vol:.035,type:'sine'});
        if(boss&&step%2===1)m.tone(track.scale[idx]/2,{dur:.2,vol:.02,type:'square'});
      });
    }
  }
  await fetch('/manifest',{method:'POST',body:JSON.stringify(manifest,null,2)});
  await fetch('/done',{method:'POST'});document.body.textContent='done';
} catch(e) {await fetch('/error',{method:'POST',body:e.stack});}
</script>`;
let finish;
const done=new Promise((resolve,reject)=>{finish={resolve,reject}});
let count=0;
const server=http.createServer(async(req,res)=>{
  if(req.url==='/'){res.setHeader('Content-Type','text/html');res.end(html);return;}
  if(req.url==='/source'){res.end(source);return;}
  const chunks=[];for await(const c of req)chunks.push(c);const body=Buffer.concat(chunks);
  if(/^\/save\/[a-z0-9-]+\.wav$/.test(req.url)){const name=req.url.slice(6);fs.writeFileSync(root+'assets/audio/'+name,masterClip(body,name.slice(0,-4)));count++;}
  else if(req.url==='/manifest')fs.writeFileSync(root+'assets/data/audio.json',body);
  else if(req.url==='/done')finish.resolve();
  else if(req.url==='/error')finish.reject(new Error(body.toString()));
  res.end('ok');
});
await new Promise(r=>server.listen(0,'127.0.0.1',r));
const profile=fs.mkdtempSync(path.join(os.tmpdir(),'star-audio-'));
const chrome=spawn(process.env.CHROME_PATH??'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',[
  '--headless=new','--no-first-run','--no-default-browser-check','--disable-background-networking',
  '--autoplay-policy=no-user-gesture-required','--user-data-dir='+profile,`http://127.0.0.1:${server.address().port}`
],{stdio:'ignore'});
const timeout=setTimeout(()=>finish.reject(new Error('Audio rendering timeout')),180000);
try {await done;console.log(`Rendered ${count} original Web Audio clips.`);}
finally {clearTimeout(timeout);chrome.kill();await new Promise(r=>chrome.once('exit',r));server.close();fs.rmSync(profile,{recursive:true,force:true});}
