# Tasks

## 1. Finding and activating the session's app (spike S1)

- [x] 1.1 Add `MacOverlay.activate_app_of(pid)` (design D1, D2): walk the parent processes to the first regular app, activate it, and fall back to LaunchServices. Rebuild the extension. Verify: `game_eval` with this Claude Code session's `ppid` brings the Claude app to the front and returns "Claude"; with pid 999999 it returns "".
- [x] 1.2 Spike S1 result: from a real overlay click, check that the Claude app (and a terminal or VS Code if available) comes to the front, whether the fallback was needed, and that no Dock or Cmd-Tab entry appears. Record it in `design.md` under D2, and apply the fallback if needed.

- [x] 1.3 Add the focus link (design D4): `focus_url` in `PROTOCOL.md` and `SessionRef`; the Claude Code adapter fills it from `CLAUDE_CODE_HOST_SESSION_ID`; the plugin goes to 0.1.4. Verify: bridge tests for an adapter event with and without the environment variable.
- [x] 1.4 Keep and check the link in the app (design D4): `Session.focus_url` from session refs, only allowed schemes (`FocusLink.allowed`), and opening it on a click after activating the app. Verify: Godot tests (a `claude:` link kept; `file:` and `https:` ignored; a later link replaces the earlier one); `game_eval` sending a left click to this session's waiting avatar opens this session in the Claude app.

## 2. Clicks on avatars

- [x] 2.1 Add the pure click decision (design D1, D3): `go` while `waiting` with a known `ppid`; `none` otherwise, with a reason. Verify: headless tests for waiting with a ppid, waiting without one, and working, idle and asleep.
- [x] 2.2 Wire left clicks in the avatar manager to the decision and `activate_app_of`, and remove the happy click reaction from `SessionAvatar` and `AvatarMood` (design D3). Verify: the existing tests are updated and green; `game_eval` sending a left click to a waiting avatar's region activates its app and logs it; a left click on a working avatar logs nothing and changes nothing.
- [x] 2.3 Manual check: while Claude waits for an answer in this session (a question), the user switches to another app or session and clicks the jumping buddy, and the Claude app comes to the front on this session. A click on a non-jumping buddy does nothing. The right-click menu still works.

## 3. Documentation and integration

- [x] 3.1 Update `README.md` ("The buddies"): a click on a jumping buddy takes you to its app, other left clicks do nothing, and the right-click menu stays. Mention that only the app comes to the front, not the exact tab. Verify: the README describes this.
- [x] 3.2 Walk through every scenario in this change's spec by test or by hand, and tick them off in a short checklist in the PR description. Any deviation found by the spike is either fixed or explicitly accepted by the user.

## Workflow follow-up

- After review and merge: archive with `openspec archive go-to-session`.
- Later: precise tab focus per host (Terminal, iTerm, editors), and dragging buddies.
