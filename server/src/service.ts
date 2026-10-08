import { once } from "node:events";
import { WebSocketServer, WebSocket } from "ws";
import { Store, Rejected } from "./store.js";
import { AuthoritativeWorld } from "./world.js";

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
  options: { heartbeatMs?: number } = {},
) {
  const server = new WebSocketServer({
    host: "127.0.0.1",
    port,
    maxPayload: 8192,
    perMessageDeflate: false,
  });
  await once(server, "listening");
  const pending = new Set<Promise<void>>();
  const connections = new Set<Promise<void>>();
  const world = new AuthoritativeWorld();
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
    world.step(Math.min(0.1, (now - lastTick) / 1000));
    lastTick = now;
    const payload = JSON.stringify({
      v: 1,
      event: "snapshot",
      data: world.snapshot(),
    });
    for (const socket of entered.keys())
      if (socket.readyState === WebSocket.OPEN) socket.send(payload);
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
      const closing = queue.then(async () => {
        if (!characterId) return;
        const actor = world.players.get(characterId);
        if (!actor) return;
        actor.path = [];
        try {
          await store.save(
            actor.account,
            actor.id,
            actor.state,
            actor.revision,
          );
        } catch (error) {
          console.error(
            "Disconnect persistence failed:",
            (error as Error).message,
          );
        } finally {
          world.remove(characterId);
        }
      });
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
      const work = queue.then(async () => {
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
                result = await store.load(account, data.character_id as string);
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
                  world: world.snapshot(),
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
      });
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
      clearInterval(heartbeat);
      for (const socket of server.clients) socket.terminate();
      await new Promise<void>((resolve, reject) =>
        server.close((error) => (error ? reject(error) : resolve())),
      );
      await Promise.all(connections);
      while (pending.size) await Promise.all(pending);
    },
  };
}
