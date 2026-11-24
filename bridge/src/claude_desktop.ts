// Wobbo's entry in Claude Desktop's MCP configuration (claude-desktop-setup D2).
//
//   wobbo-bridge claude-desktop connect      (add or refresh the `wobbo` entry)
//   wobbo-bridge claude-desktop disconnect   (remove it)
//
// The edit is a pure function over the file text; `runClaudeDesktop` reads and
// writes the file. JavaScript's JSON keeps every other value exactly as Claude
// Desktop wrote it, which Godot's parser would not (it turns 1 into 1.0).
import { chmodSync, existsSync, readFileSync, renameSync, statSync, unlinkSync, writeFileSync } from "node:fs";
import { basename, dirname, join } from "node:path";

export const ENTRY_NAME = "wobbo";
/** Binaries whose entries would run a second Wobbo server in Claude Desktop. */
const BRIDGE_BINARIES = ["wobbo-bridge", "claude-buddy-bridge"];

export type Outcome = "added" | "updated" | "unchanged" | "removed" | "absent";

export class ConfigError extends Error {}

export function configDir(home: string): string {
  return join(home, "Library", "Application Support", "Claude");
}

export function configPath(home: string): string {
  return join(configDir(home), "claude_desktop_config.json");
}

export function wobboEntry(binary: string): { command: string; args: string[] } {
  return { command: binary, args: ["mcp", "--agent", "claude-desktop"] };
}

type Json = Record<string, unknown>;

function isObject(v: unknown): v is Json {
  return typeof v === "object" && v !== null && !Array.isArray(v);
}

function parse(text: string | null): Json {
  if (text === null || text.trim() === "") return {};
  let data: unknown;
  try {
    data = JSON.parse(text);
  } catch {
    throw new ConfigError("Claude Desktop's configuration is not valid JSON");
  }
  if (!isObject(data)) throw new ConfigError("Claude Desktop's configuration is not a JSON object");
  if (data.mcpServers !== undefined && !isObject(data.mcpServers)) {
    throw new ConfigError("mcpServers in Claude Desktop's configuration is not an object");
  }
  return data;
}

function format(data: Json): string {
  return JSON.stringify(data, null, 2) + "\n";
}

function runsBridge(entry: unknown): boolean {
  return isObject(entry) && typeof entry.command === "string" && BRIDGE_BINARIES.includes(basename(entry.command));
}

/** Removes entries other than `keep` that run a Wobbo bridge; true when any went. */
function dropStale(servers: Json, keep: string | null): boolean {
  let dropped = false;
  for (const [name, entry] of Object.entries(servers)) {
    if (name !== keep && runsBridge(entry)) {
      delete servers[name];
      dropped = true;
    }
  }
  return dropped;
}

/** The file text with Wobbo's entry set to `binary`; `text` is null for no file. */
export function connectConfig(text: string | null, binary: string): { text: string; outcome: Outcome } {
  const data = parse(text);
  const servers: Json = isObject(data.mcpServers) ? data.mcpServers : {};
  data.mcpServers = servers;
  const want = wobboEntry(binary);
  const had = servers[ENTRY_NAME];
  const same = JSON.stringify(had) === JSON.stringify(want);
  const dropped = dropStale(servers, ENTRY_NAME);
  if (same && !dropped) return { text: text ?? "", outcome: "unchanged" };
  servers[ENTRY_NAME] = want;
  return { text: format(data), outcome: had === undefined ? "added" : "updated" };
}

/** The file text without Wobbo's entries; `text` is null for no file. */
export function disconnectConfig(text: string | null): { text: string; outcome: Outcome } {
  const data = parse(text);
  if (!isObject(data.mcpServers)) return { text: text ?? "", outcome: "unchanged" };
  const servers = data.mcpServers;
  const had = ENTRY_NAME in servers;
  delete servers[ENTRY_NAME];
  const dropped = dropStale(servers, null);
  if (!had && !dropped) return { text: text ?? "", outcome: "unchanged" };
  return { text: format(data), outcome: "removed" };
}

/** Writes through a temporary file in the same folder, keeping the file's mode. */
function writeAtomic(path: string, text: string): void {
  const tmp = join(dirname(path), `.${basename(path)}.wobbo-${process.pid}.tmp`);
  const mode = existsSync(path) ? statSync(path).mode & 0o777 : 0o644;
  try {
    writeFileSync(tmp, text, { mode });
    chmodSync(tmp, mode);
    renameSync(tmp, path);
  } catch (e) {
    try {
      unlinkSync(tmp);
    } catch {}
    throw e;
  }
}

/** Applies `action` to Claude Desktop's configuration under `home`. */
export function runClaudeDesktop(action: string, home: string, binary: string): Outcome {
  if (action !== "connect" && action !== "disconnect") {
    throw new ConfigError(`unknown action: ${action} (known: connect, disconnect)`);
  }
  if (!existsSync(configDir(home))) return "absent";
  const path = configPath(home);
  const text = existsSync(path) ? readFileSync(path, "utf8") : null;
  const result = action === "connect" ? connectConfig(text, binary) : disconnectConfig(text);
  if (result.outcome !== "unchanged") writeAtomic(path, result.text);
  return result.outcome;
}
