import {writeFileSync} from 'node:fs';
const obstacles=[];
const add=(x,y,width,height,texture)=>obstacles.push({x,y,width,height,texture});
for(let x=0;x<48;x++){add(x,0,1,1,'wall');if(x<21||x>26)add(x,31,1,1,'wall');}
for(let y=1;y<31;y++){add(0,y,1,1,'wall');add(47,y,1,1,'wall');}
for(const [x,y,texture] of [[15,14,'house'],[17,7,'house'],[29,14,'shop'],[34,18,'smith'],[17,23,'house'],[29,23,'house']])add(x,y,4,3,texture);
add(23,14,2,2,'shrine');
for(const [x,y] of [[5,5],[13,5],[32,4],[41,5],[5,16],[16,18],[30,18],[42,17],[6,27],[16,26],[31,27],[41,27]])add(x,y,1,1,'tree');
const world={id:'village',name:'Aldea de Éter',width:48,height:32,tile:32,spawn:{x:784,y:592},obstacles,
 npcs:[{id:'shop',x:1008,y:560},{id:'smith',x:1104,y:688}],
 monsters:[['spider',39,23],['goblin',42,21],['wolf',39,26],['skeleton',44,23],['orc',42,27],['guardian',45,27]].map(([species,x,y])=>({species,x:x*32+16,y:y*32+16}))};
writeFileSync(new URL('../shared/world.json',import.meta.url),JSON.stringify(world,null,2)+'\n');
console.log('Generated original village geometry');
