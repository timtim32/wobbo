import { expect, test } from "bun:test";
import { printConfig } from "../src/print_config";

test("claude-desktop config points at the binary with the mcp command", () => {
  const cfg = JSON.parse(printConfig("claude-desktop", "/opt/wobbo/wobbo-bridge"));
  expect(cfg).toEqual({
    mcpServers: { wobbo: { command: "/opt/wobbo/wobbo-bridge", args: ["mcp", "--agent", "claude-desktop"] } },
  });
});

test("unknown target gives nothing", () => {
  expect(printConfig("codex", "/x")).toBe("");
});
