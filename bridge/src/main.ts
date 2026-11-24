#!/usr/bin/env bun
// wobbo-bridge: connects coding agents to the Wobbo app.
//
//   wobbo-bridge hook claude-code         (Claude Code hook; JSON on stdin)
//   wobbo-bridge mcp [--agent <name>]     (MCP server on stdio)
//   wobbo-bridge print-config <target>    (configuration snippet, e.g. claude-desktop)
//   wobbo-bridge claude-desktop connect|disconnect   (edit Claude Desktop's MCP configuration)
//   wobbo-bridge --version
import { BRIDGE_VERSION } from "./protocol";

const USAGE = `wobbo-bridge ${BRIDGE_VERSION}
usage:
  wobbo-bridge hook claude-code
  wobbo-bridge mcp [--agent <name>]
  wobbo-bridge print-config claude-desktop
  wobbo-bridge claude-desktop connect|disconnect
  wobbo-bridge --version`;

async function main(argv: string[]): Promise<number> {
  const [command, ...rest] = argv;
  switch (command) {
    case "--version":
    case "version":
      console.log(BRIDGE_VERSION);
      return 0;
    case "hook": {
      // Hooks must never disturb the agent: always exit 0, print only decisions.
      try {
        if (rest[0] !== "claude-code") return 0;
        const { runHook } = await import("./adapters/claude_code");
        const out = await runHook(await Bun.stdin.text());
        if (out) process.stdout.write(out);
      } catch {}
      return 0;
    }
    case "mcp": {
      const i = rest.indexOf("--agent");
      const agent = i >= 0 && rest[i + 1] ? rest[i + 1] : "mcp";
      const { runMcpServer } = await import("./mcp_server");
      await runMcpServer(agent);
      return -1; // keep running; the transport ends the process
    }
    case "print-config": {
      const { printConfig } = await import("./print_config");
      const out = printConfig(rest[0] ?? "", process.execPath);
      if (!out) {
        console.error(`unknown target: ${rest[0] ?? ""} (known: claude-desktop)`);
        return 2;
      }
      console.log(out);
      return 0;
    }
    case "claude-desktop": {
      const { runClaudeDesktop } = await import("./claude_desktop");
      try {
        console.log(runClaudeDesktop(rest[0] ?? "", process.env.HOME ?? "", process.execPath));
        return 0;
      } catch (e) {
        console.error(e instanceof Error ? e.message : String(e));
        return 1;
      }
    }
    default:
      console.error(USAGE);
      return command ? 2 : 0;
  }
}

const code = await main(process.argv.slice(2));
if (code >= 0) process.exit(code);
