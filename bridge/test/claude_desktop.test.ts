import { afterEach, beforeEach, expect, test } from "bun:test";
import { mkdirSync, mkdtempSync, readFileSync, rmSync, statSync, writeFileSync, chmodSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import {
  configDir,
  configPath,
  connectConfig,
  disconnectConfig,
  runClaudeDesktop,
  wobboEntry,
} from "../src/claude_desktop";

const BIN = "/Users/me/Library/Application Support/Wobbo/claude-plugin/plugins/wobbo/bin/wobbo-bridge";

const existing = {
  mcpServers: {
    other: { command: "/usr/local/bin/other", args: ["serve"] },
    "claude-buddy": { command: "/Users/me/claude-buddy/bridge/plugin/bin/claude-buddy-bridge", args: ["mcp"] },
  },
  coworkUserFilesPath: "/Users/me/Claude",
  preferences: { sidebarMode: "chat", zoom: 1, ratio: 1.5, big: 12345678901 },
};

test("connect on no file creates just the entry", () => {
  const r = connectConfig(null, BIN);
  expect(r.outcome).toBe("added");
  expect(JSON.parse(r.text)).toEqual({ mcpServers: { wobbo: wobboEntry(BIN) } });
  expect(r.text.endsWith("}\n")).toBe(true);
});

test("connect on an empty file", () => {
  expect(connectConfig("  \n", BIN).outcome).toBe("added");
});

test("connect keeps other servers and values and drops stale bridges", () => {
  const r = connectConfig(JSON.stringify(existing, null, 2), BIN);
  expect(r.outcome).toBe("added");
  const data = JSON.parse(r.text);
  expect(data.mcpServers.other).toEqual(existing.mcpServers.other);
  expect(data.mcpServers["claude-buddy"]).toBeUndefined();
  expect(data.mcpServers.wobbo).toEqual(wobboEntry(BIN));
  expect(data.preferences).toEqual(existing.preferences);
  expect(data.coworkUserFilesPath).toBe(existing.coworkUserFilesPath);
  expect(r.text).toContain('"zoom": 1,');
});

test("connect twice is unchanged and returns the text as it was", () => {
  const once = connectConfig(null, BIN).text;
  const twice = connectConfig(once, BIN);
  expect(twice.outcome).toBe("unchanged");
  expect(twice.text).toBe(once);
});

test("connect with another path updates the entry", () => {
  const once = connectConfig(null, "/old/wobbo-bridge").text;
  const r = connectConfig(once, BIN);
  expect(r.outcome).toBe("updated");
  expect(JSON.parse(r.text).mcpServers.wobbo.command).toBe(BIN);
});

test("a second entry running wobbo-bridge counts as a change", () => {
  const text = JSON.stringify({ mcpServers: { wobbo: wobboEntry(BIN), "wobbo-dev": wobboEntry("/repo/wobbo-bridge") } });
  const r = connectConfig(text, BIN);
  expect(r.outcome).toBe("updated");
  expect(Object.keys(JSON.parse(r.text).mcpServers)).toEqual(["wobbo"]);
});

test("invalid JSON or a wrong shape throws", () => {
  expect(() => connectConfig("{ not json", BIN)).toThrow("not valid JSON");
  expect(() => connectConfig("[]", BIN)).toThrow("not a JSON object");
  expect(() => connectConfig('{"mcpServers": []}', BIN)).toThrow("mcpServers");
  expect(() => disconnectConfig("{ not json")).toThrow("not valid JSON");
});

test("disconnect removes Wobbo's entries and keeps the rest", () => {
  const connected = connectConfig(JSON.stringify(existing), BIN).text;
  const withStale = JSON.parse(connected);
  withStale.mcpServers["claude-buddy"] = existing.mcpServers["claude-buddy"];
  const r = disconnectConfig(JSON.stringify(withStale));
  expect(r.outcome).toBe("removed");
  const data = JSON.parse(r.text);
  expect(data.mcpServers).toEqual({ other: existing.mcpServers.other });
  expect(data.preferences).toEqual(existing.preferences);
});

test("disconnect without an entry or a file is unchanged", () => {
  expect(disconnectConfig(null).outcome).toBe("unchanged");
  expect(disconnectConfig('{"preferences": {}}').outcome).toBe("unchanged");
  expect(disconnectConfig('{"mcpServers": {"other": {"command": "x"}}}').outcome).toBe("unchanged");
});

let home = "";

beforeEach(() => {
  home = mkdtempSync(join(tmpdir(), "wobbo-desktop-"));
});

afterEach(() => {
  rmSync(home, { recursive: true, force: true });
});

test("no Claude Desktop folder: absent, nothing written", () => {
  expect(runClaudeDesktop("connect", home, BIN)).toBe("absent");
  expect(runClaudeDesktop("disconnect", home, BIN)).toBe("absent");
  expect(() => statSync(configDir(home))).toThrow();
});

test("connect and disconnect on disk, keeping the file mode", () => {
  mkdirSync(configDir(home), { recursive: true });
  writeFileSync(configPath(home), JSON.stringify(existing, null, 2));
  chmodSync(configPath(home), 0o600);
  expect(runClaudeDesktop("connect", home, BIN)).toBe("added");
  expect(statSync(configPath(home)).mode & 0o777).toBe(0o600);
  const written = readFileSync(configPath(home), "utf8");
  expect(JSON.parse(written).mcpServers.wobbo).toEqual(wobboEntry(BIN));
  const mtime = statSync(configPath(home)).mtimeMs;
  expect(runClaudeDesktop("connect", home, BIN)).toBe("unchanged");
  expect(statSync(configPath(home)).mtimeMs).toBe(mtime);
  expect(runClaudeDesktop("disconnect", home, BIN)).toBe("removed");
  expect(JSON.parse(readFileSync(configPath(home), "utf8")).mcpServers.wobbo).toBeUndefined();
});

test("Claude Desktop folder without a file: connect creates it", () => {
  mkdirSync(configDir(home), { recursive: true });
  expect(runClaudeDesktop("connect", home, BIN)).toBe("added");
  expect(JSON.parse(readFileSync(configPath(home), "utf8"))).toEqual({ mcpServers: { wobbo: wobboEntry(BIN) } });
});

test("a broken file is left untouched", () => {
  mkdirSync(configDir(home), { recursive: true });
  writeFileSync(configPath(home), "{ broken");
  expect(() => runClaudeDesktop("connect", home, BIN)).toThrow();
  expect(readFileSync(configPath(home), "utf8")).toBe("{ broken");
});

test("unknown action throws", () => {
  expect(() => runClaudeDesktop("fix", home, BIN)).toThrow("unknown action");
});
