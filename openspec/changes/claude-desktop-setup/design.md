# Design

## Context

Wobbo connects to Claude Code by copying the plugin it carries to `~/Library/Application Support/Wobbo/claude-plugin/` and installing it from there with the `claude` CLI (standalone-app D9). Claude Desktop has no plugin mechanism for chats; it starts the stdio MCP servers listed under `mcpServers` in `~/Library/Application Support/Claude/claude_desktop_config.json`, and only reads that file at start. Claude Desktop's Code tab also starts these servers for every Code session; the app already links that server to the Code session of the same project (claude-bridge design, "Claude Desktop's Code tab").

## Decisions

### D1. Part of "Connect to Claude Code", not a separate switch

Claude Desktop setup rides along with connecting to Claude Code: connect adds the entry, disconnect removes it, and the start-up update keeps it current. The menu and the welcome keep one item. Users think of "Claude", and a second switch would mostly confuse. Connect still needs the Claude Code CLI (the desktop app's own copy counts); a Mac with only Claude Desktop is out of scope.

### D2. The bridge edits the file

`wobbo-bridge claude-desktop connect` and `... disconnect` do the edit. Reasons:
- Godot's JSON parser turns every number into a float and writes `1` back as `1.0`; it would rewrite values in `preferences` that Wobbo does not own. The bridge uses JavaScript's `JSON`, like Claude Desktop.
- The entry's `command` is the bridge's own `process.execPath`, as `print-config` already does, so the path is always the binary that ran.

The edit is a pure function over the file text, so it is tested without touching the real file:
- `connect`: parse (missing or empty file = `{}`), set `mcpServers.wobbo = {command, args: ["mcp", "--agent", "claude-desktop"]}`, remove every other entry whose `command` ends in `/wobbo-bridge` or `/claude-buddy-bridge`, write with two-space indent and a trailing newline.
- `disconnect`: remove `mcpServers.wobbo` and the same stale entries; leave an empty `mcpServers` object in place.
- When nothing changes, the file is not written.
- Not valid JSON, or a top-level or `mcpServers` value that is not an object: exit 1 with a message, file untouched.
- Claude Desktop absent (no `~/Library/Application Support/Claude` folder): print `absent`, write nothing.

The write goes to a temporary file in the same folder, then renames over the original, keeping the original's mode.

Output: one word on stdout, `added`, `updated`, `unchanged`, `removed` or `absent`; exit 0. Errors go to stderr with exit 1.

### D3. Point at the copied bridge

Wobbo runs the bridge in `claude-plugin/plugins/wobbo/bin/` (the copy made on connect), so that is the path written into Claude Desktop's file. It does not move when Wobbo runs from a disk image or is moved, and it is replaced with the new version on every update. Replacing the binary while Claude Desktop runs it is safe on macOS: the running process keeps the old file.

Disconnect runs whichever bridge exists: the copy, or else the one inside Wobbo.

### D4. When it runs

- **Connect:** after the Claude Code steps succeed. A failure of the Desktop step does not fail the connect; it is reported in the result (`desktop_error`) and logged.
- **Disconnect:** after the Claude Code steps, whatever their outcome.
- **Start-up update:** when the plugin is installed at user scope, Wobbo runs `connect` for Claude Desktop even when the plugin itself is current. It is idempotent and quick. An `added` or `updated` result makes the welcome buddy say to restart Claude Desktop. This also re-adds the entry when the user removed it by hand; disconnecting from Wobbo's menu is the way to turn it off.

The result dictionary gains `desktop`: the bridge's word, or `""` when the step did not run.

### D5. Texts

- Connect, Desktop entry added or updated: "Done! New Claude Code sessions will show up as buddies, and after a restart of Claude Desktop its chats can talk through me too. Restart the sessions that are already open."
- Start-up, Desktop entry added or updated (plugin current): "I'm set up in Claude Desktop now. Restart Claude Desktop to use me in its chats."
- Start-up, plugin updated and Desktop entry changed: the update text plus "Restart Claude Desktop too."

### D6. Code-tab messages go to the session that sent them

*(Added after the clean-install test.)* Claude Desktop's Code tab starts the Desktop-configured server too, once per project, with client name `local-agent-mode-<name>`. The app linked it to the live session whose name is `<name>`. In the test, Claude Desktop called the project "wobbo" while the folder, and so the session's name, is `claude-buddy`: the message opened a new buddy labelled `local-agent-mode-wobbo`. Now that Wobbo adds the Desktop entry for every user, every Code-tab user would hit this.

When no session has that name, the app now takes the live Claude Code session hosted in the Claude app (its focus link starts with `claude:`) that was active last. The bridge resolves the session for every message, and the calling session's PreToolUse hook fires just before the call, so that session is the most recently active one. A Desktop server that still finds no session gets its own buddy named "Claude Desktop" instead of the raw client name.

## Risks

- **Claude Desktop rewrites its file from memory.** If Claude Desktop keeps the configuration in memory and writes it back when the user changes a setting, it could drop the entry until Wobbo's next start. Task 4.2 checks this by hand; Wobbo's start-up step limits the damage either way.
- **Users who keep a hand-made entry under another name** pointing at a `wobbo-bridge` (for example a development build) lose it on connect. That is intended: two servers would show each message twice.
- **Code tab tools twice.** In Claude Desktop's Code tab, a session sees both the plugin's tools and the Desktop server's tools. This was already true for anyone with the manual entry, and the app links both to the same session.
