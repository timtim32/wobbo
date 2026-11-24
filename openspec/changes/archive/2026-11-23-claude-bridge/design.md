# Design: claude-bridge

## Context

The app is a Godot 4.7.2 overlay (GL Compatibility, 30 fps) with a `Settings` and an `Overlay` autoload, a `Monster` scene that plays the clips `idle`, `thinking`, `working`, `waiting`, `happy`, `error` and others, and a debug mode toggled from the menu bar. Nothing in the app talks to the outside world yet.

On this machine, Bun 1.4, Node 24 and Claude Code 2.1.322 are installed. The user's global `~/.claude/settings.json` already has a `PreToolUse` hook of its own, and must not be edited by this change.

Facts from the current Claude Code documentation (hooks, plugins, MCP pages, read on 2026-11-23) that shape this design:
- **Hook input:** every hook gets `session_id`, `cwd`, `hook_event_name` and `transcript_path` on stdin, and `CLAUDE_PROJECT_DIR` in its environment. `"async": true` hooks run without Claude waiting for them. `PermissionRequest` hooks can return `{"hookSpecificOutput":{"hookEventName":"PermissionRequest","decision":{"behavior":"allow|deny","message":...}}}`, and with no output Claude Code shows its own prompt.
- **Working and idle:** `UserPromptSubmit` and `Stop`/`StopFailure` mark exactly when Claude starts and finishes a turn. `Notification` with `idle_prompt` comes about 60 s late, so it is not used for state.
- **Session ID in MCP:** a stdio MCP server spawned by Claude Code gets `CLAUDE_PROJECT_DIR` and `CLAUDECODE=1`, but no documented session ID.
- **MCP wait limits:** tool calls have a very long default time-out, but an idle time-out of 30 minutes for stdio servers. Progress notifications reset that idle timer. After 2 minutes, a long call moves to a background task.
- **Plugins:** a plugin declares hooks (`hooks/hooks.json`) and MCP servers (`.mcp.json`), using `${CLAUDE_PLUGIN_ROOT}` for paths. It is installed from a marketplace directory with `claude plugin marketplace add` and `claude plugin install`.

See proposal.md for motivation, and the specs for the required behaviour.

## Goals / Non-Goals

**Goals:**
- One protocol and one bridge binary, with all agent-specific code in small adapters.
- Zero impact on the agent when the app is closed, and near-zero impact when it is open.
- Make every link testable on its own: the protocol and the registry in tests, the bridge with `bun test`, and the app endpoint with a test client.

**Non-Goals:**
- A daemon or background service. Short-lived hook processes and per-session MCP processes connect directly to the app.
- Persisting sessions across app restarts. A restarted app learns about sessions again from their next event.

## Decisions

### D1. The app is the server; bridge processes are short-lived clients
The Godot app runs a WebSocket server (Godot `TCPServer` bound to `127.0.0.1` plus `WebSocketPeer.accept_stream()`), polled in `_process`. The bridge connects to it in two ways:
- Each **hook invocation** opens a connection, sends one message, and closes it. A permission request waits for its decision before closing.
- Each **MCP server process** (one per agent session) keeps one connection open while it runs.

No separate daemon is needed, so there is nothing extra to install or to keep running.
- *Alternatives:* a bridge daemon that the app and the hooks both talk to has an extra moving part and its own lifecycle. An HTTP endpoint per hook works, but MCP needs a long-lived channel for answers anyway. Both rejected.

### D2. Discovery and authentication: `bridge.json` in the app's settings folder
On start, the app:
- tries port 47321 on 127.0.0.1, then up to 10 ports after it;
- generates a random 32-byte token (`Crypto.generate_random_bytes`);
- writes `{"port", "token", "pid", "protocol": 1}` to `~/Library/Application Support/ClaudeBuddy/bridge.json` with mode 0600 (via `OS.execute("chmod", ...)`, as Godot has no chmod API).

On quit the app deletes the file. A stale file, from a crash, is detected by the bridge because the connection fails or the `pid` is not running.

Every client's first message is `hello` with the token. On a wrong token the app closes the socket. The token guards against other local processes; loopback binding guards against the network.

### D3. Protocol (version 1), JSON text frames
Envelope: `{"v":1,"type":...}`. The full schema lives in `bridge/PROTOCOL.md`, with TypeScript types in `bridge/src/protocol.ts` and GDScript constants in `godot/scripts/bridge/protocol.gd`.

