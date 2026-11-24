import { expect, test } from "bun:test";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { BRIDGE_VERSION } from "../src/protocol";

const readJson = (path: string) => JSON.parse(readFileSync(join(import.meta.dir, "..", path), "utf8"));

// The version is written in three places, each read by a different tool (Bun, the
// compiled binary, Claude Code's plugin manager); a release bumps all three.
test("package.json, BRIDGE_VERSION and the plugin manifest carry the same version", () => {
  expect(readJson("package.json").version).toBe(BRIDGE_VERSION);
  expect(readJson("plugin/.claude-plugin/plugin.json").version).toBe(BRIDGE_VERSION);
});
