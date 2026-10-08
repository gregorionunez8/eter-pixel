import { once } from 'node:events';
import { WebSocketServer, WebSocket } from 'ws';
import { Store, Rejected } from './store.js';

type Request = { v: 1; id: string; op: string; data: Record<string, unknown> };
function parse(text: string): Request {
  const value = JSON.parse(text);
  if (!value || typeof value !== 'object' || value.v !== 1 || typeof value.id !== 'string' || !/^[A-Za-z0-9_-]{1,40}$/.test(value.id) ||
      typeof value.op !== 'string' || !value.data || typeof value.data !== 'object' || Array.isArray(value.data) || Object.keys(value).some(key => !['v','id','op','data'].includes(key))) throw new Rejected('bad_request');
  return value;
}
function fields(data: Record<string, unknown>, keys: string[]) {
  if (Object.keys(data).length !== keys.length || keys.some(key => typeof data[key] !== 'string')) throw new Rejected('bad_request');
}
export async function startService(store: Store, port: number) {
  const server = new WebSocketServer({ host: '127.0.0.1', port, maxPayload: 8192, perMessageDeflate: false });
  await once(server, 'listening');
  const pending = new Set<Promise<void>>();
  server.on('connection', socket => {
    if (server.clients.size > 64) { socket.close(1013, 'server_full'); return; }
    let account: string | undefined;
    let queue = Promise.resolve();
    let queued = 0;
    let windowStart = Date.now(), requests = 0;
    const seen = new Set<string>();
    socket.on('error', () => {});
    socket.on('message', (buffer, binary) => {
      if (Date.now() - windowStart > 1000) { windowStart = Date.now(); requests = 0; }
      if (++requests > 20 || ++queued > 8 || binary) { socket.close(1008, 'rate_or_format'); return; }
      const work = queue.then(async () => {
        let id = '';
        try {
          const request = parse(buffer.toString()); id = request.id;
          if (seen.has(id)) throw new Rejected('duplicate_request');
          seen.add(id); if (seen.size > 256) seen.delete(seen.values().next().value!);
          const data = request.data;
          let result: unknown;
          if (request.op === 'register' || request.op === 'login') {
            if (account) throw new Rejected('already_authenticated');
            fields(data, ['username', 'password']);
            if (request.op === 'register') { await store.register(data.username, data.password); result = { registered: true }; }
            else { account = await store.login(data.username, data.password); result = { authenticated: true }; }
          } else {
            if (!account) throw new Rejected('unauthenticated');
            switch (request.op) {
              case 'characters': fields(data, []); result = await store.list(account); break;
              case 'create_character': fields(data, ['name','class_id']); result = await store.create(account, data.name as string, data.class_id as string); break;
              case 'load_character': fields(data, ['character_id']); result = await store.load(account, data.character_id as string); break;
              default: throw new Rejected('unknown_operation');
            }
          }
          if (socket.readyState === WebSocket.OPEN) socket.send(JSON.stringify({ v: 1, id, ok: true, data: result }));
        } catch (error) {
          const code = error instanceof Rejected ? error.message : error instanceof SyntaxError ? 'bad_request' : 'internal_error';
          if (!(error instanceof Rejected) && !(error instanceof SyntaxError)) console.error('Request failed:', (error as Error).message);
          if (socket.readyState === WebSocket.OPEN) socket.send(JSON.stringify({ v: 1, id, ok: false, error: code }));
        } finally { queued--; }
      });
      queue = work; pending.add(work); void work.finally(() => pending.delete(work));
    });
  });
  const address = server.address();
  return { port: typeof address === 'object' && address ? address.port : port,
    close: async () => { for (const socket of server.clients) socket.terminate(); await new Promise<void>((resolve, reject) => server.close(error => error ? reject(error) : resolve())); await Promise.all(pending); } };
}
