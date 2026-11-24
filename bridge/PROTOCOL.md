# Wobbo bridge protocol, version 1

Coding agents (through the `wobbo-bridge` program) talk to the
Wobbo app over a WebSocket on the loopback interface. Every frame is a UTF-8
JSON text frame with the envelope `{"v": 1, "type": "<type>", ...}`.

## Discovery

The app writes `~/Library/Application Support/Wobbo/bridge.json`, which only the
user can read. Clients also try `~/Library/Application Support/ClaudeBuddy/bridge.json`,
where the app wrote it before it was renamed, and use the first file whose app runs:

```json
{"port": 47321, "token": "9f2c…", "pid": 12345, "protocol": 1}
```

A client connects to `ws://127.0.0.1:<port>/`. If the file is missing, the
connection is refused, or `pid` is not running, the app is "not available".
Clients then give up silently.

## Handshake

The first frame from a client must be `hello`, within 2 seconds:

```json
{"v": 1, "type": "hello", "token": "9f2c…",
 "client": {"role": "hook", "agent": "claude-code", "pid": 4242, "ppid": 4100,
            "project_dir": "/Users/me/Projects/api", "client_name": "",
            "bridge_version": "0.1.0"}}
```

`role` is `"hook"` for a short-lived hook process and `"mcp"` for a long-lived
MCP server process. `client_name` is the MCP client's name from the MCP
`initialize` handshake, for example `"claude-ai"` (Claude Desktop) or
`"claude-code"`.

The app answers with one of these:

```json
{"v": 1, "type": "welcome", "app_version": "0.1.0"}
{"v": 1, "type": "error", "reason": "bad_token"}
```

After an `error`, the app closes the connection.

## Hook connections

A hook connection carries exactly one `event`, `say` or `request`. A hook
may send its `event` right after `hello`, without waiting for `welcome`; the
app handles both in order. After an
`event` or `say` the app closes the connection itself; the client waits for
that close (at most 300 ms) instead of closing first. Godot's WebSocket drops a
frame that arrives together with the peer's close frame, so a client that sends
and closes at once can lose its message. For a `request`, the client closes
after it received the `answer` (or gives up with `cancel`).

## Session object

```json
{"id": "5c1e…", "agent": "claude-code", "project_dir": "/Users/me/Projects/api"}
```

`focus_url` is optional: a URL that opens this session in the app that hosts
the agent, for example `claude://code/continue?session=local_…` for a Claude
Code session in the Claude app. The app only opens it when it knows the URL's
scheme (currently `claude`), when the user clicks the buddy of a waiting
session.

Hook clients always send `session`. MCP clients may omit it; the app then
attributes their messages through the connection's `hello`, linking by `ppid`
or `project_dir` (design D6).

Every client-to-app frame carries `ts`, the client's time in milliseconds since
the epoch. The app ignores a state change that is older than the last one it
applied for that session, because hooks run as separate processes and their
frames can arrive out of order.

## Client → app

### `event`

```json
{"v": 1, "type": "event", "ts": 1795440000123,
 "session": {"id": "5c1e…", "agent": "claude-code", "project_dir": "/Users/me/Projects/api"},
 "kind": "tool_start", "data": {"tool": "Bash"}}
```

| `kind` | When | `data` |
|---|---|---|
| `session_start` | session started or resumed | `source` |
| `prompt` | the user submitted a prompt | – |
| `tool_start` | a tool starts | `tool` |
| `tool_end` | a tool finished | `tool` |
| `tool_error` | a tool failed | `tool`, `error` |
| `notification` | the agent shows a notification | `message`, `notification_type` |
| `input_wait` | the agent waits for the user in its own UI (a question, plan approval, a permission prompt) | `reason`, `tool` (optional), and the question fields below (optional) |
| `turn_end` | the agent finished its turn | – |
| `turn_error` | the turn failed (API error) | `error` |
| `session_end` | the session ended | `reason` |

When the agent asks the user in its own UI, the event of that tool also carries
the question, so the app can show it (read only: the answer is given in the
agent's own window):

| Field | Meaning |
|---|---|
| `question` | the question's text (at most 500 characters) |
| `choices` | the answer options as labels (at most 6, each at most 40 characters) |
| `question_until` | `"answer"`: the question is open until the tool ends (`tool_end` or `tool_error` of the same tool); `"prompt"`: until the next `prompt` |

Claude Code's question tool and plan approval send them with `input_wait`. The
Claude app's next-step box (the tool `mcp__ccd_turn__wrap_up` with an `ask`) is
a `tool_start` with these fields and `question_until: "prompt"`: the turn ends
right after it, so the session is not waiting.

### `say`

```json
{"v": 1, "type": "say", "ts": 1795440000200, "session": null, "text": "Tests are green"}
```

### `request`

```json
{"v": 1, "type": "request", "ts": 1795440000300, "id": "r-81f0…", "session": null,
 "kind": "question", "text": "Deploy to staging now?",
 "choices": ["yes", "no"], "allow_text": false, "timeout_s": 600}
```

For `kind: "permission"`, `text` describes the action, for example
`Bash: rm -rf build`, and `choices` is `["allow", "deny"]`.

### `cancel`

```json
{"v": 1, "type": "cancel", "ts": 1795440001000, "id": "r-81f0…"}
```

The asker gave up (time-out). Closing the connection cancels all of its
requests as well.

## App → client

### `answer`

```json
{"v": 1, "type": "answer", "id": "r-81f0…", "status": "answered", "choice": "no", "text": ""}
{"v": 1, "type": "answer", "id": "r-81f0…", "status": "dismissed"}
```

## Session states in the app

| Event | State |
|---|---|
| `session_start` | `idle` |
| `prompt`, `tool_end`, `tool_error` | `thinking` |
| `tool_start` | `working` |
| `turn_end` | `done` |
| `turn_error` | `error` |
| a pending request | `waiting` (the previous state returns afterwards) |
| `session_end` | `ended` (removed after 5 s) |

## Versioning

Additive changes (new optional fields, new `kind`s) keep `v: 1`; the app
ignores what it does not know. Breaking changes bump `v`. The app answers an
unknown `v` with `error` `"unsupported_version"`.
