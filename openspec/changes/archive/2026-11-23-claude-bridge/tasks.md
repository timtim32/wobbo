# Tasks

## 1. Protocol and app endpoint

- [x] 1.1 Write `bridge/PROTOCOL.md` (protocol version 1: envelope, `hello`/`welcome`/`error`, `event` kinds, `say`, `request`, `cancel`, `answer`, session object, `ts` timestamps) and the matching GDScript constants in `godot/scripts/bridge/protocol.gd`. Verify: every message type in design D3 is documented with an example.
- [x] 1.2 Implement the pure `SessionRegistry` (`godot/scripts/core/session_registry.gd`): sessions keyed by id, display name from the project directory, state transitions from D3, pending requests (state `waiting`, restore after), out-of-order protection by timestamp, removal 5 s after `ended`, and removal after 30 min idle without a connection, plus linking MCP connections to hook sessions by `ppid` with the `project_dir` fallback (D6). Verify: headless tests cover every transition, a request, out-of-order events, both removals and both linking paths.
- [x] 1.3 Implement the `Bridge` autoload (D1, D2, D9): loopback `TCPServer` with port fallback, a token, a `bridge.json` written with mode 0600 and deleted on quit, a `hello` check, message routing to the registry, signals, `answer_request()`, and cancel on disconnect. Verify: a headless test client in GDScript connects with the right token and gets `welcome`, and gets closed with a wrong token; `ls -l` shows `-rw-------` on `bridge.json`; the file is gone after quitting.
- [x] 1.4 Add the debug session panel (D9): it lists sessions with agent, name, state and last message, has answer, dismiss and free-text controls for pending requests, registers its overlay region, and is only shown in debug mode. Verify: with a test client sending a session, a `say` and a question, a game screenshot shows the panel, and answering via `game_eval` sends the `answer`.
- [x] 1.5 Manual check: with debug mode on, run the test client script from the README. A session appears in the panel, its state changes, and clicking a choice for its question makes the script print the answer. Clicks next to the panel still pass through.

## 2. Bridge core (Bun)

- [x] 2.1 Scaffold `bridge/` (`package.json`, `tsconfig.json`, `bun.lock`, scripts `test`, `build` and `build:plugin`), add `@modelcontextprotocol/sdk`, and implement `protocol.ts` and `app_client.ts` (read `bridge.json`, 200 ms connect time-out, `hello`, stale-file detection). Verify: `bun test` covers reading a valid, missing and stale `bridge.json`, a successful handshake against a fake server, and a quick failure when nothing listens.
- [x] 2.2 Implement the `claude-buddy-bridge` command line (`hook <agent>`, `mcp [--agent]`, `print-config <target>`, `--version`) and `bun run build` (compiled binary in `bridge/dist/`, copied to `bridge/plugin/bin/` by `build:plugin`). Verify: `bridge/dist/claude-buddy-bridge --version` runs, and `hook claude-code` with the app closed exits 0 without output in under 100 ms.
- [x] 2.3 Document the bridge build and the test client in `README.md`. Verify: the documented commands run as written from a fresh clone (`bun install`, `bun test`, `bun run build`).
- [x] 2.4 Manual check: with the app running, `echo '{"session_id":"test","cwd":"/tmp/demo","hook_event_name":"UserPromptSubmit"}' | bridge/dist/claude-buddy-bridge hook claude-code` makes a "demo" session appear in the debug panel in state `thinking`.

## 3. Claude Code hooks and plugin (spikes S1, S2)

