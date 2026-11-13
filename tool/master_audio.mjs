// Offline mobile mastering. FFmpeg is only needed when regenerating assets.
import {execFileSync} from 'node:child_process';

export function masterClip(wav, name) {
  let peak=0;
  for(let i=44;i<wav.length;i+=2) peak=Math.max(peak,Math.abs(wav.readInt16LE(i))/32768);
  if(!peak) throw new Error(`Silent source: ${name}`);
  const music=name.startsWith('bgm-');
  const base=music?7:((name==='sfx-move'||name==='sfx-click')?.36:.48)/peak;
  const gain=base*Math.pow(10,30/20);
  const pcm=execFileSync(process.env.FFMPEG_PATH??'ffmpeg',[
    '-hide_banner','-loglevel','error','-f','s16le','-ar','22050','-ac','1','-i','pipe:0',
    '-af',`volume=${gain},alimiter=limit=.98:attack=1:release=5:level=0:latency=1`,
    '-f','s16le','pipe:1'
  ],{input:wav.subarray(44),maxBuffer:1024*1024});
  if(pcm.length!==wav.length-44) throw new Error(`Changed duration: ${name}`);
  for(let i=0;i<pcm.length;i+=2) {
    if(Math.abs(pcm.readInt16LE(i))/32768>.9801) throw new Error(`Limiter exceeded ceiling: ${name}`);
  }
  return Buffer.concat([wav.subarray(0,44),pcm]);
}
