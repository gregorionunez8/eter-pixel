// Explicit runner, not included in *.test.js: requires the local Godot executable.
import { spawn, type ChildProcess } from "node:child_process";
import { openSync, closeSync, readFileSync } from "node:fs";
import { resolve } from "node:path";
import { randomUUID } from "node:crypto";
import { openDatabase } from "../src/database.js";
import { deriveStats } from "../src/rules.js";
import { Store } from "../src/store.js";
import { startService } from "../src/service.js";

const database = await openDatabase(
  "../artifacts/postgres-godot-network-test",
  55443,
);
let service: Awaited<ReturnType<typeof startService>> | undefined;
const suffix = randomUUID().replaceAll("-", "").slice(0, 8);
const mode = process.argv[3] ?? "transport";
const quests = mode.startsWith("quests");
const rendered = mode === "graphics" || mode === "quests-graphics";
const roles = quests ? [0] : [0, 1];
const fixtureIds: string[] = [];
try {
  const store = new Store(database.pool);
  await store.migrate();
  if (mode !== "transport") {
    for (const role of roles) {
      const account = await store.register(
        `godotw_${role}_${suffix}`,
        "fixture-password",
      );
      const saved = await store.create(
        account,
        `Red${role}${suffix}`,
        role === 0 ? "warrior" : "mage",
      );
      fixtureIds.push(saved.id);
      if (quests) {
        // Trusted fixture accelerates real server attacks, never journal progress.
        for (const key of Object.keys(saved.state.attributes)) saved.state.attributes[key] = 1000;
        saved.state.stats = deriveStats(saved.state);
        saved.state.hp = Number(saved.state.stats.max_hp);
        saved.state.mana = Number(saved.state.stats.max_mana);
      }
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
  const children = new Set<ChildProcess>();
  const execute = (role: number) =>
    new Promise<void>((resolvePromise, reject) => {
      const logPath = resolve(`../artifacts/godot-${mode}-${role}.log`);
      const fd = openSync(logPath, "w");
      const child = spawn(
        process.argv[2] ?? "C:/Godot/godot.exe",
        [
          ...(rendered ? [] : ["--headless"]),
          "--path",
          resolve("../client"),
          ...(mode === "transport"
            ? ["--script", "res://tests/network_transport.gd"]
            : [quests ? "res://scenes/test_online_quests.tscn" : "res://scenes/test_online_world.tscn"]),
          "--",
          url,
          String(role),
          suffix,
          mode,
          ...(process.argv.includes("--fail-role0") ? ["--fail-role0"] : []),
        ],
        { windowsHide: true, stdio: ["ignore", fd, fd] },
      );
      const diagnostics = setInterval(() => {
        if (/SCRIPT ERROR|Parse Error|ERROR:(?! FAIL )/.test(readFileSync(logPath, "utf8"))) child.kill();
      }, 200);
      children.add(child);
      closeSync(fd);
      const timer = setTimeout(() => {
        clearInterval(diagnostics);
        child.kill();
        reject(new Error("Godot network timed out"));
      }, quests ? 360000 : 120000);
      child.once("error", (error) => {
        clearInterval(diagnostics);
        clearTimeout(timer);
        reject(error);
      });
      child.once("exit", (code) => {
        children.delete(child);
        clearInterval(diagnostics);
        clearTimeout(timer);
        const log = readFileSync(logPath, "utf8");
        console.log(log);
        if (
          code !== 0 ||
          /SCRIPT ERROR|ERROR:|FAIL network|FAIL online world/.test(log) ||
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
  const executePeer = (role: number) => execute(role).catch((error) => {
    for (const child of children) child.kill();
    throw error;
  });
  const results = await Promise.allSettled(roles.map(executePeer));
  for (const result of results)
    if (result.status === "rejected") throw result.reason;
  if (quests) {
    const persisted = await store.loadWorld("godot_" + suffix);
    const character = await database.pool.query("SELECT state FROM characters WHERE id=$1", [fixtureIds[0]]);
    const journal = character.rows[0].state.quests;
    if (!persisted || Object.values(journal).length !== 3 || !Object.values(journal).every((entry: any) => entry.claimed))
      throw new Error("Three delivered quests were not persisted in SQL");
    console.log("PASS three actual Godot quest flows and SQL persistence");
  }
  console.log(
    mode === "transport"
      ? "PASS two actual Godot transports with SQL reconnect"
      : quests
        ? "PASS one actual Godot quest world with authoritative gameplay and SQL reconnect"
        : "PASS two actual Godot worlds with authoritative gameplay and SQL reconnect",
  );
} finally {
  await service?.close();
  await database.close();
}
