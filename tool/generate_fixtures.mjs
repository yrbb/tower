import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import {pathToFileURL, fileURLToPath} from 'node:url';
import {gzipSync} from 'node:zlib';
import * as original from '../reference/src/game/star/engine.js';
import * as rules from '../reference/src/game/star/rules.js';
const root=fileURLToPath(new URL('../',import.meta.url));
const defsList=[], defsIndex=new Map(), calls=[];
const clone=v=>JSON.parse(JSON.stringify(v,(_,x)=>x===Infinity?{$number:'Infinity'}:x));
function record(group,name,args) {
  const before=clone(args);
  let result=null,error=null;
  try { result=(group==='engine'?original:rules)[name](...args); } catch(e) { error=e.message; }
  let defId=null;
  if (group==='engine' && !['undo','serialize','deserialize'].includes(name)) {
    const i=name==='createGame'?0:1;
    const key=JSON.stringify(before[i]);
    if (!defsIndex.has(key)) { defsIndex.set(key,defsList.length);defsList.push(before[i]); }
    defId=defsIndex.get(key);before.splice(i,1);
  }
  calls.push({group,name,args:before,defId,error,result:clone(result),state:group==='engine'&&name!=='createGame'&&name!=='deserialize'?clone(args[0]):null});
  return result;
}
globalThis.__record=record;
const tmp=fs.mkdtempSync(path.join(os.tmpdir(),'star-reference-'));
try {
  for(const group of ['engine','rules']) {
    const mod=group==='engine'?original:rules;
    let wrapper='';
    for(const [name,v] of Object.entries(mod)) {
      wrapper+=typeof v==='function'?`export const ${name}=(...args)=>globalThis.__record('${group}','${name}',args);\n`:`export const ${name}=${JSON.stringify(v)};\n`;
    }
    const wp=path.join(tmp,group+'.mjs');fs.writeFileSync(wp,wrapper);
    let src=fs.readFileSync(root+`reference/tests/star-${group}.mjs`,'utf8');
    src=src.replace(`'../src/game/star/${group}.js'`,JSON.stringify(pathToFileURL(wp).href));
    const test=path.join(tmp,group+'-test.mjs');fs.writeFileSync(test,src);
    await import(pathToFileURL(test));
  }
} finally { fs.rmSync(tmp,{recursive:true,force:true}); }
const {maps:defs,data}=JSON.parse(fs.readFileSync(root+'assets/data/game.json','utf8'));
// Exercise every source tile, including every item, monster, stair and event location.
for(let floor=1;floor<=50;floor++) {
  for(let y=0;y<11;y++) for(let x=0;x<11;x++) {
    if(defs[floor].grid[y][x]==='.') continue;
    const dir=x>0?'right':'left', sx=x>0?x-1:x+1;
    const s=original.createGame(defs,{startFloor:floor});
    Object.assign(s.hero,{x:sx,y,hp:100000,atk:5000,def:100,gold:50000});
    Object.assign(s.hero.keys,{yellowKey:30,blueKey:30,redKey:30});
    s.items={compass:1,pickaxe:1,flask:1,mirrorJump:1,frostCore:1,bomb:1};
    record('engine','preview',[s,defs,x,y]);
    record('engine','moveHero',[s,defs,dir]);
  }
  for(const id of Object.keys(data.ACTIVE)) {
    const s=original.createGame(defs,{startFloor:floor});
    s.items[id]=1;s.visited=[1,floor,44,50];
    record('engine','useItem',[s,defs,id,id==='compass'?1:null]);
  }
}
for(const m of Object.values(data.MONSTERS)) for(const atk of [m.def,m.def+1,m.def+25,1000]) {
  for(const hp of [1,36,1000,100000]) record('rules','combat',[{hp,atk,def:100,flags:{tideSpear:true,dragonFang:true}},m,{pillarsAlive:4}]);
}
const s=original.createGame(defs);record('engine','moveHero',[s,defs,'left']);record('engine','moveHero',[s,defs,'invalid']);record('engine','undo',[s]);
for(const save of ['broken',{}, ...[false,0,'',null,[],{}].flatMap(v=>[{version:1,hero:v,world:{}},{version:1,hero:{},world:v}]), {version:1,hero:{},world:{}}, {version:2,hero:{},world:{}}]) record('engine','deserialize',[save]);
fs.writeFileSync(root+'test/fixtures/reference.json.gz',gzipSync(JSON.stringify({defs:defsList,calls}),{level:9}));
console.log(`Captured ${calls.length} independent JS reference calls against ${defsList.length} map sets.`);
