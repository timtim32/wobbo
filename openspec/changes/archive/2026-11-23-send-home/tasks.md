# Tasks

## 1. Going away and coming back (pure rules)

- [x] 1.1 Extend `AvatarCast` (design D1, D2): sessions carry an `away` flag, so away sessions are no candidates and their avatar leaves without waving. Add `comes_back(mark, session)` for a new state event into thinking, working or waiting, or a new request. Verify: headless tests cover:
  - an away session freeing its place for a sixth session;
  - an away session's avatar leaving;
  - coming back on a prompt, on a tool start and on a new request;
  - staying away on a notification-only update, on `done`, and while the state is unchanged.
- [x] 1.2 Add `asleep_since_msec` and `wants_home(now)` to `AvatarMood` (design D3). Verify: headless tests cover:
  - not yet after 14 minutes asleep, but yes after 15;
  - a click restarting the timer;
  - never while thinking, working or waiting.
- [x] 1.3 Manual check: the user confirms the rules: gone 17 minutes after the last activity (2 asleep + 15), and back on a prompt, a tool use or a question, but not on Claude's background notifications.

## 2. Send home in the app (spike S1)

- [x] 2.1 Wire the away state into the `Avatars` manager (design D1–D3): a `_away` map with `AwayMark`s, `send_home(session_id)`, auto-home on `wants_home`, and the return check on `session_changed` and every re-plan. Verify:
  - `game_eval`: `send_home` on a fake session's avatar makes it walk off, and its session stays in the registry;
  - `fake_sessions state <name> thinking` brings it back within 2 seconds;
  - a notification-only event does not bring it back.
- [x] 2.2 Add the right-click context menu with `NativeMenu` (design D4): "Send home", plus "Type here (debug)" in debug mode, which replaces the direct right click to the debug text field. Verify: in the app, a right click on an avatar shows the menu; "Send home" sends that avatar home; in debug mode "Type here (debug)" opens the text field at the avatar.
- [x] 2.3 Spike S1 result: on both displays, check the native menu at the pointer, the callbacks, closing on Escape and on a click elsewhere, keyboard focus staying in the terminal, and no Dock or Cmd-Tab entry. Record it in `design.md` under D4, and apply the fallback if needed.
- [x] 2.4 Manual check: the user sends a buddy home from its menu, then uses that session again and sees the buddy walk back in. With six sessions, sending one home lets the sixth buddy walk in.

## 3. Documentation and integration

- [x] 3.1 Update `README.md` ("The buddies"): going home after a while asleep, "Send home" in the right-click menu, and coming back on use. Verify: the README describes them.
- [x] 3.2 Walk through every scenario in `specs/session-avatars/spec.md` of this change by test or by hand, and tick them off in a short checklist in the PR description. Any deviation found by the spike is either fixed or explicitly accepted by the user.

## Workflow follow-up

- After review and merge: archive with `openspec archive send-home`.
- Next change: `avatar-interactions` (click to focus the session's window, drag and drop, more context-menu items) or `balloons-and-speech`.