| Direction | Message | Purpose |
|---|---|---|
| client → app | `hello {token, client: {role: "hook"\|"mcp", agent, pid, ppid, project_dir, agent_session_id?}}` | Authenticate and identify. |
| client → app | `event {session, kind, data}` | Report activity. `kind` is one of `session_start`, `prompt`, `tool_start`, `tool_end`, `tool_error`, `notification`, `turn_end`, `turn_error`, `session_end`. |
| client → app | `say {session, text}` | Show a message. |
| client → app | `request {id, session, kind: "question"\|"permission", text, choices[], allow_text, timeout_s}` | Ask something that needs an answer. |
| client → app | `cancel {id}` | The asker gave up. |
| app → client | `welcome {app_version}` / `error {reason}` | Reply to `hello`. |
| app → client | `answer {id, status: "answered"\|"dismissed", choice?, text?}` | The user's answer. |

`session` is `{id, agent, project_dir}`.

The app derives states from events in a pure `SessionRegistry` class (unit tested):

| Event | State |
|---|---|
| `prompt` | `thinking` |
| `tool_start` | `working` (with the tool name) |
| `tool_end` | `thinking` |
| `tool_error` | stays `thinking`, and stores the error as the last problem |
| `turn_end` | `done` |
| `turn_error` | `error` |
| pending request | `waiting` (when it ends, the state goes back to what it was) |
| `session_start` | `idle` |
| `session_end` | `ended` (removed 5 s later) |

Sessions idle for 30 minutes without a connection are removed.

### D4. Bridge program: Bun + TypeScript, one compiled binary
Layout:
- `bridge/src/protocol.ts`: shared types.
- `bridge/src/app_client.ts`: reads `bridge.json`, connects with a 200 ms connect time-out, sends `hello`.
- `bridge/src/adapters/claude_code.ts`: maps hook stdin to events and requests.
- `bridge/src/mcp_server.ts`: the MCP server, using `@modelcontextprotocol/sdk` over stdio.
- `bridge/src/main.ts`: the command line, `claude-buddy-bridge hook <agent>` and `claude-buddy-bridge mcp [--agent <name>]`.

`bun build --compile` produces `bridge/dist/claude-buddy-bridge`, so there is no runtime dependency on Bun for users. A new agent later is a new file in `adapters/` plus its install docs; the app and the protocol stay unchanged.

Errors never reach the agent. Every hook path catches everything and exits 0 without output, unless it has a decision to give. The MCP tools return text results (`"buddy not available, ask in the conversation instead"`), never protocol errors, so the model can act on them.

### D5. Claude Code hooks: async for status, sync only for permissions
`bridge/plugin/hooks/hooks.json` registers the bridge binary for:
- **`async: true`:** `SessionStart`, `UserPromptSubmit`, `PreToolUse`, `PostToolUse`, `PostToolUseFailure`, `Notification`, `Stop`, `StopFailure`.
- **Sync with a 1.5 s budget:** `SessionEnd`, which is the documented default.
- **Sync, `timeout: 60`:** `PermissionRequest`.

The status hooks therefore never delay Claude. The `PermissionRequest` hook sends a `permission` request and waits up to `PERMISSION_WAIT_S` (default 20 s) for an answer. On `allow` or `deny` it prints the decision JSON. On time-out, dismissal or no app, it prints nothing, and Claude Code shows its own prompt.

- **Spike S1:** check whether Claude Code holds its own permission prompt back while the hook waits, and whether the wait feels acceptable. **Fallback:** cut the wait to about 3 s. With "no decision", the app only notifies, and the user answers in the terminal. The spec's "No decision in the app" scenario covers both.
- **Result S1 (task 3.4, 2026-11-23, Claude Code 2.1.322):** passed, no fallback needed.
  - **Allow:** Claude runs the command without its own prompt.
  - **Deny:** Claude does not run it and reports that it was denied.
  - **No decision:** Claude Code shows its own permission prompt after the wait.
  - **Wait:** the user found the default `PERMISSION_WAIT_S` of 20 s good, so it stays. It can be set with `CLAUDE_BUDDY_PERMISSION_WAIT_S`.
