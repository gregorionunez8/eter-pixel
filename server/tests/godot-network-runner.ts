// Explicit runner, not included in *.test.js: requires the local Godot executable.
import { spawn } from "node:child_process";
import { openSync, closeSync, readFileSync } from "node:fs";
import { resolve } from "node:path";
import { randomUUID } from "node:crypto";
import { openDatabase } from "../src/database.js";
import { Store } from "../src/store.js";
import { startService } from "../src/service.js";

const database = await openDatabase(
  "../artifacts/postgres-godot-network-test",
  55443,
);
let service: Awaited<ReturnType<typeof startService>> | undefined;
const suffix = randomUUID().replaceAll("-", "").slice(0, 8);
try {
  const store = new Store(database.pool);
  await store.migrate();
  service = await startService(store, 0, { persistenceKey: "godot_" + suffix });
  const url = `ws://127.0.0.1:${service.port}`;
  const execute = (role: number) =>
    new Promise<void>((resolvePromise, reject) => {
      const logPath = resolve(`../artifacts/godot-network-${role}.log`);
      const fd = openSync(logPath, "w");
      const child = spawn(
        process.argv[2] ?? "C:/Godot/godot.exe",
        [
          "--headless",
          "--path",
          resolve("../client"),
          "--script",
          "res://tests/network_transport.gd",
          "--",
          url,
          String(role),
          suffix,
        ],
        { windowsHide: true, stdio: ["ignore", fd, fd] },
      );
      closeSync(fd);
      const timer = setTimeout(() => {
        child.kill();
        reject(new Error("Godot network timed out"));
      }, 30000);
      child.once("error", (error) => {
        clearTimeout(timer);
        reject(error);
      });
      child.once("exit", (code) => {
        clearTimeout(timer);
        const log = readFileSync(logPath, "utf8");
        console.log(log);
        if (
          code !== 0 ||
          /SCRIPT ERROR|ERROR:|FAIL network/.test(log) ||
          !log.includes("PASS Godot network transport")
        )
          reject(new Error(`Godot role${role} failed (${code})`));
        else resolvePromise();
      });
    });
  const results = await Promise.allSettled([execute(0), execute(1)]);
  for (const result of results)
    if (result.status === "rejected") throw result.reason;
  console.log("PASS two actual Godot transports with SQL reconnect");
} finally {
  await service?.close();
  await database.close();
}
