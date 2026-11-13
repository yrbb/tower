import fs from 'node:fs';
import assert from 'node:assert/strict';
import {fileURLToPath} from 'node:url';
import * as data from '../reference/src/game/star/data.js';
import * as art from '../reference/src/engine/star-art.js';
const root = fileURLToPath(new URL('../', import.meta.url));
const names = ['01-04','05-15','16-27','28-39','29-32','33-36','37-39','40-50'];
const maps = {};
for (const name of names) {
  const shard = (await import(`../reference/src/game/star/maps/floors-${name}.js`)).default;
  for (const def of shard) {
    assert(!maps[def.index], `Duplicate floor ${def.index}`);
    assert.equal(def.grid.length, 11);
    assert(def.grid.every(r => [...r].length === 11));
    maps[def.index] = def;
  }
}
assert.equal(Object.keys(maps).length, 50);
const value = {sourceCommit:'e41439a3d7a72f6053b2e86f0019543bda65ca27', maps, data, art};
const json = JSON.stringify(value, (_,v) => v === Infinity ? {$number:'Infinity'} : v, 2)+'\n';
const dest = root+'assets/data/game.json';
if (process.argv.includes('--check')) assert.equal(fs.readFileSync(dest,'utf8'),json);
else fs.writeFileSync(dest,json);
console.log('50 floors, data and art mappings match pinned reference.');
