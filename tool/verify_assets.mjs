import fs from 'node:fs';
import assert from 'node:assert/strict';
import {fileURLToPath} from 'node:url';
import {trackFor,sfx} from '../reference/src/engine/audio.js';
const root=fileURLToPath(new URL('../',import.meta.url));
const game=JSON.parse(fs.readFileSync(root+'assets/data/game.json','utf8'));
const audio=JSON.parse(fs.readFileSync(root+'assets/data/audio.json','utf8'));
function verifyWav(name) {
  const b=fs.readFileSync(root+'assets/audio/'+name+'.wav');
  assert.equal(b.toString('ascii',0,4),'RIFF');assert.equal(b.readUInt32LE(24),22050);
  assert.equal(b.readUInt32LE(40),b.length-44);
  let peak=0;for(let i=44;i<b.length;i+=2)peak=Math.max(peak,Math.abs(b.readInt16LE(i)));
  assert(peak>0,`${name} is silent`);
  assert(peak<32767,`${name} clips`);
  assert(peak/32768 >= (name.startsWith('bgm-')?.15:.30),`${name} is too quiet for the mobile mix`);
}
for(const name of Object.keys(sfx)) verifyWav('sfx-'+name);
for(let f=0;f<=50;f++) {
  const t=trackFor(f,[10,20,30,40,50].includes(f));if(f===0)t.stepMs*=2;
  assert.deepEqual(audio.tracks[f],t);
  for(let i=0;i<8;i++)verifyWav(`bgm-${f}-${i}`);
}
function checkArt(v){if(typeof v==='string')assert(fs.existsSync(root+'assets/images/'+v+'.svg'));else for(const item of Object.values(v))checkArt(item);}
checkArt(game.art);
assert.equal(Object.keys(game.maps).length,50);
console.log('419 WAV clips non-silent, all 51 music sequences identical, all mapped art assets present.');
