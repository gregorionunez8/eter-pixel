import { readFileSync } from "node:fs";
import { resolve } from "node:path";
export const npcDefinitions=JSON.parse(readFileSync(resolve("../shared/npcs.json"),"utf8")).definitions;
/** Compatibility adapter: authoring data stays shared, legacy spawns stay unchanged. */
export function adaptMaps(catalog: any) {
  for (const [id, map] of Object.entries(catalog.maps) as [string, any][]) {
    map.id=id;
    for(const key of ['regions','labels','obstacles','npcs','portals']) map[key]??=[];
    map.monsters=map.monsters.flatMap((spot:any,index:number)=>{
      if(spot.enabled===false)return [];
      const entries=spot.entries??[{species:spot.species??'spider',quantity:spot.quantity??1}];
      const total=entries.reduce((n:number,e:any)=>n+(e.quantity??1),0);
      let sequence=0;
      return entries.flatMap((entry:any)=>Array.from({length:entry.quantity??1},()=>{
        const raw=spot.id??'monster-'+index;
        const base=(spot.quantity!==undefined || spot.entries!==undefined || spot.enabled!==undefined)?id+'-'+raw:raw;
        const angle=sequence*Math.PI*2/total;
        const result={...spot,species:entry.species,id:total>1?base+'-'+sequence:base,
          x:spot.x+(total>1?Math.cos(angle)*(spot.spawn_radius??16):0),
          y:spot.y+(total>1?Math.sin(angle)*(spot.spawn_radius??16):0)};
        delete result.entries;delete result.quantity;sequence++;return result;
      }));
    });
  }
  return catalog;
}

export function npcShop(npc: any): string { return npcDefinitions[npc.npc_id??npc.id]?.shop_id || npc.npc_id || npc.id; }

export const balance=JSON.parse(readFileSync(resolve("../shared/balance.json"),"utf8"));
export function applyBalance(name: string,value: any){
 if(name==="items")for(const slot of ["pants","wings","pet"])if(!value.slots.includes(slot))value.slots.push(slot);
 if(name==="monsters"){
  const factors=balance.monster??{};
  for(const config of Object.values(value.species) as any[]){
   for(const [key,factor] of [["hp","hp"],["attack","damage"],["defense","defense"],["experience","experience"],["respawn","respawn"]])config[key!]*=factors[factor!]??1;
   config.loot.gold_min=Math.floor(config.loot.gold_min*(factors.gold??1));
   config.loot.gold_max=Math.floor(config.loot.gold_max*(factors.gold??1));
  }
 }
 if(name==="combat"){
  const factors=balance.skill??{};
  for(const skill of Object.values(value.skills) as any[]){
   if(skill.multiplier!==undefined)skill.multiplier*=(factors.damage??1)*(factors.pve??1);
   skill.mana=Math.floor(skill.mana*(factors.mana??1));
   skill.cooldown*=factors.cooldown??1;
  }
 }
 if(name==="economy"){
  value.sell_fraction*=balance.economy?.sell_multiplier??1;
  for(const id in value.prices)value.prices[id]=Math.floor(value.prices[id]*(balance.economy?.buy_multiplier??1));
 }
 return value;
}

export function preventsAggro(map:any,point:{x:number;y:number}){
 return (map.zones??[]).some((z:any)=>z.monster_aggro_disabled && point.x>=z.x && point.y>=z.y && point.x<z.x+(z.width??96) && point.y<z.y+(z.height??96));
}
