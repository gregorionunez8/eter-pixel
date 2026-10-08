import { randomBytes, randomUUID, scrypt, timingSafeEqual } from "node:crypto";
import type { Pool } from "pg";
import { createCharacter, type Character } from "./rules.js";

export class Rejected extends Error {}
async function hash(password: string, salt: string): Promise<Buffer> {
  return new Promise((resolve, reject) =>
    scrypt(password, salt, 64, { N: 16384, r: 8, p: 1 }, (error, result) =>
      error ? reject(error) : resolve(result),
    ),
  );
}
function credentials(
  username: unknown,
  password: unknown,
): asserts username is string {
  if (
    typeof username !== "string" ||
    !/^[a-zA-Z0-9_]{3,32}$/.test(username) ||
    typeof password !== "string" ||
    password.length < 8 ||
    password.length > 128
  )
    throw new Rejected("invalid_credentials");
}
export class Store {
  constructor(public pool: Pool) {}
  async migrate() {
    await this.pool.query(`CREATE TABLE IF NOT EXISTS accounts (
      id uuid PRIMARY KEY, username text NOT NULL UNIQUE, salt text NOT NULL, password_hash text NOT NULL, created_at timestamptz NOT NULL DEFAULT now());
      CREATE TABLE IF NOT EXISTS characters (
      id uuid PRIMARY KEY, account_id uuid NOT NULL REFERENCES accounts(id), name text NOT NULL, state jsonb NOT NULL,
      revision integer NOT NULL DEFAULT 0, updated_at timestamptz NOT NULL DEFAULT now());
      CREATE UNIQUE INDEX IF NOT EXISTS character_name_unique ON characters(lower(name));`);
  }
  async register(username: unknown, password: unknown) {
    credentials(username, password);
    const salt = randomBytes(16).toString("hex");
    const passwordHash = (await hash(password as string, salt)).toString("hex");
    const id = randomUUID();
    try {
      await this.pool.query(
        "INSERT INTO accounts(id,username,salt,password_hash) VALUES($1,$2,$3,$4)",
        [id, username.toLowerCase(), salt, passwordHash],
      );
    } catch (error) {
      if ((error as { code?: string }).code === "23505")
        throw new Rejected("account_exists");
      throw error;
    }
    return id;
  }
  async login(username: unknown, password: unknown) {
    credentials(username, password);
    const result = await this.pool.query(
      "SELECT id,salt,password_hash FROM accounts WHERE username=$1",
      [username.toLowerCase()],
    );
    const row = result.rows[0];
    const candidate = await hash(
      password as string,
      row?.salt ?? "missing-account-dummy-salt",
    );
    if (
      !row ||
      !timingSafeEqual(candidate, Buffer.from(row.password_hash, "hex"))
    )
      throw new Rejected("login_failed");
    return String(row.id);
  }
  async create(accountId: string, name: string, classId: string) {
    let state: Character;
    try {
      state = createCharacter(name, classId);
    } catch {
      throw new Rejected("invalid_character");
    }
    const client = await this.pool.connect();
    try {
      await client.query("BEGIN");
      const owner = await client.query(
        "SELECT id FROM accounts WHERE id=$1 FOR UPDATE",
        [accountId],
      );
      if (!owner.rowCount) throw new Rejected("unauthenticated");
      const count = await client.query(
        "SELECT count(*)::int AS count FROM characters WHERE account_id=$1",
        [accountId],
      );
      if (count.rows[0].count >= 3) throw new Rejected("character_limit");
      const id = randomUUID();
      await client.query(
        "INSERT INTO characters(id,account_id,name,state) VALUES($1,$2,$3,$4)",
        [id, accountId, name, state],
      );
      await client.query("COMMIT");
      return { id, state, revision: 0 };
    } catch (error) {
      await client.query("ROLLBACK");
      if ((error as { code?: string }).code === "23505")
        throw new Rejected("name_exists");
      throw error;
    } finally {
      client.release();
    }
  }
  async list(accountId: string) {
    const result = await this.pool.query(
      "SELECT id,name,state->>'class_id' AS class_id,state->'level' AS level FROM characters WHERE account_id=$1 ORDER BY name",
      [accountId],
    );
    return result.rows;
  }
  async load(accountId: string, id: string) {
    if (
      !/^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$/.test(id)
    )
      throw new Rejected("character_missing");
    const result = await this.pool.query(
      "SELECT id,state,revision FROM characters WHERE account_id=$1 AND id=$2",
      [accountId, id],
    );
    if (!result.rowCount) throw new Rejected("character_missing");
    return result.rows[0] as { id: string; state: Character; revision: number };
  }
  // Called by trusted simulation only; there is no save-state message in the protocol.
  async save(
    accountId: string,
    id: string,
    state: Character,
    expectedRevision: number,
  ) {
    const result = await this.pool.query(
      "UPDATE characters SET state=$3,revision=revision+1,updated_at=now() WHERE account_id=$1 AND id=$2 AND revision=$4 RETURNING revision",
      [accountId, id, state, expectedRevision],
    );
    if (!result.rowCount) throw new Rejected("stale_state");
    return Number(result.rows[0].revision);
  }
}
