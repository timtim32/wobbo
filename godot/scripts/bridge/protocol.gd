extends RefCounted
## Constants of the bridge protocol, version 1 (see bridge/PROTOCOL.md).

const VERSION := 1
const DEFAULT_PORT := 47321
const PORT_TRIES := 10
const HELLO_TIMEOUT_MS := 2000

const ROLE_HOOK := "hook"
const ROLE_MCP := "mcp"

const EVENT_KINDS: Array[String] = ["session_start", "prompt", "tool_start", "tool_end",
	"tool_error", "notification", "input_wait", "turn_end", "turn_error", "session_end"]

const STATE_IDLE := &"idle"
const STATE_THINKING := &"thinking"
const STATE_WORKING := &"working"
const STATE_WAITING := &"waiting"
const STATE_DONE := &"done"
const STATE_ERROR := &"error"
const STATE_ENDED := &"ended"

const REQUEST_QUESTION := "question"
const REQUEST_PERMISSION := "permission"