- [x] 3.1 Implement the Claude Code adapter (`adapters/claude_code.ts`): map `SessionStart`, `UserPromptSubmit`, `PreToolUse`, `PostToolUse`, `PostToolUseFailure`, `Notification`, `Stop`, `StopFailure` and `SessionEnd` to protocol events with `session_id`, `cwd`, `ppid` and a sequence number; and `PermissionRequest` to a `permission` request that waits `PERMISSION_WAIT_S` and prints the decision JSON on allow or deny. Verify: `bun test` feeds recorded stdin samples for every event and checks the sent messages, the decision output for allow and deny, and no output on time-out or with no app.
- [x] 3.2 Create the plugin (`bridge/plugin/.claude-plugin/plugin.json`, `hooks/hooks.json` with async status hooks and a sync `PermissionRequest`, `.mcp.json`) and the local marketplace (`.claude-plugin/marketplace.json`). Document install, uninstall and `--plugin-dir` use in `README.md`. Verify: `claude plugin validate` (or the documented validate step) passes, and `claude --plugin-dir bridge/plugin` lists the hooks in `/hooks` and the `buddy` server in `/mcp`.
- [x] 3.3 Spike S2 result: measure the hook overhead (100 runs of `hook claude-code` against the running app, average and p95) and record it in `design.md` under D5. If it is over 50 ms, apply the fallback.
- [x] 3.4 Spike S1 result: in a real session, trigger a permission prompt. Note whether Claude Code waits for the hook before showing its own prompt, how long the wait feels, and what Allow, Deny and a time-out do. Record the result and the chosen `PERMISSION_WAIT_S` in `design.md` under D5, and discuss with the user if the fallback is needed.
- [x] 3.5 Manual check: install the plugin, start a Claude Code session in another project, and give it a small task. The debug panel shows the session with its project name, and the debug monster goes through thinking, working and happy. A permission prompt can be allowed and denied from the panel. Quitting the app mid-session causes no errors in Claude Code.

## 4. MCP server and session identity (spikes S3, S4)

- [x] 4.1 Implement the MCP server (`mcp_server.ts`): `say` and `ask_user` with the schemas and descriptions from D7, progress notifications every 20 s while waiting, the time-out with `cancel`, and the "buddy not available" results. Send `hello` with `ppid`, `project_dir` and the MCP client name. Verify: `bun test` drives the server through the SDK's in-memory transport against a fake app, and covers say, answered and dismissed questions, a time-out and no app.
- [x] 4.2 Spike S3 result: in a real Claude Code session with the plugin, check that the hook `ppid` and the MCP `ppid` match, also after `/clear`, and that `say` lands on the hooked session. Record the result in `design.md` under D6, and switch to the `project_dir` fallback if they do not match.
- [x] 4.3 Spike S4 result: let an `ask_user` wait 3 minutes in Claude Code and in Claude Desktop before answering. Record how each client behaves (background task, time-outs) in `design.md` under D7, and adjust the default time-out if needed.
- [x] 4.4 Manual check: ask Claude in a Claude Code session to "use the buddy to ask me whether to continue, with choices yes and no". The question appears in the debug panel on the right session; picking an answer reaches Claude, and Claude continues accordingly.

## 5. Claude Desktop

- [x] 5.1 Implement `print-config claude-desktop` (prints the `mcpServers` entry with the absolute binary path and `mcp --agent claude-desktop`) and document the setup in `README.md`, including the "one session for all chats" limitation. Verify: the printed JSON is valid and the path exists.
- [x] 5.2 Manual check: add the entry to Claude Desktop's configuration and restart Claude Desktop. In a chat, ask Claude to say hello through the buddy and to ask a yes/no question. A "Claude Desktop" session appears in the panel with the message, and the answer reaches the chat.

## 6. Integration check

- [x] 6.1 Walk through every scenario in `specs/agent-bridge/spec.md` and `specs/session-tracking/spec.md` by test or by hand, and tick them off in a short checklist in the PR description. Any deviation found by a spike is either fixed or explicitly accepted by the user.
  - Result (2026-11-23): every scenario checked by test or by hand except "Installation — Uninstall", which was not run by hand. The checklist is in the PR description. Deviations and their fixes or acceptances: the Code-tab Desktop server is linked by name, with the known limitation for two active sessions in the same project.

## Workflow follow-up

- After review and merge: archive with `openspec archive claude-bridge`, so the specs move to `openspec/specs/`.
- Next change: `session-avatars` (one monster per session, walking, moods from session state).
