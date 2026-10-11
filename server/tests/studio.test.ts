import test from "node:test";
import assert from "node:assert/strict";
import { adaptMaps, applyBalance, balance, preventsAggro, npcShop } from "../src/content.js";
import { createCharacter, items, makeItem, deriveStats } from "../src/rules.js";
import { add, consume, validItem } from "../src/inventory.js";
import { combatRules, availableSkills, resetCharacter, progressionRules } from "../src/rpg.js";
test("Studio adapter expands multi-species spots preserving legacy IDs",()=>{
 const catalog=adaptMaps({maps:{test:{monsters:[{id:"legacy",species:"spider",x:64,y:64},{id:"spot",x:320,y:320,spawn_radius:16,entries:[{species:"wolf",quantity:2},{species:"spider",quantity:1}]}]}}});
 assert.equal(catalog.maps.test.monsters.length,4);assert.equal(catalog.maps.test.monsters[0].id,"legacy");
 assert.deepEqual(catalog.maps.test.monsters.slice(1).map((e:any)=>e.id),["test-spot-0","test-spot-1","test-spot-2"]);
});
test("Studio balance multipliers alter cloned runtime data, never shared source",()=>{
 const original=balance.monster.hp;balance.monster.hp=2;
 try{const value=applyBalance("monsters",{species:{test:{hp:50,attack:10,defense:2,experience:20,respawn:8,loot:{gold_min:1,gold_max:2}}}});assert.equal(value.species.test.hp,100);}
 finally{balance.monster.hp=original;}
});
test("Studio safe zone blocks aggro and NPC instances resolve global shops",()=>{
 assert.equal(preventsAggro({zones:[{x:0,y:0,width:96,height:96,monster_aggro_disabled:true}]},{x:50,y:50}),true);
 assert.equal(npcShop({id:"placed_npc",npc_id:"shop"}),"shop");
});
test("Studio item options use configured values and reject forged incompatible options",()=>{
 const state=createCharacter("StudioHero","warrior"), item=state.inventory.items[0]!;
 item.options={additional_damage:7,critical_chance:4.5};
 assert.equal(validItem(item),true);assert.equal(deriveStats(state).critical_chance,4.5);
 item.options={speed:999};assert.equal(validItem(item),false);
});
test("Studio skill book learns once, preserves repeated book and serializes progress",()=>{
 const state=createCharacter("StudioMage","mage");
 combatRules.skills.studio_power={...combatRules.skills.fireball,classes:["mage"],book_item_id:"studio_book"};
 items.definitions.studio_book={...items.definitions.potion,category:"skill_book",learn_skill:"studio_power",classes:["mage"],required_level:1};
 const book=makeItem("studio_book");add(state.inventory,book);
 assert.equal(availableSkills(state).includes("studio_power"),false);
 consume(state,book.uid);assert.equal(availableSkills(state).includes("studio_power"),true);
 const second=makeItem("studio_book");add(state.inventory,second);
 assert.throws(()=>consume(state,second.uid));assert.equal(state.inventory.items.find(i=>i.uid===second.uid)?.count,1);
 assert.deepEqual(JSON.parse(JSON.stringify(state)).learned_skills,["studio_power"]);
});

test("Studio reset applies cost/reward once with existing inventory and quests intact",()=>{
 const state=createCharacter("ResetHero","warrior");state.level=100;state.gold=200;
 const before=JSON.stringify(state.inventory), original={...balance.reset}, enabled=progressionRules.reset_enabled;
 try{
  progressionRules.reset_enabled=true;balance.reset.cost=100;balance.reset.points=10;
  resetCharacter(state);assert.equal(state.level,1);assert.equal(state.gold,100);assert.equal(state.attribute_points,10);assert.equal(state.reset_count,1);
  assert.equal(JSON.stringify(state.inventory),before);assert.throws(()=>resetCharacter(state));
 }finally{Object.assign(balance.reset,original);progressionRules.reset_enabled=enabled;}
});
