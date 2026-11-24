import { expect, test } from "bun:test";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { BRIDGE_VERSION } from "../src/protocol";

const readJson = (path: string) => JSON.parse(readFileSync(join(import.meta.dir, "..", path), "utf8"));

// The bridge's version is written in three places, each read by a different tool (Bun, the
// compiled binary, Claude Code's plugin manager); a release bumps all three.
test("package.json, BRIDGE_VERSION and the plugin manifest carry the same version", () => {
  expect(readJson("package.json").version).toBe(BRIDGE_VERSION);
  expect(readJson("plugin/.claude-plugin/plugin.json").version).toBe(BRIDGE_VERSION);
});

// The app's version (tools/release.sh sets one version for app and plugin).
test("the app's project settings and export preset carry the bridge's version", () => {
  const godot = (path: string) => readFileSync(join(import.meta.dir, "..", "..", "godot", path), "utf8");
  expect(godot("project.godot")).toContain(`config/version="${BRIDGE_VERSION}"`);
  expect(godot("export_presets.cfg")).toContain(`application/short_version="${BRIDGE_VERSION}"`);
});
