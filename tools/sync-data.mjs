import {mkdirSync,copyFileSync} from 'node:fs';
import {fileURLToPath} from 'node:url';
const root=fileURLToPath(new URL('../',import.meta.url));
mkdirSync(root+'client/data',{recursive:true});
copyFileSync(root+'shared/classes.json',root+'client/data/classes.json');
console.log('Synced shared class data to Godot');
