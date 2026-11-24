# Tasks

## 1. Speech spike

- [x] 1.1 Spike S1 (design D7): enable `audio/general/text_to_speech` in `project.godot`. From `game_eval`, list `DisplayServer.tts_get_voices()` and speak a test sentence with the voice for the system language, from the editor run of the accessory app. Verify: the sentence is heard and the voice list is logged. If it stays silent, try `/usr/bin/say` through `OS.create_process`, write down which way works in `design.md` (D7), and use that way in group 6.
- [ ] 1.2 Manual check: the user hears the test sentence on their Mac while the buddies run without a Dock icon.

## 2. Registry and bridge

- [x] 2.1 Keep `timeout_s` and `added_msec` on each request in `SessionRegistry.add_request()`, and copy `timeout_s` from the frame in `BridgeServer` (design D4). Verify: `test_session_registry.gd` covers a request with and without `timeout_s`; `test_bridge_server.gd` checks the value arrives from a `request` frame.
- [x] 2.2 Add `Session.turn_started_msec`, set on `prompt` (design D4). Verify: a registry test that `prompt` then `turn_end` leaves the start time readable, and that a later prompt resets it.
- [x] 2.3 Add the signal `session_event(session_id, kind, data)`, emitted from `_apply_event()` when an event was applied, also while a request keeps the session `waiting` (design D4). Verify: a bridge-server test receives `turn_end` and `turn_error` with their data, including while a question is pending, and no signal for an out-of-order event.
- [ ] 2.4 Manual check: with the app running, `bun bridge/scripts/fake_sessions.ts ask website` still shows the question in the debug panel, and answering it there still reaches the script.

## 3. Settings and the "Messages" menu

- [x] 3.1 Add `messages`, `notify_done` and `notify_errors` to `SettingsStore.DEFAULTS` and as typed `Settings` properties (design D8). Verify: `test_settings_store.gd` checks the defaults, an old file without the keys, and an unknown `messages` value reading as `balloons`.
- [x] 3.2 Add `MessagePolicy.menu_items(mode, speech_available)` (design D8). Verify: headless tests for exactly one checked item per mode, and both speech items disabled without a voice.
- [x] 3.3 Add the "Messages" submenu after "Size" in `menu_bar.gd`: the four radio items, a separator, then "Turn finished" and "Errors" (design D8). Verify: `game_eval` reads the submenu items and checks; choosing items updates the settings and the check marks.
- [ ] 3.4 Manual check: the user opens "Messages" in the real menu bar, chooses "Off", unchecks "Errors", restarts the app, and finds both choices kept.

## 4. Pure message logic

- [x] 4.1 Add `MessagePolicy` (`scripts/core/message_policy.gd`, design D2): `output_flags`, `accepts_requests`, `for_message`, `for_turn_end`, `for_turn_error`, `for_request` and `reading_time_s`. Verify: `test_message_policy.gd` covers every output mode, the 20-second rule at 19.9 s and 20 s, both notice toggles, a multi-line error cut to its first line and 120 characters, requests shown with output `speech`, the spoken texts, and reading times clamped to 4 and 12 s.
- [x] 4.2 Add `BalloonQueue` (`scripts/core/balloon_queue.gd`, design D3): requests oldest first with index and count, one message that a newer one replaces, expiry, hold and release while hovered, and `close_message`. Verify: `test_balloon_queue.gd` covers each, including a message arriving while a request shows, and a request removed from the middle.
- [x] 4.3 Add `BalloonLayout` (`scripts/core/balloon_layout.gd`, design D6): the balloon's x clamped to the display segment with 8 pt margins, the tail x clamped inside the corners, and the height limit from the head top. Verify: `test_balloon_layout.gd` covers a buddy in the middle, at both segment edges, on a second display, and the room at Small and Extra large.
- [ ] 4.4 Manual check: the user runs the headless test suite (`Godot --headless --path godot --script res://tests/run_tests.gd`) and sees all tests pass, including the new files.

## 5. Message balloons

- [x] 5.1 Add the `Balloon` control (`scripts/avatars/balloon.gd`, design D6): white rounded panel with tail and shadow, a header with the session name in the buddy's colour and a close button, wrapped body text cut with "…" to the height limit. Verify: a scene test builds a balloon with a long text and a small height limit and checks it stays within the limit with the last line cut.
- [x] 5.2 Let `SessionAvatar` own its balloon (design D5): create it lazily in the strip under its centre, move it when the buddy changes display, place it every frame, register `balloon:<id>` while shown, hide the name label while it is open, and hide the balloon while carried. Verify: `game_eval` with a fake session shows the balloon above the head, the region in `Overlay` matches its rect, and the label is hidden; picking the buddy up hides both, and after landing the balloon is back.
- [x] 5.3 Add the `Messages` node under `Main`, outside `Content` (design D1). It listens to `message_received`, `session_event`, `request_added`/`request_removed` and `Settings.changed`, keeps a `BalloonQueue` per session, and gives each avatar on screen its current content. Messages for sessions without a buddy on screen are skipped. Hovering a message balloon holds it and clicking it closes it. Verify: `game_eval` with `fake_sessions.ts say website "Tests are green"` shows the balloon, it closes after about 4 s, stays open while hovered, and a second `say` replaces the text.
- [ ] 5.4 Manual check: the user plays the demo and sends `say` messages to a few fake sessions. Balloons appear above the right buddies, stay on screen at the left and right edges, clicking beside a balloon reaches the window below, and clicking a balloon closes it without taking focus from the terminal.

## 6. Answering at the buddy

