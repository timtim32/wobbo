// Configuration snippets for agents that are set up by hand (claude-bridge D8).

/** Returns the snippet for `target`, or "" for an unknown target. */
export function printConfig(target: string, binaryPath: string): string {
  switch (target) {
    case "claude-desktop":
      return JSON.stringify(
        { mcpServers: { wobbo: { command: binaryPath, args: ["mcp", "--agent", "claude-desktop"] } } },
        null,
        2,
      );
    default:
      return "";
  }
}