- **Spike S2:** measure the hook overhead: the compiled binary's start-up plus connecting and sending one message. The target is under 50 ms per hook; async hooks hide most of it anyway. **Fallback:** subscribe to fewer events, dropping `PostToolUse`, since `PreToolUse` and `Stop` carry most of the state.
- **Result S2 (task 3.3, 2026-11-23, M5 Pro, app at 30 fps):**
  - **Start-up:** the compiled binary starts in 13 ms.
  - **App closed:** a hook takes 15 ms on average (p95 17 ms).
  - **App running:** the first version took 107 ms, because it went through two round trips that each wait for the app's next frame: `welcome`, then the close. Status hooks now send `hello` and the event together without waiting for `welcome` (`sendOnce`), which gives 73 ms on average (p95 68 ms).
  - **Why this is fine:** the rest is the app's frame rate. The status hooks are `async`, so Claude never waits for them. A status change reaches the app within about 70 ms.
  - **Not done:** polling the server faster than the frame rate (a thread). Dropping events (the fallback) is not needed.

  *Protocol change found here:* Godot's `WebSocketPeer` drops a frame that arrives in the same poll as the peer's close frame. So for hook connections the app now closes the connection after handling the message, and the hook waits for that close (`PROTOCOL.md`, "Hook connections").

### D6. MCP session identity: parent PID correlation (spike S3)
The hooks and the MCP server of one Claude Code session are both children of the same `claude` process. The hook adapter sends `ppid` together with `session_id`. The MCP server sends its own `ppid` together with `CLAUDE_PROJECT_DIR`. The app's registry links an MCP connection to the hook session with the same `ppid`, and attributes `say` and `ask_user` to it.

- **Spike S3:** verify on macOS that `process.ppid` is the same `claude` PID in a hook process and in the MCP server, also after `/clear` (which gives a new `session_id`). **Fallback:** link by `project_dir` to the most recently active Claude Code session in that directory. If that is ambiguous, show the message on a separate MCP session named after the project.
- **Result S3 (task 4.2, 2026-11-23, Claude Code 2.1.322, plugin installed at user scope):** passed. In a running session, the hooks reported ppid 92257 and the plugin's MCP server (pid 36828) reported ppid 92257 too. `say` landed on that hooked session ("claude-buddy"), not on a separate MCP session. This works because the hook command starts with `exec`: Claude Code runs hook commands through a shell, and without `exec` the shell would be the parent. **After `/clear` (checked by hand, 2026-11-23):** the old session ends and is removed after 5 s. A new session with the same project name appears and gets the following messages, with no stray session. In the Code tab, `/clear` also gave the session a new parent process (ppid 51777 → 52260); that does not matter, because the new session's hooks report the new ppid. The registry links to the most recently active live session with that ppid, and the old one ends on `SessionEnd`.

**Claude Desktop's Code tab (found during testing):** besides the plugin's own MCP server (which links by ppid), Claude Desktop runs the Desktop-configured MCP server for the Code tab as well: one instance per project, shared by that project's Code sessions. In the test, two sessions in `claude-buddy` used the same instance (pid 47924). It runs under the Claude app, not under Claude Code, so its ppid never matches, and its MCP client name is `local-agent-mode-<project name>`. The registry links such a client to the most recently active live session with that display name, of any agent. *(Added after a test: without this, a `say` through that server opened a stray session.)* **Known limitation:** when two Code sessions in the same project are active at once, a message through this server goes to the more recently active one. The plugin's tools do not have this problem, because they link by ppid.

For agents without hooks (Claude Desktop), the MCP connection is the session. Its id is `mcp:<pid>`, and its name is the MCP client's name from the MCP `initialize` handshake (`clientInfo.name`), for example "Claude Desktop".

### D7. `ask_user` waiting: progress notifications and a time-out
`ask_user(question, choices?, allow_text?, timeout_s?)` sends a `request` and waits for its `answer`.
- **Waiting:** while waiting, it sends an MCP progress notification every 20 s, which keeps the client's idle timer alive (30 min for stdio in Claude Code).
- **Time-out:** the default is 600 s and the maximum 1800 s. On time-out it sends `cancel` and returns "no answer".
- **App absent:** if the app is not available, it returns at once.

The tool's description tells the model to use `ask_user` only when the user is likely away from the conversation, and to keep questions short.
- **Spike S4:** check how Claude Desktop handles a tool call that waits several minutes, and how Claude Code handles one that moves to a background task after 2 minutes. **Fallback:** cap the default time-out at 110 s, below the 2-minute background threshold, and document the limit.
- **Result S4, Claude Code (task 4.3, 2026-11-23, Claude Code 2.1.322, desktop app Code tab):** passed. An `ask_user` answered after about 3 minutes returned the answer normally in the same tool call. The call was not visibly moved to a background task, and there was no time-out or interruption in the conversation. The default time-out stays at 600 s. **Claude Desktop (task 5.2):** an `ask_user` from a Desktop chat that was answered after about 3 minutes also reached the chat normally. The 110 s fallback is not needed.

