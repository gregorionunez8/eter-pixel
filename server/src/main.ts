import { openDatabase } from './database.js';
import { Store } from './store.js';
import { startService } from './service.js';

const smoke = process.argv.includes('--smoke-server');
const database = await openDatabase(smoke ? '../artifacts/postgres-main-smoke' : '.local/postgres', smoke ? 55440 : Number(process.env.ETER_DB_PORT ?? 55432));
const store = new Store(database.pool);
let service: Awaited<ReturnType<typeof startService>>;
try {
  await store.migrate();
  service = await startService(store, smoke ? 0 : Number(process.env.ETER_PORT ?? 8080));
} catch (error) { await database.close(); throw error; }
console.log(`ÉTER local WebSocket: ws://127.0.0.1:${service.port}`);
console.log(database.version);
let closing = false;
async function close() { if (closing) return; closing = true; await service.close(); await database.close(); }
process.on('SIGINT', () => { void close().then(() => process.exit(0)); });
process.on('SIGTERM', () => { void close().then(() => process.exit(0)); });
if (smoke) { await close(); console.log('PASS server startup: compiled entrypoint, real PostgreSQL, WebSocket and clean shutdown'); }
