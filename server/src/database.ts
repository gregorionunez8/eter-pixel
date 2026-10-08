import { existsSync, mkdirSync } from "node:fs";
import { resolve } from "node:path";
import EmbeddedPostgres from "embedded-postgres";
import pg from "pg";

export async function openDatabase(directory: string, port: number) {
  const databaseDir = resolve(directory);
  mkdirSync(databaseDir, { recursive: true });
  const cluster = new EmbeddedPostgres({
    databaseDir,
    port,
    user: "eter",
    password: "eter-local-development",
    authMethod: "scram-sha-256",
    persistent: true,
    createPostgresUser: false,
    initdbFlags: ["--encoding=UTF8"],
    postgresFlags: ["-h", "127.0.0.1"],
    onLog: () => {},
    onError: (message) => console.error("PostgreSQL:", message),
  });
  if (!existsSync(resolve(databaseDir, "PG_VERSION")))
    await cluster.initialise();
  await cluster.start();
  const pool = new pg.Pool({
    host: "127.0.0.1",
    port,
    user: "eter",
    password: "eter-local-development",
    database: "postgres",
    max: 8,
  });
  try {
    const version = await pool.query("SELECT version() AS version");
    return {
      pool,
      version: String(version.rows[0].version),
      close: async () => {
        await pool.end();
        await cluster.stop();
      },
    };
  } catch (error) {
    await pool.end();
    await cluster.stop();
    throw error;
  }
}
