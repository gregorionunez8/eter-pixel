// Original, deterministic ÉTER assets, no remote dependencies.
import {mkdirSync,writeFileSync} from 'node:fs';
import {deflateSync} from 'node:zlib';
import {fileURLToPath} from 'node:url';
const output=fileURLToPath(new URL('../client/assets/',import.meta.url));mkdirSync(output,{recursive:true});
const P={ink:'#111522',shadow:'#202838',stone:'#424e5a',light:'#75828b',moss:'#304638',grass:'#46634b',wood:'#49352e',copper:'#9f6044',gold:'#d5aa64',ether:'#64c8cf',skin:'#c59a79'};
function crc32(bytes){let c=0xffffffff;for(const b of bytes){c^=b;for(let j=0;j<8;j++)c=(c>>>1)^((c&1)?0xedb88320:0);}return(c^0xffffffff)>>>0;}
function chunk(type,data){const t=Buffer.from(type),n=Buffer.alloc(4),crc=Buffer.alloc(4);n.writeUInt32BE(data.length);crc.writeUInt32BE(crc32(Buffer.concat([t,data])));return Buffer.concat([n,t,data,crc]);}
class Canvas{
 constructor(w,h){this.w=w;this.h=h;this.data=Buffer.alloc(w*h*4);}
 pixel(x,y,c,a=255){x=Math.floor(x);y=Math.floor(y);if(x<0||y<0||x>=this.w||y>=this.h)return;const i=(y*this.w+x)*4,v=parseInt(c.slice(1),16);this.data[i]=v>>16;this.data[i+1]=(v>>8)&255;this.data[i+2]=v&255;this.data[i+3]=a;}
 rect(x,y,w,h,c,a=255){for(let yy=y;yy<y+h;yy++)for(let xx=x;xx<x+w;xx++)this.pixel(xx,yy,c,a);}
 ellipse(x,y,rx,ry,c,a=255){for(let yy=y-ry;yy<=y+ry;yy++)for(let xx=x-rx;xx<=x+rx;xx++)if(((xx-x)/rx)**2+((yy-y)/ry)**2<=1)this.pixel(xx,yy,c,a);}
 line(x,y,xx,yy,c){const n=Math.max(Math.abs(xx-x),Math.abs(yy-y));for(let i=0;i<=n;i++)this.pixel(x+(xx-x)*i/n,y+(yy-y)*i/n,c);}
 save(name){const h=Buffer.alloc(13);h.writeUInt32BE(this.w);h.writeUInt32BE(this.h,4);h[8]=8;h[9]=6;const rows=Buffer.alloc((this.w*4+1)*this.h);for(let y=0;y<this.h;y++)this.data.copy(rows,y*(this.w*4+1)+1,y*this.w*4,(y+1)*this.w*4);writeFileSync(output+name+'.png',Buffer.concat([Buffer.from([137,80,78,71,13,10,26,10]),chunk('IHDR',h),chunk('IDAT',deflateSync(rows)),chunk('IEND',Buffer.alloc(0))]));}
}
let seed=1909;const random=()=>{seed=(Math.imul(seed,1664525)+1013904223)>>>0;return seed/2**32;};
const atlas=new Canvas(128,32);
for(let t=0;t<4;t++){const x=t*32;atlas.rect(x,0,32,32,[P.moss,'#655545',P.stone,'#243f49'][t]);for(let j=0;j<80;j++)atlas.rect(x+Math.floor(random()*32),Math.floor(random()*32),1+Math.floor(random()*3),1,[P.grass,'#796654','#56636e','#355d66'][t]);if(t===2)for(let y=0;y<32;y+=8){atlas.rect(x,y,32,1,P.shadow);for(let xx=y%16?8:0;xx<32;xx+=16)atlas.rect(x+xx,y,1,8,P.shadow);}}atlas.save('terrain');
const tree=new Canvas(64,80);tree.ellipse(32,69,24,7,P.ink,110);tree.rect(27,39,10,31,P.ink);tree.rect(29,39,6,29,P.wood);tree.rect(30,43,2,24,P.copper);
for(const[x,y,rx,ry]of[[21,29,17,20],[43,29,17,20],[32,15,18,14],[31,40,25,17]]){tree.ellipse(x,y,rx+1,ry+1,P.ink);tree.ellipse(x,y,rx,ry,P.moss);tree.ellipse(x-3,y-5,rx-4,ry-5,P.grass);}for(let j=0;j<95;j++){const x=Math.floor(7+random()*48),y=Math.floor(6+random()*44);if(tree.data[(y*64+x)*4+3])tree.rect(x,y,2,1,random()>.6?'#68805a':P.moss);}tree.save('tree');
for(const type of['house','smith','shop']){
 const c=new Canvas(128,128);c.ellipse(64,113,61,11,P.ink,110);c.rect(7,26,114,90,P.ink);c.rect(11,30,106,82,P.stone);
 for(let y=34;y<111;y+=9){c.rect(12,y,104,1,P.shadow);for(let x=y%18?14:22;x<114;x+=16)c.rect(x,y,1,9,P.shadow);}
 c.rect(4,8,120,88,P.ink);c.rect(8,12,112,80,type==='shop'?'#3b5d65':'#633f38');
 for(let y=15;y<90;y+=6){c.rect(9,y,110,1,'#9b6450');for(let x=y%12?12:17;x<117;x+=10){c.rect(x,y,1,6,'#412d30');c.rect(x+2,y+1,5,1,'#835346');}}
 c.rect(8,50,112,4,P.ink);c.rect(10,50,108,1,P.copper);c.rect(57,14,12,76,P.wood);c.rect(58,14,2,76,P.copper);c.rect(49,94,30,20,P.ink);c.rect(52,94,24,20,P.wood);
 for(let x=55;x<76;x+=5)c.rect(x,96,1,17,P.copper);c.rect(70,104,2,2,P.gold);for(const x of[20,91]){c.rect(x,98,17,11,P.ink);c.rect(x+2,100,13,7,P.gold);c.rect(x+8,99,1,10,P.wood);}
 c.rect(96,2,17,30,P.ink);c.rect(98,4,13,26,P.stone);c.rect(97,2,15,5,P.light);
 if(type==='smith'){c.rect(8,97,27,19,P.ink);c.rect(11,100,21,12,'#a2462d');c.rect(14,102,15,8,'#e49a47');c.rect(17,104,9,5,'#f6d87b');}if(type==='shop'){c.rect(83,98,35,5,P.wood);c.rect(84,99,33,2,P.ether);}c.save(type);
}
const shrine=new Canvas(96,96);shrine.ellipse(48,75,44,13,P.ink,140);shrine.ellipse(48,61,42,25,P.ink);shrine.ellipse(48,59,38,22,P.light);shrine.ellipse(48,58,33,18,P.stone);shrine.ellipse(48,57,29,15,'#243f49');shrine.ellipse(48,55,25,12,'#355d66');
for(let i=0;i<25;i++)shrine.rect(25+random()*46,50+random()*12,3,1,P.ether);shrine.rect(38,40,21,19,P.ink);shrine.rect(40,42,17,13,P.stone);for(let y=10;y<49;y++){const w=Math.floor(2+Math.sin((y-10)/39*Math.PI)*9);shrine.rect(48-w,y,w*2,1,P.ink);shrine.rect(50-w,y,w*2-4,1,P.ether);shrine.rect(48,y,3,1,'#b1e6df');}shrine.save('shrine');
const wall=new Canvas(32,48);wall.rect(0,17,32,30,P.ink);wall.rect(1,18,30,26,P.stone);wall.rect(1,18,30,3,P.light);for(let y=25;y<44;y+=7){wall.rect(1,y,30,1,P.shadow);wall.rect(y%2?8:20,y,1,7,P.shadow);}wall.save('wall');
for(const characterClass of ['warrior','mage','elf']) {
const actor=new Canvas(128,384);
const armor=characterClass==='mage'?'#554b83':characterClass==='elf'?'#527357':P.stone;
const armorLight=characterClass==='mage'?'#8175a8':characterClass==='elf'?'#82a26b':P.light;
for(let d=0;d<8;d++)for(let f=0;f<4;f++){
 const x=f*32+16,y=d*48,b=f===2?-1:0,s=f===1?2:f===3?-2:0;
 actor.ellipse(x,y+42,11,4,P.ink,100);actor.rect(x-7,y+29+b,5,11+s,P.ink);actor.rect(x+2,y+29+b,5,11-s,P.ink);actor.rect(x-6,y+30+b,3,8+s,P.wood);actor.rect(x+3,y+30+b,3,8-s,P.wood);
 actor.rect(x-8,y+15+b,16,20,P.ink);actor.rect(x-6,y+17+b,12,15,armor);actor.rect(x-5,y+18+b,3,12,armorLight);actor.rect(x-7,y+29+b,14,3,P.wood);actor.rect(x-1,y+29+b,3,2,P.gold);
 actor.rect(x-11,y+18+b+s,4,12,P.ink);actor.rect(x+7,y+18+b-s,4,12,P.ink);actor.rect(x-10,y+18+b+s,2,7,P.light);actor.rect(x+8,y+18+b-s,2,7,P.stone);actor.rect(x-10,y+27+b+s,2,2,P.skin);actor.rect(x+8,y+27+b-s,2,2,P.skin);
 actor.ellipse(x,y+11+b,7,8,P.ink);actor.ellipse(x,y+10+b,6,6,armorLight);actor.rect(x-4,y+4+b,8,4,armor);actor.rect(x-1,y+4+b,2,7,armorLight);const back=d>=5;actor.rect(x-4,y+12+b,8,4,back?armor:P.skin);if(!back){const e=d<=1?2:d>=3?-2:0;actor.rect(x-3+e,y+12+b,2,1,P.ink);actor.rect(x+2+e,y+12+b,2,1,P.ink);}
 if(characterClass==='warrior'){actor.line(x+11,y+13+b,x+11,y+30+b,P.light);actor.rect(x+8,y+27+b,7,2,P.gold);}
 if(characterClass==='mage'){actor.rect(x-7,y+32+b,14,7,P.ink);actor.rect(x-6,y+32+b,12,5,armor);actor.rect(x-4,y+33+b,2,4,armorLight);actor.line(x+11,y+10+b,x+11,y+38+b,P.copper);actor.ellipse(x+11,y+9+b,3,3,P.ink);actor.ellipse(x+11,y+9+b,2,2,P.ether);actor.rect(x-5,y+6+b,10,4,armor);}
 if(characterClass==='elf'){actor.rect(x-7,y+6+b,3,11,P.gold);actor.rect(x+5,y+6+b,3,11,P.gold);actor.ellipse(x+10,y+23+b,4,11,P.copper);actor.ellipse(x+10,y+23+b,2,9,P.ink,0);actor.line(x+10,y+12+b,x+10,y+34+b,P.gold);}
}actor.save(characterClass);if(characterClass==='warrior')actor.save('traveler');
}
const dummy=new Canvas(48,64);dummy.ellipse(24,56,18,5,P.ink,110);dummy.rect(20,22,8,34,P.ink);dummy.rect(22,23,4,31,P.copper);dummy.rect(5,26,38,8,P.ink);dummy.rect(7,28,34,4,P.wood);dummy.ellipse(24,18,9,10,P.ink);dummy.ellipse(24,18,7,8,P.gold);dummy.rect(18,15,3,2,P.ink);dummy.rect(27,15,3,2,P.ink);dummy.rect(23,20,2,3,P.copper);dummy.rect(15,25,18,20,P.ink);dummy.rect(17,27,14,16,'#927e50');dummy.rect(18,31,12,2,P.wood);dummy.rect(23,27,2,16,P.copper);dummy.save('training');
console.log('Generated 12 original PNG assets, including three class sheets and training effigy');