`say(text)` returns right away: "shown", or "buddy not available".

### D8. Packaging: plugin in the repo, local marketplace, Desktop by documentation
- **Plugin:** `bridge/plugin/` contains:
  - `.claude-plugin/plugin.json` (name `claude-buddy`);
  - `hooks/hooks.json`;
  - `.mcp.json` (server `buddy`, `${CLAUDE_PLUGIN_ROOT}/bin/claude-buddy-bridge mcp --agent claude-code`);
  - `bin/`, which holds the compiled binary. The build copies it there; it is ignored by git.
- **Marketplace:** the repo root gets `.claude-plugin/marketplace.json`, listing the plugin by relative path. Install: `claude plugin marketplace add ./` and then `claude plugin install claude-buddy@claude-buddy --scope user`. During development, `claude --plugin-dir bridge/plugin` loads it for one session.
- **Claude Desktop:** the README gives the `mcpServers` entry for `~/Library/Application Support/Claude/claude_desktop_config.json`, pointing at the absolute path of the compiled binary with `mcp --agent claude-desktop`. `claude-buddy-bridge print-config claude-desktop` prints that entry with the right path. The bridge never edits the user's configuration files itself.

### D9. App side: `Bridge` autoload, `SessionRegistry`, debug panel
- **`godot/scripts/bridge/bridge_server.gd`** (autoload `Bridge`): the server, the handshake and message routing. Signals: `session_added`, `session_changed`, `session_removed`, `message_received`, `request_added`, `request_removed`. Method: `answer_request(id, choice, text)`.
- **`godot/scripts/core/session_registry.gd`**: pure state logic, covered by headless tests, as in D3.
- **`godot/scripts/debug/session_panel.gd`**: a `PanelContainer` at the top-left of the strip. Shown only in debug mode, it registers its rect as an overlay region. For each session it shows the agent, name, state and last message. Pending requests get buttons for their choices or Allow/Deny, a text field when free text is allowed (using `Overlay.request_keyboard_focus`), and Dismiss.
- **Debug monster:** it follows the most recently active session. The states map to clips like this:

  | State | Clip |
  |---|---|
  | `idle` | `idle` |
  | `thinking` | `thinking` |
  | `working` | `working` |
  | `waiting` | `waiting` |
  | `done` | `happy`, then `idle` |
  | `error` | `error` |
  | `ended` | `wave` |

  It stops walking while a session is busy.

### Godot and macOS assumptions
- Godot 4.7: `TCPServer.listen(port, "127.0.0.1")`, `WebSocketPeer.accept_stream()`, `Crypto.generate_random_bytes()`, `OS.get_user_data_dir()` (ClaudeBuddy custom user dir), `OS.execute("chmod")`.
- macOS: `process.ppid` semantics (spike S3); `claude_desktop_config.json` location on macOS.
- No new GDExtension code.

## Risks / Trade-offs

- [Async hooks may arrive out of order, for example a `tool_start` after a `turn_end`] → Every frame carries the client time `ts` in milliseconds. The registry ignores a state change older than the last one it applied for that session; `session_end` always applies. *(Changed during implementation:)* a per-process sequence number was dropped, because every hook runs as its own short-lived process, so such a number says nothing about order.
- [A malicious local process could read the token] → It is readable only by the user, and a process running as the user can do far worse. Accepted, and documented.
- [Waiting permission hooks slow the user down when the app shows the prompt in a place they do not look] → Short wait, with the fallback to the terminal (S1). Later, `balloons-and-speech` makes the prompt prominent.
- [Claude Desktop runs one MCP server for all chats] → One "Claude Desktop" session in the app. Documented as a known limitation.
- [The bridge binary in the plugin's `bin/` must be rebuilt after source changes] → `bun run build` copies it. The README says so, and the plugin's hooks log a version mismatch to the app in debug mode.
- [Port 47321 taken] → Try the next 10 ports. The actual port is in `bridge.json`.

## Migration Plan

None for data. Users install the plugin once, and can uninstall it with `claude plugin uninstall claude-buddy`.

## Open Questions

- None. The permission wait (20 s) was confirmed in spike S1.
