import { once } from "node:events";
import { WebSocketServer, WebSocket } from "ws";
import { Store, Rejected } from "./store.js";
import { AuthoritativeWorld } from "./world.js";
import { allocate } from "./rpg.js";

type Request = { v: 1; id: string; op: string; data: Record<string, unknown> };
function parse(text: string): Request {
  const value = JSON.parse(text);
  if (
    !value ||
    typeof value !== "object" ||
    value.v !== 1 ||
    typeof value.id !== "string" ||
    !/^[A-Za-z0-9_-]{1,40}$/.test(value.id) ||
    typeof value.op !== "string" ||
    !value.data ||
    typeof value.data !== "object" ||
    Array.isArray(value.data) ||
    Object.keys(value).some((key) => !["v", "id", "op", "data"].includes(key))
  )
    throw new Rejected("bad_request");
  return value;
}
function fields(data: Record<string, unknown>, keys: string[]) {
  if (
    Object.keys(data).length !== keys.length ||
    keys.some((key) => typeof data[key] !== "string")
  )
    throw new Rejected("bad_request");
}
export async function startService(
  store: Store,
  port: number,
  options: {
    heartbeatMs?: number;
    random?: () => number;
    lootRandom?: () => number;
    persistenceKey?: string;
    checkpointMs?: number;
  } = {},
) {
  const pending = new Set<Promise<void>>();
  const connections = new Set<Promise<void>>();
  const world = new AuthoritativeWorld(options.random, options.lootRandom);
  const persistenceKey = options.persistenceKey ?? "village";
  const savedWorld = await store.loadWorld(persistenceKey);
  let worldRevision = savedWorld?.revision ?? 0;
  if (savedWorld) world.economy.restore(savedWorld.ground);
  const server = new WebSocketServer({
    host: "127.0.0.1",
    port,
    maxPayload: 8192,
    perMessageDeflate: false,
  });
  await once(server, "listening");
  let busy = false,
    serialTail = Promise.resolve();
  const leaving = new Set<string>();
  function serial<T>(action: () => Promise<T>) {
    const next = serialTail.then(async () => {
      busy = true;
      try {
        return await action();
      } finally {
        busy = false;
      }
    });
    serialTail = next.then(
      () => undefined,
      () => undefined,
    );
    return next;
  }
  async function checkpoint() {
    const result = await store.checkpoint(
      persistenceKey,
      worldRevision,
      [...world.players.values()],
      [...world.economy.ground.values()],
    );
    worldRevision = result.revision;
    for (const [id, revision] of Object.entries(result.actors)) {
      const actor = world.players.get(id);
      if (actor) actor.revision = revision;
    }
    for (const id of leaving) {
      world.remove(id);
      leaving.delete(id);
    }
  }
  async function commitAction<T>(action: () => T) {
    const states = new Map(
      [...world.players].map(([id, actor]) => [
        id,
        structuredClone(actor.state),
      ]),
    );
    const ground = structuredClone([...world.economy.ground.values()]);
    try {
      const result = action();
      await checkpoint();
      return result;
    } catch (error) {
      for (const [id, state] of states) {
        const actor = world.players.get(id);
        if (actor) actor.state = state;
      }
      world.economy.ground.clear();
      for (const record of ground) world.economy.ground.set(record.id, record);
      throw error instanceof Rejected
        ? error
        : new Rejected("persistence_failed");
    }
  }
  const checkpointTimer = setInterval(() => {
    if (
      busy ||
      (!world.players.size && !world.economy.ground.size && !leaving.size)
    )
      return;
    const work = serial(checkpoint).catch((error) =>
      console.error(
        "Checkpoint failed; retaining in-memory state:",
        (error as Error).message,
      ),
    );
    pending.add(work);
    void work.finally(() => pending.delete(work));
  }, options.checkpointMs ?? 1000);
  const entered = new Map<WebSocket, string>();
  const alive = new WeakMap<WebSocket, boolean>();
  const heartbeat = setInterval(() => {
    for (const socket of server.clients) {
      if (alive.get(socket) === false) {
        socket.terminate();
        continue;
      }
      alive.set(socket, false);
      socket.ping();
    }
  }, options.heartbeatMs ?? 10000);
  let lastTick = performance.now();
  const timer = setInterval(() => {
    const now = performance.now();
    if (busy) {
      lastTick = now;
      return;
    }
    world.step(Math.min(0.1, (now - lastTick) / 1000));
    lastTick = now;
    const snapshots = new Map<string, string>();
    for (const socket of entered.keys())
      if (socket.readyState === WebSocket.OPEN) {
        const id = entered.get(socket)!,
          actor = world.players.get(id);
        if (actor) {
          const mapId = actor.state.map_id;
          if (!snapshots.has(mapId))
            snapshots.set(
              mapId,
              JSON.stringify({
                v: 1,
                event: "snapshot",
                data: world.snapshot(mapId),
              }),
            );
          socket.send(snapshots.get(mapId)!);
        }
        if (actor)
          socket.send(
            JSON.stringify({
              v: 1,
              event: "self",
              data: {
                state: actor.state,
                cooldowns: world.combat.battles.get(id)?.cooldowns ?? {},
                social: world.social.snapshot(id),
              },
            }),
          );
      }
  }, 50);
  server.on("connection", (socket) => {
    if (server.clients.size > 64) {
      socket.close(1013, "server_full");
      return;
    }
    let resolveClosed!: () => void;
    const closed = new Promise<void>((resolve) => {
      resolveClosed = resolve;
    });
    connections.add(closed);
    alive.set(socket, true);
    socket.on("pong", () => alive.set(socket, true));
    let account: string | undefined;
    let characterId: string | undefined;
    let queue = Promise.resolve();
    let queued = 0;
    let windowStart = Date.now(),
      requests = 0;
    const seen = new Set<string>();
    socket.on("error", () => {});
    socket.on("close", () => {
      entered.delete(socket);
      const closing = queue.then(() =>
        serial(async () => {
          if (!characterId) return;
          const actor = world.players.get(characterId);
          if (!actor) return;
          actor.path = [];
          world.social.remove(characterId);
          world.combat.remove(characterId);
          leaving.add(characterId);
          try {
            await checkpoint();
          } catch (error) {
            console.error(
              "Disconnect persistence failed:",
              (error as Error).message,
            );
          }
        }),
      );
      pending.add(closing);
      void closing.finally(() => {
        pending.delete(closing);
        connections.delete(closed);
        resolveClosed();
      });
    });
    socket.on("message", (buffer, binary) => {
      if (Date.now() - windowStart > 1000) {
        windowStart = Date.now();
        requests = 0;
      }
      if (++requests > 20 || ++queued > 8 || binary) {
        socket.close(1008, "rate_or_format");
        return;
      }
      const work = queue.then(() =>
        serial(async () => {
          let id = "";
          try {
            const request = parse(buffer.toString());
            id = request.id;
            if (seen.has(id)) throw new Rejected("duplicate_request");
            seen.add(id);
            if (seen.size > 256) seen.delete(seen.values().next().value!);
            const data = request.data;
            let result: unknown;
            if (request.op === "register" || request.op === "login") {
              if (account) throw new Rejected("already_authenticated");
              fields(data, ["username", "password"]);
              if (request.op === "register") {
                await store.register(data.username, data.password);
                result = { registered: true };
              } else {
                account = await store.login(data.username, data.password);
                result = { authenticated: true };
              }
            } else {
              if (!account) throw new Rejected("unauthenticated");
              switch (request.op) {
                case "portal": {
                  fields(data, ["portal_id"]);
                  if (!characterId) throw new Rejected("not_in_world");
                  await commitAction(() =>
                    world.portal(characterId!, data.portal_id as string),
                  );
                  world.social.cancel(characterId);
                  world.social.reconcile();
                  const actor = world.players.get(characterId)!;
                  result = {
                    state: actor.state,
                    cooldowns:
                      world.combat.battles.get(characterId)?.cooldowns ?? {},
                    social: world.social.snapshot(characterId),
                    world: world.snapshot(actor.state.map_id),
                  };
                  break;
                }
                case "chat": {
                  fields(data, ["channel", "message"]);
                  if (!characterId) throw new Rejected("not_in_world");
                  const delivery = world.social.chat(
                    characterId,
                    data.channel,
                    data.message,
                  );
                  for (const [peer, id] of entered)
                    if (
                      delivery.recipients.includes(id) &&
                      peer.readyState === WebSocket.OPEN
                    )
                      peer.send(
                        JSON.stringify({
                          v: 1,
                          event: "chat",
                          data: delivery.message,
                        }),
                      );
                  result = { sent: true };
                  break;
                }
                case "party_invite":
                case "trade_invite":
                  fields(data, ["target_id"]);
                  if (!characterId) throw new Rejected("not_in_world");
                  if (request.op === "party_invite")
                    world.social.inviteParty(
                      characterId,
                      data.target_id as string,
                    );
                  else
                    world.social.inviteTrade(
                      characterId,
                      data.target_id as string,
                    );
                  result = { accepted: true };
                  break;
                case "party_reply":
                case "trade_reply":
                  if (
                    Object.keys(data).length !== 1 ||
                    typeof data.accept !== "boolean"
                  )
                    throw new Rejected("bad_request");
                  if (!characterId) throw new Rejected("not_in_world");
                  if (request.op === "party_reply")
                    world.social.replyParty(characterId, data.accept);
                  else world.social.replyTrade(characterId, data.accept);
                  result = { accepted: true };
                  break;
                case "party_leave":
                case "trade_cancel":
                  fields(data, []);
                  if (!characterId) throw new Rejected("not_in_world");
                  if (request.op === "party_leave")
                    world.social.leaveParty(characterId);
                  else world.social.cancel(characterId);
                  result = { accepted: true };
                  break;
                case "trade_offer":
                  if (
                    Object.keys(data).length !== 3 ||
                    !Array.isArray(data.uids) ||
                    typeof data.gold !== "number" ||
                    typeof data.revision !== "number"
                  )
                    throw new Rejected("bad_request");
                  if (!characterId) throw new Rejected("not_in_world");
                  world.social.offer(
                    characterId,
                    data.uids,
                    data.gold,
                    data.revision,
                  );
                  result = { accepted: true };
                  break;
                case "trade_accept": {
                  if (
                    Object.keys(data).length !== 1 ||
                    typeof data.revision !== "number"
                  )
                    throw new Rejected("bad_request");
                  if (!characterId) throw new Rejected("not_in_world");
                  const acceptance = world.social.accept(
                    characterId,
                    data.revision,
                  );
                  if (acceptance.ready) {
                    await commitAction(() =>
                      world.social.exchange(acceptance.trade_id),
                    );
                    world.social.complete(acceptance.trade_id);
                  }
                  result = { completed: acceptance.ready };
                  break;
                }
                case "characters":
                  fields(data, []);
                  result = await store.list(account);
                  break;
                case "create_character":
                  fields(data, ["name", "class_id"]);
                  result = await store.create(
                    account,
                    data.name as string,
                    data.class_id as string,
                  );
                  break;
                case "load_character":
                  fields(data, ["character_id"]);
                  result = await store.load(
                    account,
                    data.character_id as string,
                  );
                  break;
                case "enter_world": {
                  fields(data, ["character_id"]);
                  if (characterId) throw new Rejected("already_in_world");
                  const loaded = await store.load(
                    account,
                    data.character_id as string,
                  );
                  if (socket.readyState !== WebSocket.OPEN)
                    throw new Rejected("disconnected");
                  const actor = world.join(account, loaded);
                  characterId = actor.id;
                  entered.set(socket, actor.id);
                  result = {
                    character_id: actor.id,
                    state: actor.state,
                    world: world.snapshot(actor.state.map_id),
                  };
                  break;
                }
                case "move": {
                  if (!characterId) throw new Rejected("not_in_world");
                  if (
                    Object.keys(data).length !== 2 ||
                    typeof data.x !== "number" ||
                    typeof data.y !== "number"
                  )
                    throw new Rejected("bad_request");
                  world.move(characterId, { x: data.x, y: data.y });
                  result = { accepted: true };
                  break;
                }
                case "select_target":
                  fields(data, ["target_id"]);
                  if (!characterId) throw new Rejected("not_in_world");
                  world.combat.select(characterId, data.target_id as string);
                  result = { accepted: true };
                  break;
                case "cast":
                  fields(data, ["skill_id"]);
                  if (!characterId) throw new Rejected("not_in_world");
                  world.combat.cast(characterId, data.skill_id as string);
                  result = { accepted: true };
                  break;
                case "allocate": {
                  if (!characterId) throw new Rejected("not_in_world");
                  if (
                    Object.keys(data).length !== 2 ||
                    typeof data.attribute !== "string" ||
                    typeof data.amount !== "number"
                  )
                    throw new Rejected("bad_request");
                  const actor = world.players.get(characterId)!;
                  if (actor.state.hp <= 0) throw new Rejected("dead");
                  allocate(actor.state, data.attribute, data.amount);
                  result = { accepted: true };
                  break;
                }
                case "buy":
                  fields(data, ["shop_id", "definition"]);
                  if (!characterId) throw new Rejected("not_in_world");
                  result = await commitAction(() => {
                    world.economy.buy(
                      characterId!,
                      data.shop_id as string,
                      data.definition as string,
                    );
                    return { accepted: true };
                  });
                  break;
                case "sell":
                  fields(data, ["shop_id", "uid"]);
                  if (!characterId) throw new Rejected("not_in_world");
                  result = await commitAction(() => {
                    world.economy.sell(
                      characterId!,
                      data.shop_id as string,
                      data.uid as string,
                    );
                    return { accepted: true };
                  });
                  break;
                case "pickup":
                case "drop":
                case "equip":
                case "consume":
                case "repair":
                case "upgrade": {
                  const key = request.op === "pickup" ? "ground_id" : "uid";
                  fields(data, [key]);
                  if (!characterId) throw new Rejected("not_in_world");
                  result = await commitAction(() => {
                    const value = data[key] as string;
                    switch (request.op) {
                      case "pickup":
                        world.economy.pickup(characterId!, value);
                        break;
                      case "drop":
                        world.economy.drop(characterId!, value);
                        break;
                      case "equip":
                        world.economy.equip(characterId!, value);
                        break;
                      case "consume":
                        world.economy.consume(characterId!, value);
                        break;
                      case "repair":
                        world.economy.repair(characterId!, value);
                        break;
                      case "upgrade":
                        return world.economy.upgrade(characterId!, value);
                    }
                    return { accepted: true };
                  });
                  break;
                }
                case "unequip":
                  fields(data, ["slot"]);
                  if (!characterId) throw new Rejected("not_in_world");
                  result = await commitAction(() => {
                    world.economy.unequip(characterId!, data.slot as string);
                    return { accepted: true };
                  });
                  break;
                case "inventory_move": {
                  if (!characterId) throw new Rejected("not_in_world");
                  if (
                    Object.keys(data).length !== 3 ||
                    typeof data.uid !== "string" ||
                    typeof data.x !== "number" ||
                    typeof data.y !== "number"
                  )
                    throw new Rejected("bad_request");
                  result = await commitAction(() => {
                    world.economy.move(
                      characterId!,
                      data.uid as string,
                      data.x as number,
                      data.y as number,
                    );
                    return { accepted: true };
                  });
                  break;
                }
                default:
                  throw new Rejected("unknown_operation");
              }
            }
            if (socket.readyState === WebSocket.OPEN)
              socket.send(JSON.stringify({ v: 1, id, ok: true, data: result }));
          } catch (error) {
            const code =
              error instanceof Rejected
                ? error.message
                : error instanceof SyntaxError
                  ? "bad_request"
                  : "internal_error";
            if (!(error instanceof Rejected) && !(error instanceof SyntaxError))
              console.error("Request failed:", (error as Error).message);
            if (socket.readyState === WebSocket.OPEN)
              socket.send(JSON.stringify({ v: 1, id, ok: false, error: code }));
          } finally {
            queued--;
          }
        }),
      );
      queue = work;
      pending.add(work);
      void work.finally(() => pending.delete(work));
    });
  });
  const address = server.address();
  return {
    world,
    port: typeof address === "object" && address ? address.port : port,
    close: async () => {
      clearInterval(timer);
      clearInterval(checkpointTimer);
      clearInterval(heartbeat);
      for (const socket of server.clients) socket.terminate();
      await new Promise<void>((resolve, reject) =>
        server.close((error) => (error ? reject(error) : resolve())),
      );
      await Promise.all(connections);
      while (pending.size) await Promise.all(pending);
      if (leaving.size) await serial(checkpoint);
    },
  };
}
