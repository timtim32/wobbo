# Tasks

## 1. Bridge: count background commands at the end of a turn

- [x] 1.1 Add `runningBackgroundTasks(transcript)` to `bridge/src/adapters/claude_code.ts` (design D1): ids from `"backgroundTaskId":"<id>"` minus ids with a `<task-notification>` status other than `running`. Verify: unit tests in `bridge/test/claude_code.test.ts` for one running command, one finished, a finished one absorbed mid-turn, and notification text quoted inside another tool's output (escaped quotes) not counted as a start.
- [x] 1.2 Add `readTranscript` to `HookContext` (default: read the last 32 MB of `transcript_path`, null on any error; design D2) and, in `runHook`, add `data.background` to `turn_end` when the count is above 0. Verify: tests that `Stop` with a sample transcript sends `turn_end` with `background: 1`, without a transcript or with an unreadable path sends plain `turn_end`, and other hooks never read the transcript.
- [x] 1.3 Document the optional `background` field of `turn_end` in `bridge/PROTOCOL.md` (event table and the state table). Verify: the doc names the field and that an older app ignores it.
- [x] 1.4 Run `bun test` and `bun run typecheck` in `bridge/`. Verify: both pass.
- [x] 1.5 Manual check: rebuild the plugin bridge (`bun run build:plugin`), start a Claude Code session, ask Claude to run `sleep 60` in the background and wait for it; the hook delivers `turn_end` with `background: 1` (visible in the app's debug panel after group 2, or with `bridge/scripts/fake_sessions.ts`/a fake app).

## 2. App: stay at work while background commands run

- [x] 2.1 In `godot/scripts/core/session_registry.gd`, make `turn_end` with `background > 0` set `working` with an empty tool instead of `done` (design D3). Verify: tests in `godot/tests/test_session_registry.gd` for "turn ends with a background command running" → `working`, and the woken-up sequence `tool_start`, `tool_end`, `turn_end` without background → `done`; a pending request still keeps `waiting`.
- [x] 2.2 In `godot/scripts/avatars/messages.gd`, skip the turn-finished notice for a `turn_end` with `background > 0`, keeping `turn_started_msec` so the later "Done" counts from the prompt. Verify: a test (message policy or messages) that such a turn end gives no notice and the next plain `turn_end` after more than 20 s does.
- [x] 2.3 Run the Godot test suite headless (`godot --headless --path godot -s res://tests/run_tests.gd`). Verify: all tests pass.
- [ ] 2.4 Manual check: with the rebuilt plugin and the app running, ask Claude in a session to start a script of about a minute in the background and wait for its result. The Wobbo keeps its work animation after Claude's turn ends, shows no "Done" then, and shows "Done" (happy jump) once Claude has handled the result.
