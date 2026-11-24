# Proposal

## Why

Clicking a buddy only takes you to its session while that session waits for you. In practice a buddy is the quickest way to find a session: you want to look at a session that is working, finished or idle too, and a click that does nothing feels broken.

## What Changes

- A left click on a buddy goes to its session whatever the session's state: thinking, working, waiting, done, error, idle or asleep. As now, the app that runs the agent comes to the front, and the session's focus link opens when it has one.
- A buddy that is walking off because its session ended does nothing on a click.
- When neither app nor link can be found, the click still does nothing visible and logs why (unchanged).
- The README's "Looking and clicking" text is updated.

Out of scope:
- Waking a sleeping buddy or changing its animation on a click.
- Any change to the right-click menu.
- Picking up and dropping a buddy (the separate `buddy-drag` change); that change keeps the click as press-and-release and is aligned with this one.

## Capabilities

### New Capabilities
<!-- none -->

### Modified Capabilities
- `session-avatars`: "Looking and click reaction" and "Go to the session" no longer depend on the session waiting for the user.

## Impact

- `godot/scripts/core/click_action.gd`: drop the waiting check, keep the "no agent process" check, add an "ended" check.
- `godot/tests/test_click_action.gd`: updated cases.
- `godot/scripts/avatars/avatar_manager.gd`: comment of `go_to_session` only; the call stays the same.
- `README.md`.
- `openspec/changes/buddy-drag/specs/session-avatars/spec.md` modifies the same requirement; its text is aligned with this change.
