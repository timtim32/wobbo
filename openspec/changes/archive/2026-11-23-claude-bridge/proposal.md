# Proposal: claude-bridge

## Why

The overlay and the monster exist, but they do not know anything about Claude yet. The buddy is only useful once it shows what each coding session is doing and lets Claude talk to the user on purpose. This change builds that connection, before `session-avatars` and `balloons-and-speech` give it a face. It is designed from the start to serve more than Claude Code: Claude Desktop now, and Codex and other coding agents later.

## What Changes

- Add a small **agent-neutral protocol** (JSON over a local WebSocket on 127.0.0.1) between coding agents and the Claude Buddy app. It covers sessions, their state, messages and requests that wait for an answer.
- Make the Godot app the **WebSocket endpoint**. It accepts connections only from this machine and only with a per-install token, which the app writes to its settings folder together with the port.
- Track **sessions and their state** in the app: starting, idle, thinking, working, waiting for the user, done, error, ended. Expose the sessions as signals for later changes.
- Add a **bridge program** in `bridge/` (Bun + TypeScript, compiled to a single binary) with two roles:
  - **Hook adapter for Claude Code:** turns Claude Code hook events into protocol events. It never slows Claude down and does nothing when the app is not running.
  - **MCP server:** works with any MCP client (Claude Code, Claude Desktop, and later others). Its tools are `say` (show a message) and `ask_user` (ask a question with optional choices or free text, and wait for the answer).
- Support **requests that wait for the user**: `ask_user` questions and Claude Code permission prompts (Allow/Deny). The answers come from the app, with time-outs and a fallback to the agent's own prompt.
- Package the Claude Code side as a **local Claude Code plugin** (hooks plus MCP server), installable from a marketplace in this repository, so the user's own `settings.json` is not edited.
- Document and support **Claude Desktop** through its MCP configuration.
- Add a temporary **debug panel** in the overlay (debug mode only). It lists sessions, shows their state and the last message, and lets the user answer pending requests. The walking debug monster plays the clip that matches the most recently active session's state.

### Out of scope

- Avatars per session, walking and moods (`session-avatars`). The debug monster only mirrors one session, as a demo.
- Speech balloons, TTS and the real answer UI (`balloons-and-speech`). This change only adds the debug panel.
- Click-to-focus on the session's terminal window, drag & drop and the right-click menu (`avatar-interactions`).
- Adapters for Codex or other agents. The protocol and the bridge get a clear extension point (an `agent` field and an adapter module per agent), but only Claude Code hooks and generic MCP are built.
- Detecting failing tests or build errors from tool output. The bridge forwards tool results; interpreting them belongs to a later change.
- Remote or multi-machine use, code signing, and a distributable installer.

## Capabilities

### New Capabilities

- `agent-bridge`: the bridge program and its integrations. Covers the hook adapter for Claude Code, the MCP server and its tools, behaviour when the app is absent, and installation for Claude Code (plugin) and Claude Desktop (MCP configuration).
- `session-tracking`: the app side of the connection. Covers the local endpoint and its security, the list of sessions and their states, messages, and requests that wait for an answer from the user.

### Modified Capabilities

None. The overlay's debug view and the debug monster are not specified, so the debug panel and the monster mirroring a session change no requirement.

## Impact

- **New code:** `bridge/` (Bun project: protocol types, app client, Claude Code hook adapter, MCP server, tests), `bridge/plugin/` (the Claude Code plugin), `.claude-plugin/marketplace.json` (local marketplace), and in `godot/` a `Bridge` autoload, a session registry and the debug panel.
- **Changed code:** `godot/scripts/debug/debug_blob.gd` plays clips that follow a session's state.
- **New dependencies:** Bun (already installed) and the MCP TypeScript SDK (`@modelcontextprotocol/sdk`) from npm.
- **User's machine:** the plugin is installed with `claude plugin install` (user scope). Claude Desktop needs one entry in `claude_desktop_config.json`, which is documented and not written automatically.
- **Security:** the app listens on 127.0.0.1 only and rejects connections without the token. The token file is readable only by the user.
