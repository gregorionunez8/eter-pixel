import {mkdirSync,copyFileSync} from 'node:fs';
import {fileURLToPath} from 'node:url';
const root=fileURLToPath(new URL('../',import.meta.url));
mkdirSync(root+'client/data',{recursive:true});
for(const name of ['classes','combat','monsters','progression','items','economy','world','maps'])copyFileSync(root+'shared/'+name+'.json',root+'client/data/'+name+'.json');
console.log('Synced shared game data to Godot');
