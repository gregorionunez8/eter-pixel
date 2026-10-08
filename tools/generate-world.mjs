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
world.terrain='terrain';world.ambient='#d4e3f5';world.ground_color='#34413c';world.path_color='#796654';
world.regions=[{x:21,y:0,width:6,height:32,tile:1},{x:0,y:16,width:48,height:4,tile:1},{x:20,y:12,width:8,height:9,tile:2}];
world.labels=[{x:1170,y:651,text:'CERCADO DE LA NIEBLA'}];
world.portals=[{id:'village_forest',name:'Bosque de las Sombras',x:784,y:976,target:'forest',arrival:{x:176,y:176}}];
function make(id,name,terrain,ambient){return{id,name,width:48,height:32,tile:32,terrain,ambient,ground_color:id==='forest'?'#253c36':'#343440',path_color:id==='forest'?'#665749':'#58606c',spawn:{x:176,y:176},obstacles:[],npcs:[],monsters:[],regions:[],labels:[],portals:[]};}
const forest=make('forest','Bosque de las Sombras','terrain_forest','#9cbdc2');
const crypt=make('crypt','Cripta Olvidada','terrain_crypt','#b8b2cc');
function boundary(map,texture){for(let x=0;x<48;x++)for(const y of [0,31])map.obstacles.push({x,y,width:1,height:1,texture});for(let y=1;y<31;y++)for(const x of [0,47])map.obstacles.push({x,y,width:1,height:1,texture});}
boundary(forest,'tree_shadow');boundary(crypt,'crypt_wall');
forest.regions=[{x:4,y:3,width:3,height:24,tile:1},{x:4,y:12,width:37,height:3,tile:1},{x:38,y:12,width:6,height:14,tile:2}];
for(const [x0,y0,w,h] of [[10,3,8,6],[10,20,8,7],[24,19,8,7],[34,3,8,6]])for(let y=y0;y<y0+h;y+=2)for(let x=x0;x<x0+w;x+=2)forest.obstacles.push({x,y,width:1,height:1,texture:'tree_shadow'});
forest.obstacles.push({x:23,y:4,width:7,height:5,texture:'pond'});
for(const [x,y] of [[18,15],[21,18],[33,11],[35,18]])forest.obstacles.push({x,y,width:1,height:1,texture:'rock'});
forest.monsters=[['spider',14,13],['goblin',20,11],['wolf',27,14],['goblin',34,13],['wolf',41,19],['orc',35,24]].map(([species,x,y],i)=>({id:`forest-monster-${i}`,species,x:x*32+16,y:y*32+16}));
forest.portals=[{id:'forest_village',name:'Aldea de Éter',x:176,y:144,target:'village',arrival:{x:784,y:944}},{id:'forest_crypt',name:'Cripta Olvidada',x:1360,y:784,target:'crypt',arrival:{x:176,y:176}}];
forest.labels=[{x:670,y:340,text:'LAGUNA DE LAS VOCES'},{x:1080,y:910,text:'SENDA DEL UMBRAL'}];
crypt.regions=[{x:3,y:3,width:12,height:12,tile:1},{x:18,y:4,width:12,height:12,tile:2},{x:32,y:19,width:12,height:11,tile:3}];
for(let y=3;y<29;y++){if(![12,13,14,23,24,25].includes(y))crypt.obstacles.push({x:17,y,width:1,height:1,texture:'crypt_wall'});if(![8,9,10,20,21,22].includes(y))crypt.obstacles.push({x:31,y,width:1,height:1,texture:'crypt_wall'});}
for(let x=3;x<45;x++)if(![8,9,10,21,22,23,36,37,38].includes(x))crypt.obstacles.push({x,y:17,width:1,height:1,texture:'crypt_wall'});
for(const [x,y] of [[6,12],[24,12],[38,6],[39,21]])crypt.obstacles.push({x,y,width:2,height:2,texture:'crypt_pillar'});
crypt.monsters=[['skeleton',12,10],['skeleton',22,8],['orc',25,22],['skeleton',36,12],['orc',38,26],['guardian',42,25]].map(([species,x,y],i)=>({id:`crypt-monster-${i}`,species,x:x*32+16,y:y*32+16}));
crypt.portals=[{id:'crypt_forest',name:'Bosque de las Sombras',x:176,y:144,target:'forest',arrival:{x:1328,y:784}}];
crypt.labels=[{x:570,y:600,text:'OSARIO DEL SILENCIO'},{x:1030,y:980,text:'CÁMARA DEL VIGÍA'}];
const maps={version:1,portal_range:48,maps:{village:world,forest,crypt}};
writeFileSync(new URL('../shared/world.json',import.meta.url),JSON.stringify(world,null,2)+'\n');
writeFileSync(new URL('../shared/maps.json',import.meta.url),JSON.stringify(maps,null,2)+'\n');
console.log('Generated three original connected map geometries');