- [x] 6.1 Show questions in the balloon (design D6): one button per choice in a wrapping row, sending the choice through `Bridge.answer_request()`, and "1 of 2" in the header with more pending requests. Verify: `game_eval` with two questions for one fake session shows "1 of 2", clicking a choice answers the first and then shows the second.
- [x] 6.2 Add the free-text field: clicking it calls `Overlay.request_keyboard_focus()`, Enter sends the text, Escape releases focus without answering, and focus is released when the balloon closes for any reason. Verify: `game_eval` for Enter and Escape, checking the answer sent and that no focus request is left open.
- [x] 6.3 Show permission prompts with "Allow", "Deny" and a time-left bar from `timeout_s` and `added_msec`. The close button dismisses a question and hands a permission back. Verify: `game_eval` with a local permission request whose time-out is 5 s shows the bar shrinking and the balloon closing once the request is withdrawn; the close button calls `dismiss_request`.
- [x] 6.4 Hand requests back when they are not accepted (design D9): on a new request, on switching to Off, and when the buddies are hidden. Clear messages and close balloons at the same time. Verify: `game_eval` sets `Settings.messages = "off"` with a pending question and sees it dismissed; with the buddies hidden a new request is dismissed at once.
- [ ] 6.5 Manual check: in a real Claude Code session with the plugin, the user lets Claude ask a question through `ask_user` and answers it with a button, then with typed text. They allow and deny a permission prompt from the balloon, and with "Off" chosen they see Claude Code's own permission prompt appear without the 20-second wait.

## 7. Speech and notices

- [x] 7.1 Add the `Speech` node and `SpeechVoice` (design D7) in the way chosen in 1.1: voice choice from the system language, queued speaking, `stop()`, `available()`. Verify: `test_speech_voice.gd` covers a matching voice, a fallback to the first voice, and no voices; the menu's speech items are disabled when `available()` is false.
- [x] 7.2 Let `Messages` speak what `MessagePolicy` asks for, and stop speech when the output turns off or the buddies hide. Messages for sessions without a buddy on screen are still spoken. Verify: `game_eval` with output `speech` and a spy `Speech` checks the spoken texts for a message, a question and a permission, and that no balloon appears for the message.
- [x] 7.3 Show and speak the turn-finished and error notices from `session_event` (design D2): "Done" for turns of at least 20 s, and "Something went wrong: <first line>" for failed turns, each with its toggle. Verify: `game_eval` with fake events and timestamps shows "Done" for a 30 s turn, nothing for a 5 s turn or with "Turn finished" off, and the error notice for `turn_error` but not for `tool_error`.
- [ ] 7.4 Manual check: the user chooses "Balloons and Speech", lets a real Claude session work for a minute, and hears "<project> is done" while seeing "Done". They then choose "Speech" and hear a `say` message without a balloon.

## 8. Frame rate, debug panel and docs

- [x] 8.1 Keep the normal frame rate while a balloon is open (design D10): add `balloon_open` to `QuietMode.is_quiet()` and pass it from `QuietFps`. Verify: `test_quiet_mode.gd` covers the new argument; `game_eval` shows `QuietFps.quiet` false while a balloon is open over sleeping buddies.
- [x] 8.2 Update the debug panel's header comment (design D10), and the README: the balloon, answering at the buddy, speech, the "Messages" menu, and `fake_sessions.ts ask` now answered in the balloon. Verify: the README describes each, and the documented commands work as written.
- [x] 8.3 Walk through every scenario in this change's specs, by test or by hand, and tick them off in a short checklist in the PR description.
- [ ] 8.4 Manual check: the user leaves the app running for a while with sleeping buddies and no balloons, and sees in Activity Monitor that its CPU use is as low as before this change.

## 9. Questions asked in the agent's own window

- [x] 9.1 Fix the menu: give the "Screen", "Size" and "Messages" submenus their own ids, so `_sync` no longer renames "Messages" to "Play Demo". Verify: `game_eval` lists the menu texts "Hide Buddies, Screen, Size, Messages, Show Names, Play Demo, Debug regions, Quit Claude Buddy".
- [x] 9.2 Bridge (design D11): `toEvent` adds `question`, `choices` and `question_until` for `AskUserQuestion`, `ExitPlanMode` and `mcp__ccd_turn__wrap_up` with an `ask`; an unknown shape stays a plain event. Document the fields in `PROTOCOL.md`, rebuild the plugin binary and raise its version. Verify: `bun test` covers each tool, several questions ("+1 more"), and a wrap-up without `ask` or with odd fields.
- [x] 9.3 App (design D11): an "asked" slot in `BalloonQueue` between requests and messages, filled by `Messages` from `session_event` data and closed on `prompt`, `session_end`, or the tool's `tool_end`/`tool_error` (for `"answer"`). It is spoken like a request. Verify: `test_balloon_queue.gd` covers the priority and closing; `game_eval` with local events shows the balloon with "Answer in the session", keeps it when a "Done" notice arrives, and closes it on the next prompt.
- [x] 9.4 The balloon for an asked question shows the choices as a muted line and the hint, and a click on it goes to the session. Verify: `game_eval` checks the click calls `go_to_session` (spy on the avatar manager), and the × only closes it.
- [x] 9.5 Update the README. Verify: it describes these balloons and that they are answered in the session.
- [ ] 9.6 Manual check: after updating the plugin and restarting a Claude Code session in the Claude app, the user sees the next-step question of a turn in the buddy's balloon, clicks it to reach the session, and sees the balloon close after the next prompt.

## Workflow follow-up

- After review and merge: archive with `openspec archive balloons-and-speech`.
