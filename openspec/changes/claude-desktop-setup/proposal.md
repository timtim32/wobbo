# Proposal

## Why

Claude Desktop chats can only reach Wobbo through an `mcpServers` entry in `~/Library/Application Support/Claude/claude_desktop_config.json`. Today the user has to add that entry by hand, with a path into `Wobbo.app`. That is the only setup step left that needs a text editor, and Wobbo's rule is that installing, connecting and updating happen by clicking in Wobbo.

The manual entry also goes stale. After the rename from Claude Buddy, entries named `claude-buddy` still point at a `claude-buddy-bridge` binary that no longer exists, so Claude Desktop silently fails to start that server.

## What Changes

- **Connect also sets up Claude Desktop.** When the user connects Wobbo to Claude Code and Claude Desktop is on the Mac, Wobbo writes its `wobbo` entry into Claude Desktop's configuration. The entry points at the bridge in Wobbo's own data folder, the same stable copy the Claude Code plugin is installed from.
- **Stale entries are replaced.** Any other entry whose command is a `wobbo-bridge` or `claude-buddy-bridge` binary is removed, so Claude Desktop runs one Wobbo server.
- **Everything else in the file stays as it is.** Other servers, preferences and keys are kept. A file that is not valid JSON is left untouched, and Wobbo says so.
- **Disconnect removes it again.** Disconnecting from Claude Code also removes the `wobbo` entry.
- **Kept current on start.** While Wobbo is connected, each start makes sure the entry is there and points at the right bridge. This also sets up Claude Desktop for users who connected before this change, and for users who install Claude Desktop later.
- **Restart hint.** Claude Desktop reads its configuration only at start. When Wobbo added or changed the entry, the balloon says to restart Claude Desktop.
- **The bridge does the file edit.** A new command `wobbo-bridge claude-desktop connect|disconnect` edits the file. The bridge is written in TypeScript, so it reads and writes the JSON the same way Claude Desktop itself does.
- **README:** the manual step disappears; `print-config claude-desktop` stays for development.

### Out of scope

- **Macs with Claude Desktop but no Claude Code CLI.** Connecting still needs Claude Code (the Claude desktop app's own copy counts). Without it, Wobbo says Claude Code was not found, as today, and changes nothing.
- **A separate menu item or state for Claude Desktop.** The menu keeps one "Connect to Claude Code" item; its state is Claude Code's plugin.
- **Restarting Claude Desktop for the user.**
- **Claude Desktop on Windows or Linux.**

## Capabilities

### New Capabilities
- `claude-desktop-setup`: Wobbo adds, keeps current and removes its entry in Claude Desktop's MCP configuration as part of connecting to Claude Code.

### Modified Capabilities
- `agent-bridge`: installation for Claude Desktop is done by Wobbo instead of documented as a manual step; the bridge gets the `claude-desktop` command.

## Impact

- **Bridge (`bridge/`):** new `src/claude_desktop.ts` (pure edit functions and the file write), wired into `src/main.ts`; tests in `test/claude_desktop.test.ts`.
- **Godot app (`godot/`):** `ClaudeSetup` runs the copied bridge after connecting, after disconnecting and on start; the welcome texts mention Claude Desktop when its entry changed. Tests in `test_claude_setup.gd`.
- **README:** the Claude Desktop section.
- **User's machine:** Wobbo now writes to `claude_desktop_config.json`. The edit is atomic (temporary file, then rename) and keeps the file's permissions.
