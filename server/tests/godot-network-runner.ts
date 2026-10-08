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
const mode = process.argv[3] ?? "transport";
try {
  const store = new Store(database.pool);
  await store.migrate();
  if (mode !== "transport") {
    for (const role of [0, 1]) {
      const account = await store.register(
        `godotw_${role}_${suffix}`,
        "fixture-password",
      );
      const saved = await store.create(
        account,
        `Red${role}${suffix}`,
        role === 0 ? "warrior" : "mage",
      );
      saved.state.gold = 1000; // Explicit economy UI fixture, never client-provided gold.
      saved.state.position = { x: role === 0 ? 1008 : 976, y: 560 };
      await store.save(account, saved.id, saved.state, saved.revision);
    }
  }
  service = await startService(store, 0, {
    persistenceKey: "godot_" + suffix,
    ...(mode !== "transport"
      ? { random: () => 0.2, lootRandom: () => 0.2 }
      : {}),
  });
  const url = `ws://127.0.0.1:${service.port}`;
  const execute = (role: number) =>
    new Promise<void>((resolvePromise, reject) => {
      const logPath = resolve(`../artifacts/godot-${mode}-${role}.log`);
      const fd = openSync(logPath, "w");
      const child = spawn(
        process.argv[2] ?? "C:/Godot/godot.exe",
        [
          ...(mode === "graphics" ? [] : ["--headless"]),
          "--path",
          resolve("../client"),
          ...(mode === "transport"
            ? ["--script", "res://tests/network_transport.gd"]
            : ["res://scenes/test_online_world.tscn"]),
          "--",
          url,
          String(role),
          suffix,
          mode,
        ],
        { windowsHide: true, stdio: ["ignore", fd, fd] },
      );
      closeSync(fd);
      const timer = setTimeout(() => {
        child.kill();
        reject(new Error("Godot network timed out"));
      }, 60000);
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
          !log.includes(
            mode === "transport"
              ? "PASS Godot network transport"
              : "PASS online world",
          )
        )
          reject(new Error(`Godot role${role} failed (${code})`));
        else resolvePromise();
      });
    });
  const results = await Promise.allSettled([execute(0), execute(1)]);
  for (const result of results)
    if (result.status === "rejected") throw result.reason;
  console.log(
    mode === "transport"
      ? "PASS two actual Godot transports with SQL reconnect"
      : "PASS two actual Godot worlds with authoritative gameplay and SQL reconnect",
  );
} finally {
  await service?.close();
  await database.close();
}
