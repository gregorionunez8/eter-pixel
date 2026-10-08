import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { randomUUID } from "node:crypto";
import type { AuthoritativeWorld } from "./world.js";
import { Rejected } from "./store.js";
import { add, find, remove, refresh } from "./inventory.js";
import { economyRules } from "./economy.js";
import type { Character } from "./rules.js";
export const socialRules = JSON.parse(
  readFileSync(resolve("../shared/social.json"), "utf8"),
);
type Party = { id: string; leader: string; members: string[] };
type Invite = { from: string; expires: number };
type Offer = { uids: string[]; gold: number; fingerprints: string[] };
type Trade = {
  id: string;
  from: string;
  members: string[];
  phase: "invited" | "open";
  offers: Record<string, Offer>;
  revision: number;
  accepted: string[];
  expires: number;
};
export class Social {
  readonly active = new Set<string>();
  readonly parties = new Map<string, Party>();
  readonly invitations = new Map<string, Invite>();
  readonly trades = new Map<string, Trade>();
  private chatTimes = new Map<string, number>();
  private sequence = 0;
  constructor(
    private world: AuthoritativeWorld,
    private now: () => number = Date.now,
  ) {}
  join(id: string) {
    this.active.add(id);
  }
  private actor(id: string) {
    const actor = this.world.players.get(id);
    if (!actor || !this.active.has(id)) throw new Rejected("not_connected");
    return actor;
  }
  chat(id: string, channel: unknown, text: unknown) {
    const actor = this.actor(id);
    if (
      !["global", "local"].includes(channel as string) ||
      typeof text !== "string" ||
      !text.trim() ||
      text.length > socialRules.chat_max_length ||
      /[\x00-\x1f\x7f]/.test(text)
    )
      throw new Rejected("invalid_chat");
    const now = this.now();
    if (
      now - (this.chatTimes.get(id) ?? -Infinity) <
      socialRules.chat_interval_ms
    )
      throw new Rejected("chat_rate");
    this.chatTimes.set(id, now);
    const recipients = [...this.active].filter((other) => {
      const state = this.actor(other).state;
      return (
        channel === "global" ||
        (state.map_id === actor.state.map_id &&
          Math.hypot(
            state.position.x - actor.state.position.x,
            state.position.y - actor.state.position.y,
          ) <= socialRules.local_range)
      );
    });
    return {
      recipients,
      message: {
        sequence: ++this.sequence,
        channel,
        sender_id: id,
        sender: actor.state.name,
        message: text.trim(),
      },
    };
  }
  partyFor(id: string) {
    return [...this.parties.values()].find((p) => p.members.includes(id));
  }
  inviteParty(id: string, target: string) {
    this.actor(id);
    this.actor(target);
    this.reconcile();
    const party = this.partyFor(id);
    if (
      id === target ||
      this.partyFor(target) ||
      (party &&
        (party.leader !== id ||
          party.members.length >= socialRules.party_max)) ||
      this.invitations.has(target)
    )
      throw new Rejected("party_unavailable");
    this.invitations.set(target, {
      from: id,
      expires: this.now() + socialRules.invite_seconds * 1000,
    });
  }
  replyParty(id: string, accept: boolean) {
    this.actor(id);
    this.reconcile();
    const invite = this.invitations.get(id);
    if (!invite) throw new Rejected("invitation_missing");
    if (!accept) {
      this.invitations.delete(id);
      return;
    }
    this.actor(invite.from);
    const current = this.partyFor(invite.from);
    if (
      this.partyFor(id) ||
      (current &&
        (current.leader !== invite.from ||
          current.members.length >= socialRules.party_max))
    )
      throw new Rejected("party_unavailable");
    const party = current ?? {
      id: randomUUID(),
      leader: invite.from,
      members: [invite.from],
    };
    party.members.push(id);
    this.parties.set(party.id, party);
    this.invitations.delete(id);
  }
  leaveParty(id: string) {
    const party = this.partyFor(id);
    if (!party) return;
    party.members = party.members.filter((member) => member !== id);
    if (!party.members.length) this.parties.delete(party.id);
    else if (party.leader === id) party.leader = party.members[0];
  }
  tradeFor(id: string) {
    return [...this.trades.values()].find((t) => t.members.includes(id));
  }
  private nearby(first: string, second: string) {
    const a = this.actor(first).state,
      b = this.actor(second).state;
    return (
      a.hp > 0 &&
      b.hp > 0 &&
      a.map_id === b.map_id &&
      Math.hypot(a.position.x - b.position.x, a.position.y - b.position.y) <=
        socialRules.trade_range &&
      this.world.combat.visible(a.position, b.position, a.map_id)
    );
  }
  inviteTrade(id: string, target: string) {
    this.reconcile();
    if (
      id === target ||
      this.tradeFor(id) ||
      this.tradeFor(target) ||
      !this.nearby(id, target)
    )
      throw new Rejected("trade_unavailable");
    const empty = () => ({ uids: [], gold: 0, fingerprints: [] });
    const trade: Trade = {
      id: randomUUID(),
      from: id,
      members: [id, target],
      phase: "invited",
      offers: { [id]: empty(), [target]: empty() },
      revision: 0,
      accepted: [],
      expires: this.now() + socialRules.invite_seconds * 1000,
    };
    this.trades.set(trade.id, trade);
  }
  replyTrade(id: string, accept: boolean) {
    this.reconcile();
    const trade = this.tradeFor(id);
    if (!trade || trade.phase !== "invited" || trade.from === id)
      throw new Rejected("trade_invitation_missing");
    if (!accept) {
      this.trades.delete(trade.id);
      return;
    }
    trade.phase = "open";
    trade.revision++;
    trade.expires = this.now() + socialRules.trade_seconds * 1000;
  }
  private openTrade(id: string, revision: number) {
    this.actor(id);
    this.reconcile();
    const trade = this.tradeFor(id);
    if (!trade || trade.phase !== "open") throw new Rejected("trade_missing");
    if (!Number.isSafeInteger(revision) || revision !== trade.revision)
      throw new Rejected("trade_revision");
    return trade;
  }
  offer(id: string, uids: unknown, gold: unknown, revision: number) {
    const trade = this.openTrade(id, revision),
      state = this.actor(id).state;
    if (
      !Array.isArray(uids) ||
      uids.length > socialRules.trade_max_items ||
      uids.some((uid) => typeof uid !== "string") ||
      new Set(uids).size !== uids.length ||
      !Number.isSafeInteger(gold) ||
      (gold as number) < 0 ||
      (gold as number) > state.gold
    )
      throw new Rejected("invalid_offer");
    const fingerprints = uids.map((uid) => {
      const item = find(state.inventory, uid);
      if (Object.values(state.inventory.equipment).includes(uid))
        throw new Rejected("equipped_offer");
      return JSON.stringify(item);
    });
    trade.offers[id] = { uids: [...uids], gold: gold as number, fingerprints };
    trade.revision++;
    trade.accepted = [];
  }
  accept(id: string, revision: number) {
    const trade = this.openTrade(id, revision);
    if (trade.accepted.includes(id)) throw new Rejected("already_accepted");
    if (!trade.accepted.length) {
      trade.accepted.push(id);
      return { ready: false, trade_id: trade.id };
    }
    // Final confirmation is only recorded when the SQL transaction succeeds.
    return { ready: true, trade_id: trade.id };
  }
  exchange(tradeId: string) {
    const trade = this.trades.get(tradeId);
    if (
      !trade ||
      trade.phase !== "open" ||
      trade.accepted.length !== 1 ||
      !this.validTrade(trade)
    )
      throw new Rejected("trade_changed");
    const drafts = new Map<string, Character>();
    const outgoing = new Map<string, ReturnType<typeof remove>[]>();
    for (const id of trade.members) {
      const state = structuredClone(this.actor(id).state),
        offer = trade.offers[id];
      outgoing.set(
        id,
        offer.uids.map((uid) => remove(state.inventory, uid)),
      );
      state.gold -= offer.gold;
      drafts.set(id, state);
    }
    for (const id of trade.members) {
      const other = trade.members.find((member) => member !== id)!,
        state = drafts.get(id)!;
      state.gold += trade.offers[other].gold;
      if (state.gold > economyRules.gold_cap) throw new Rejected("gold_cap");
      for (const item of outgoing.get(other)!) add(state.inventory, item);
      refresh(state);
    }
    for (const [id, state] of drafts) this.actor(id).state = state;
  }
  complete(tradeId: string) {
    this.trades.delete(tradeId);
  }
  cancel(id: string) {
    const trade = this.tradeFor(id);
    if (trade) this.trades.delete(trade.id);
  }
  private validTrade(trade: Trade) {
    if (trade.expires <= this.now()) return false;
    try {
      if (!this.nearby(trade.members[0], trade.members[1])) return false;
      for (const id of trade.members) {
        const state = this.actor(id).state,
          offer = trade.offers[id];
        if (state.gold < offer.gold) return false;
        for (let i = 0; i < offer.uids.length; i++)
          if (
            Object.values(state.inventory.equipment).includes(offer.uids[i]) ||
            JSON.stringify(find(state.inventory, offer.uids[i])) !==
              offer.fingerprints[i]
          )
            return false;
      }
      return true;
    } catch {
      return false;
    }
  }
  reconcile() {
    for (const [id, invite] of this.invitations)
      if (
        invite.expires <= this.now() ||
        !this.active.has(invite.from) ||
        this.partyFor(id)
      )
        this.invitations.delete(id);
    for (const [id, trade] of this.trades)
      if (!this.validTrade(trade)) this.trades.delete(id);
  }
  remove(id: string) {
    this.active.delete(id);
    this.chatTimes.delete(id);
    this.leaveParty(id);
    this.cancel(id);
    this.invitations.delete(id);
    for (const [target, invite] of this.invitations)
      if (invite.from === id) this.invitations.delete(target);
  }
  snapshot(id: string) {
    const publicActor = (other: string) => {
      const state = this.actor(other).state;
      return {
        id: other,
        name: state.name,
        class_id: state.class_id,
        level: state.level,
        hp: state.hp,
        max_hp: state.stats.max_hp,
      };
    };
    const party = this.partyFor(id),
      invite = this.invitations.get(id),
      trade = this.tradeFor(id);
    return {
      players: [...this.active].map(publicActor),
      party: party
        ? {
            id: party.id,
            leader: party.leader,
            members: party.members.map(publicActor),
          }
        : null,
      invitation: invite
        ? {
            from: invite.from,
            name: this.actor(invite.from).state.name,
            expires: invite.expires,
          }
        : null,
      trade: trade
        ? {
            id: trade.id,
            from: trade.from,
            phase: trade.phase,
            revision: trade.revision,
            accepted: [...trade.accepted],
            expires: trade.expires,
            offers: trade.members.map((member) => ({
              id: member,
              name: this.actor(member).state.name,
              gold: trade.offers[member].gold,
              items: trade.offers[member].uids.map((uid) =>
                structuredClone(find(this.actor(member).state.inventory, uid)),
              ),
            })),
          }
        : null,
    };
  }
}
