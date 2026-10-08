import { existsSync, mkdirSync } from "node:fs";
import { resolve, dirname, basename } from "node:path";
import EmbeddedPostgres from "embedded-postgres";
import pg from "pg";
import { spawn } from "node:child_process";

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
  // pg_ctl performs a graceful, waited shutdown on Windows. The wrapper's
  // taskkill-based stop can leave PostgreSQL children alive during restart.
  const pgCtl = resolve(
    "node_modules/@embedded-postgres/windows-x64/native/bin/pg_ctl.exe",
  );
  if (process.platform !== "win32" || !existsSync(pgCtl))
    throw new Error("Local PostgreSQL launcher currently requires Windows x64");
  // Ignore inherited pipes: pg_ctl exits while the server intentionally stays alive.
  const control = (args: string[]) =>
    new Promise<number>((resolve, reject) => {
      const child = spawn(
        pgCtl,
        ["-D", databaseDir, "-w", "-t", "15", ...args],
        { windowsHide: true, stdio: "ignore" },
      );
      const timeout = setTimeout(() => {
        child.kill();
        reject(new Error("pg_ctl timeout; inspect local PostgreSQL log"));
      }, 20000);
      child.once("error", (error) => {
        clearTimeout(timeout);
        reject(error);
      });
      child.once("exit", (code) => {
        clearTimeout(timeout);
        if (code === 0 || (args.includes("status") && code === 3))
          resolve(code ?? 1);
        else
          reject(
            new Error(
              "pg_ctl failed " +
                args.join(" ") +
                "; inspect local PostgreSQL log",
            ),
          );
      });
    });
  if (
    existsSync(resolve(databaseDir, "postmaster.pid")) &&
    (await control(["status"])) === 0
  )
    throw new Error(
      "cluster_already_running: stop the existing local cluster first",
    );
  try {
    await control([
      "-l",
      resolve(dirname(databaseDir), basename(databaseDir) + ".log"),
      "-o",
      `-h 127.0.0.1 -p ${port}`,
      "start",
    ]);
  } catch (error) {
    try {
      await control(["-m", "fast", "stop"]);
    } catch {}
    throw error;
  }
  const pool = new pg.Pool({
    host: "127.0.0.1",
    port,
    user: "eter",
    password: "eter-local-development",
    database: "postgres",
    max: 8,
  });
  let closing: Promise<void> | undefined;
  const close = () =>
    (closing ??= (async () => {
      await pool.end();
      await control(["-m", "fast", "stop"]);
    })());
  try {
    const version = await pool.query("SELECT version() AS version");
    return {
      pool,
      version: String(version.rows[0].version),
      close,
    };
  } catch (error) {
    await close();
    throw error;
  }
}
