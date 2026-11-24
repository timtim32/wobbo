# Proposal

## Why

When Claude starts a script or command in the background (Bash with `run_in_background`) and waits for its result, its turn ends and the Wobbo shows "done" and walks around idle, while the session is in fact still busy: Claude is woken up again as soon as the command ends. The user cannot tell from the Wobbo that the session is still at work.

## What Changes

- At the end of a turn, the bridge checks whether the session still has background commands running, and reports their number with the end of the turn.
- A session whose turn ends while background commands still run stays `working` (instead of `done`), with the work animation.
- No "Done" notice while background commands still run; it comes when Claude finishes the turn in which nothing runs in the background any more (after it was woken up by the command's end).
- Older bridges and apps keep working: the count is an optional field of the existing end-of-turn event.

### Out of scope

- Background subagents (the Agent tool in the background), the Monitor tool and other kinds of background tasks: only Bash commands with `run_in_background`.
- Showing which command runs, or its output or progress.
- Detecting the moment a background command ends while Claude is not woken up (for example when Claude Code is closed): the state then changes on the session's next event, or the session disappears after the existing 30 minutes of silence.
- Agents other than Claude Code.

## Capabilities

### New Capabilities
<!-- none -->

### Modified Capabilities
- `agent-bridge`: "Session status from Claude Code" also reports, at the end of a turn, how many background commands still run.
- `session-tracking`: "Session list and state": a turn that ends with background commands running leaves the session `working`, not `done`.
- `buddy-messages`: "Turn finished notice": no "Done" while background commands still run.

## Impact

- `bridge/src/adapters/claude_code.ts`: on `Stop`, read the session's transcript (`transcript_path`) and count background commands still running; `turn_end` gets `data.background`.
- `bridge/PROTOCOL.md`: document the optional `background` field of `turn_end`.
- `godot/scripts/core/session_registry.gd`: `turn_end` with `background > 0` → `working`.
- `godot/scripts/avatars/messages.gd`: no "Done" notice for such a turn end.
- Tests: `bridge/test/claude_code.test.ts`, `godot/tests/test_session_registry.gd`, message policy test.
- Relies on the format of Claude Code's transcript, which is not a public API (see design).
