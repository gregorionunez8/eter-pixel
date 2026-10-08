import type { AuthoritativeWorld } from "./world.js";
import { geometry, type Point } from "./navigation.js";
import {
  combatRules,
  species,
  hit,
  gainExperience,
  deathPenalty,
  derive,
} from "./rpg.js";
import { Rejected } from "./store.js";
export type Enemy = {
  id: string;
  species: string;
  training: boolean;
  config: any;
  hp: number;
  home: Point;
  position: Point;
  phase: string;
  target?: string;
  path: Point[];
  detect: number;
  attack: number;
  respawn: number;
  repath: number;
};
type Battle = {
  selected?: string;
  auto: number;
  chase: number;
  regen: number;
  sinceDamage: number;
  respawn: number;
  cooldowns: Record<string, number>;
};
const distance = (a: Point, b: Point) => Math.hypot(a.x - b.x, a.y - b.y);
export class CombatSimulation {
  readonly enemies = new Map<string, Enemy>();
  readonly battles = new Map<string, Battle>();
  readonly events: any[] = [];
  private sequence = 0;
  onDefeated?: (killer: string, enemy: Enemy) => void;
  constructor(
    private world: AuthoritativeWorld,
    private random: () => number = Math.random,
  ) {
    for (const [index, entry] of geometry.monsters.entries())
      this.addEnemy("monster-" + index, entry.species, entry, false);
    for (const x of [22, 24, 26])
      this.addEnemy(
        "training-" + x,
        "training",
        { x: x * 32 + 16, y: 27 * 32 + 16 },
        true,
      );
  }
  private addEnemy(id: string, name: string, home: Point, training: boolean) {
    const c = training
      ? {
          ...combatRules.training_target.stats,
          hp: combatRules.training_target.hp,
          experience: 0,
          radius: 7,
          speed: 0,
          detect_radius: 0,
          leash_radius: 0,
          attack_range: combatRules.training_target.retaliation_range,
          attack_interval: combatRules.training_target.retaliation_interval,
          respawn: combatRules.target_respawn_seconds,
        }
      : species[name];
    this.enemies.set(id, {
      id,
      species: name,
      training,
      config: c,
      hp: c.hp,
      home: { x: home.x, y: home.y },
      position: { x: home.x, y: home.y },
      phase: "idle",
      path: [],
      detect: 0,
      attack: 0,
      respawn: 0,
      repath: 0,
    });
  }
  join(id: string) {
    const actor = this.world.players.get(id)!;
    actor.state.stats = derive(actor.state);
    const runtime = (actor.state.combat_state ??= {
      cooldown_deadlines: {},
      respawn_deadline: 0,
      regeneration_deadline: 0,
    });
    const remaining = (deadline: number) =>
      Math.max(0, (deadline - Date.now()) / 1000);
    this.battles.set(id, {
      auto: 0,
      chase: 0,
      regen: 0,
      sinceDamage: runtime.regeneration_deadline
        ? Math.max(
            0,
            combatRules.regeneration_delay -
              remaining(runtime.regeneration_deadline),
          )
        : 0,
      respawn:
        actor.state.hp <= 0
          ? runtime.respawn_deadline
            ? remaining(runtime.respawn_deadline)
            : combatRules.player_respawn_seconds
          : 0,
      cooldowns: Object.fromEntries(
        Object.entries(runtime.cooldown_deadlines).map(([skill, deadline]) => [
          skill,
          remaining(deadline),
        ]),
      ),
    });
  }
  remove(id: string) {
    this.battles.delete(id);
    for (const enemy of this.enemies.values())
      if (enemy.target === id) enemy.target = undefined;
  }
  private syncRuntime(id: string, battle: Battle) {
    const actor = this.world.players.get(id);
    if (!actor) return;
    const now = Date.now();
    actor.state.combat_state = {
      cooldown_deadlines: Object.fromEntries(
        Object.entries(battle.cooldowns)
          .filter(([, left]) => left > 0)
          .map(([skill, left]) => [skill, now + left * 1000]),
      ),
      respawn_deadline:
        actor.state.hp <= 0 ? now + Math.max(0, battle.respawn) * 1000 : 0,
      regeneration_deadline:
        now +
        Math.max(0, combatRules.regeneration_delay - battle.sinceDamage) * 1000,
    };
  }
  cancel(id: string) {
    const battle = this.battles.get(id);
    if (battle) battle.selected = undefined;
  }
  private event(kind: string, data: Record<string, unknown>) {
    this.events.push({ sequence: ++this.sequence, kind, ...data });
    if (this.events.length > 128) this.events.shift();
  }
  visible(a: Point, b: Point) {
    const steps = Math.ceil(distance(a, b) / 4);
    for (let step = 0; step <= steps; step++) {
      const ratio = steps ? step / steps : 0;
      if (
        !this.world.navigation.walkable(
          this.world.navigation.cellAt({
            x: a.x + (b.x - a.x) * ratio,
            y: a.y + (b.y - a.y) * ratio,
          }),
        )
      )
        return false;
    }
    return true;
  }
  select(id: string, targetId: string) {
    const actor = this.world.players.get(id),
      battle = this.battles.get(id);
    if (!actor || !battle) throw new Rejected("not_in_world");
    if (actor.state.hp <= 0) throw new Rejected("dead");
    if (targetId === "") {
      battle.selected = undefined;
      return;
    }
    const target = this.enemies.get(targetId);
    if (!target || target.hp <= 0) throw new Rejected("invalid_target");
    battle.selected = targetId;
  }
  cast(id: string, skillId: string) {
    const actor = this.world.players.get(id),
      battle = this.battles.get(id);
    if (!actor || !battle) throw new Rejected("not_in_world");
    if (actor.state.hp <= 0) throw new Rejected("dead");
    if (!combatRules.classes[actor.state.class_id].skills.includes(skillId))
      throw new Rejected("invalid_skill");
    const skill = combatRules.skills[skillId];
    if ((battle.cooldowns[skillId] ?? 0) > 0) throw new Rejected("cooldown");
    if (actor.state.mana < skill.mana) throw new Rejected("insufficient_mana");
    let victims: Enemy[] = [];
    if (skill.mode === "single") {
      const target = this.enemies.get(battle.selected ?? "");
      if (
        !target ||
        target.hp <= 0 ||
        distance(actor.state.position, target.position) > skill.range ||
        !this.visible(actor.state.position, target.position)
      )
        throw new Rejected("out_of_range");
      victims = [target];
    } else if (skill.mode === "area" || skill.mode === "multiple") {
      victims = [...this.enemies.values()].filter(
        (target) =>
          target.hp > 0 &&
          distance(actor.state.position, target.position) <= skill.range &&
          this.visible(actor.state.position, target.position),
      );
      if (!victims.length) throw new Rejected("no_targets");
      if (skill.mode === "multiple")
        victims = victims.slice(0, skill.max_targets);
    }
    actor.state.mana -= skill.mana;
    battle.cooldowns[skillId] = skill.cooldown;
    this.syncRuntime(id, battle);
    if (skill.mode === "heal")
      actor.state.hp = Math.min(
        Number(actor.state.stats.max_hp),
        actor.state.hp +
          Math.floor(Number(actor.state.stats.max_hp) * skill.heal_fraction),
      );
    this.event("skill", {
      actor: id,
      skill: skillId,
      position: { ...actor.state.position },
    });
    for (const victim of victims)
      this.damageEnemy(
        id,
        victim,
        skill.multiplier,
        skill.damage_type,
        skill.effect,
      );
  }
  private wear(id: string, slot: string) {
    const state = this.world.players.get(id)!.state;
    const uid = (state.inventory.equipment as Record<string, string>)[slot];
    const item = state.inventory.items.find((item) => item.uid === uid);
    if (item) {
      item.durability = Math.max(0, item.durability - 1);
      state.stats = derive(state);
    }
  }
  private damageEnemy(
    id: string,
    enemy: Enemy,
    multiplier: number,
    kind: string,
    effect: string,
  ) {
    if (enemy.hp <= 0) return;
    const actor = this.world.players.get(id)!;
    const result = hit(
      actor.state.stats,
      enemy.config,
      kind,
      multiplier,
      this.random(),
      this.random(),
    );
    enemy.hp = Math.max(0, enemy.hp - result.damage);
    this.event("hit", {
      actor: id,
      target: enemy.id,
      ...result,
      effect,
      position: { ...enemy.position },
    });
    if (result.damage > 0) this.wear(id, "weapon");
    if (enemy.hp === 0) {
      enemy.phase = "dying";
      enemy.respawn = enemy.config.respawn;
      enemy.path = [];
      enemy.target = undefined;
      for (const battle of this.battles.values())
        if (battle.selected === enemy.id) battle.selected = undefined;
      if (!enemy.training) {
        gainExperience(actor.state, enemy.config.experience);
        this.onDefeated?.(id, enemy);
      }
      this.event("defeated", {
        target: enemy.id,
        killer: id,
        experience: enemy.config.experience,
      });
    } else if (result.damage > 0 && !enemy.training && enemy.phase === "idle") {
      enemy.target = id;
      enemy.phase = "detect";
      enemy.detect = 0.15;
    }
  }
  private damagePlayer(enemy: Enemy, id: string) {
    const actor = this.world.players.get(id),
      battle = this.battles.get(id);
    if (!actor || !battle || actor.state.hp <= 0) return;
    const result = hit(
      enemy.config,
      actor.state.stats,
      "physical",
      1,
      this.random(),
      this.random(),
    );
    actor.state.hp = Math.max(0, actor.state.hp - result.damage);
    this.event("hit", {
      actor: enemy.id,
      target: id,
      ...result,
      effect: "slash",
      position: { ...actor.state.position },
    });
    if (!result.miss) battle.sinceDamage = 0;
    if (result.damage > 0) this.wear(id, "armor");
    if (actor.state.hp === 0) {
      battle.respawn = combatRules.player_respawn_seconds;
      battle.selected = undefined;
      actor.path = [];
      this.event("player_death", {
        target: id,
        lost_experience: deathPenalty(actor.state),
      });
    }
    this.syncRuntime(id, battle);
  }
  private follow(enemy: Enemy, point: Point, delta: number) {
    enemy.repath -= delta;
    if (enemy.repath <= 0) {
      enemy.repath = 0.3;
      const route = this.world.navigation.findPath(enemy.position, point);
      if (
        !enemy.path.length ||
        !route.length ||
        distance(enemy.path.at(-1)!, route.at(-1)!) > 0
      )
        enemy.path = route;
    }
    let budget = enemy.config.speed * delta;
    while (enemy.path.length && budget > 0) {
      const target = enemy.path[0],
        length = distance(enemy.position, target);
      if (length < 0.001) {
        enemy.path.shift();
        continue;
      }
      const moved = Math.min(length, budget, 7),
        ratio = moved / length;
      const next = {
        x: enemy.position.x + (target.x - enemy.position.x) * ratio,
        y: enemy.position.y + (target.y - enemy.position.y) * ratio,
      };
      if (!this.world.navigation.safe(next, enemy.config.radius)) {
        enemy.path = [];
        break;
      }
      enemy.position = next;
      budget -= moved;
      if (moved === length) enemy.path.shift();
    }
  }
  step(delta: number) {
    for (const [id, battle] of this.battles) {
      const actor = this.world.players.get(id)!;
      battle.auto = Math.max(0, battle.auto - delta);
      battle.chase = Math.max(0, battle.chase - delta);
      for (const skill in battle.cooldowns)
        battle.cooldowns[skill] = Math.max(0, battle.cooldowns[skill] - delta);
      if (actor.state.hp <= 0) {
        battle.respawn -= delta;
        if (battle.respawn <= 0) {
          actor.state.position = { ...geometry.spawn };
          actor.state.hp = Number(actor.state.stats.max_hp);
          actor.state.mana = Number(actor.state.stats.max_mana);
          this.event("player_respawn", { target: id });
        }
        continue;
      }
      battle.sinceDamage += delta;
      battle.regen += delta;
      if (battle.regen >= combatRules.regeneration_interval) {
        battle.regen = 0;
        if (battle.sinceDamage >= combatRules.regeneration_delay) {
          actor.state.hp = Math.min(
            Number(actor.state.stats.max_hp),
            actor.state.hp +
              Math.max(
                1,
                Math.floor(
                  Number(actor.state.stats.max_hp) *
                    combatRules.hp_regeneration_fraction,
                ),
              ),
          );
          actor.state.mana = Math.min(
            Number(actor.state.stats.max_mana),
            actor.state.mana +
              Math.max(
                1,
                Math.floor(
                  Number(actor.state.stats.max_mana) *
                    combatRules.mana_regeneration_fraction,
                ),
              ),
          );
        }
      }
      const target = this.enemies.get(battle.selected ?? "");
      if (!target || target.hp <= 0) continue;
      const config = combatRules.classes[actor.state.class_id];
      if (
        distance(actor.state.position, target.position) <= config.auto_range &&
        this.visible(actor.state.position, target.position)
      ) {
        actor.path = [];
        if (battle.auto <= 0) {
          battle.auto = config.auto_interval;
          this.damageEnemy(
            id,
            target,
            1,
            String(actor.state.stats.damage_type),
            actor.state.class_id === "mage"
              ? "fire"
              : actor.state.class_id === "elf"
                ? "arrow"
                : "slash",
          );
        }
      } else if (battle.chase <= 0) {
        battle.chase = 0.3;
        try {
          this.world.move(id, target.position, false);
        } catch {
          /* unreachable pursuit waits for next server tick */
        }
      }
    }
    for (const enemy of this.enemies.values()) {
      enemy.attack = Math.max(0, enemy.attack - delta);
      if (enemy.hp <= 0) {
        enemy.respawn -= delta;
        enemy.phase =
          enemy.respawn <= enemy.config.respawn - 0.5 ? "respawn" : "dying";
        if (enemy.respawn <= 0) {
          enemy.hp = enemy.config.hp;
          enemy.position = { ...enemy.home };
          enemy.phase = "idle";
          this.event("enemy_respawn", { target: enemy.id });
        }
        continue;
      }
      if (enemy.training) {
        for (const [id, battle] of this.battles) {
          const actor = this.world.players.get(id)!;
          if (
            battle.selected === enemy.id &&
            actor.state.hp > 0 &&
            distance(actor.state.position, enemy.position) <=
              enemy.config.attack_range &&
            this.visible(enemy.position, actor.state.position) &&
            enemy.attack <= 0
          ) {
            enemy.attack = enemy.config.attack_interval;
            this.damagePlayer(enemy, id);
          }
        }
        continue;
      }
      const target = enemy.target
        ? this.world.players.get(enemy.target)
        : undefined;
      if (
        ["detect", "chase", "attack"].includes(enemy.phase) &&
        (!target ||
          target.state.hp <= 0 ||
          distance(enemy.home, target.state.position) >
            enemy.config.leash_radius ||
          distance(enemy.home, enemy.position) > enemy.config.leash_radius)
      ) {
        enemy.phase = "return";
        enemy.target = undefined;
        enemy.repath = 0;
      }
      switch (enemy.phase) {
        case "idle": {
          const nearby = [...this.world.players.values()]
            .filter(
              (actor) =>
                actor.state.hp > 0 &&
                distance(enemy.position, actor.state.position) <=
                  enemy.config.detect_radius &&
                this.visible(enemy.position, actor.state.position),
            )
            .sort(
              (a, b) =>
                distance(enemy.position, a.state.position) -
                distance(enemy.position, b.state.position),
            )[0];
          if (nearby) {
            enemy.target = nearby.id;
            enemy.phase = "detect";
            enemy.detect = 0.15;
          }
          break;
        }
        case "detect":
          enemy.detect -= delta;
          if (enemy.detect <= 0) {
            enemy.phase = "chase";
            enemy.repath = 0;
          }
          break;
        case "chase":
          if (target) {
            if (
              distance(enemy.position, target.state.position) <=
                enemy.config.attack_range &&
              this.visible(enemy.position, target.state.position)
            ) {
              enemy.path = [];
              enemy.phase = "attack";
            } else this.follow(enemy, target.state.position, delta);
          }
          break;
        case "attack":
          if (target) {
            if (
              distance(enemy.position, target.state.position) >
                enemy.config.attack_range ||
              !this.visible(enemy.position, target.state.position)
            ) {
              enemy.phase = "chase";
              enemy.repath = 0;
            } else if (enemy.attack <= 0) {
              enemy.attack = enemy.config.attack_interval;
              this.damagePlayer(enemy, target.id);
            }
          }
          break;
        case "return":
          if (distance(enemy.position, enemy.home) < 2) {
            enemy.position = { ...enemy.home };
            enemy.path = [];
            enemy.hp = enemy.config.hp;
            enemy.phase = "idle";
          } else this.follow(enemy, enemy.home, delta);
          break;
      }
    }
    for (const [id, battle] of this.battles) this.syncRuntime(id, battle);
  }
  snapshot() {
    return [...this.enemies.values()].map((enemy) => ({
      id: enemy.id,
      species: enemy.species,
      name: enemy.training ? "Efigie" : enemy.config.name,
      level: enemy.config.level ?? 0,
      hp: enemy.hp,
      max_hp: enemy.config.hp,
      phase: enemy.phase,
      position: { ...enemy.position },
    }));
  }
}
