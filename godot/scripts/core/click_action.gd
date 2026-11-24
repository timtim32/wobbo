extends RefCounted
## What a left click on an avatar does (go-to-session D3, always-go-to-session). Pure.
##
## A click goes to the app that runs the session's agent, whatever the session
## is doing. Only a session that has ended (its buddy walks off) does nothing.

const Protocol := preload("res://scripts/bridge/protocol.gd")

## Returns {action: "go" | "none", reason: String}.
static func for_left_click(state: StringName, agent_pid: int) -> Dictionary:
	if state == Protocol.STATE_ENDED:
		return {"action": "none", "reason": "session ended"}
	if agent_pid <= 0:
		return {"action": "none", "reason": "no agent process known"}
	return {"action": "go", "reason": ""}
