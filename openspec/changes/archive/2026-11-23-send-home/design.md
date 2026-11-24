# Design: send-home

## Context

What `session-avatars` built (Godot 4.7.2, macOS):

- **`Avatars` manager:** re-plans every 0.5 s and on `Bridge` signals. It feeds the pure `AvatarCast.plan(sessions, avatars, slots)`, which returns `enter` / `leave` actions.
- **`SessionAvatar`:** a `WalkwayBody` driven by the pure `AvatarMood`. `AvatarMood.asleep` is true after 120 s without activity in `idle`, `done` or `error`. `leave(wave)` makes it walk off beyond the nearest end of the walkway.
- **Session data:** the registry `Session` has:
  - `state`;
  - `updated_msec`, set by every event, notifications included;
  - `last_ts`, set by every state event, but not by notifications, which return early;
  - `pending`, the request ids.

  Requests (`add_request`) set the state to `waiting` without touching `last_ts`.
- **Why buddies stay:** a session that is left open never sends `session_end`. Its plugin MCP connection stays open, so `SessionRegistry.tick` never removes it. Its buddy sleeps on screen indefinitely.
- **Right click today:** in debug mode it opens the debug text field directly (`avatar_right_clicked`). In normal mode it does nothing.

## Goals / Non-Goals

**Goals:**
- An "away" state for sessions that lives only in the app: no protocol change and no effect on the agent.
- Pure, tested rules for going away (15 minutes asleep) and coming back (real use, not notifications).
- A real macOS context menu on a buddy that does not steal focus.

**Non-Goals:**
- Persisting the away state across restarts.
- More context-menu items (`avatar-interactions`).

## Decisions

### D1. Away sessions in the manager, filtered in the cast
The manager keeps `_away := {session_id: AwayMark}`, where an `AwayMark` is `{last_ts, pending: Array}` captured when the buddy is sent home.
- **In the cast:** `AvatarCast.plan` gets an `away: bool` per session. Away sessions are not candidates, so they free their place. An avatar whose session turns away gets `leave(wave=false)`. A manual "Send home" calls `avatar.leave(false)` at once, so the buddy starts walking without waiting for the next re-plan.
- **Ending:** an away session that ends or is removed is dropped from `_away`. It has no avatar, so nothing walks.

*Alternative:* mark away in the registry (`Session.away`). Rejected: it is a view concern of the avatars, and the registry stays agent-facing.

### D2. Coming back: real use only
Pure `AvatarCast.comes_back(mark, session) -> bool` is true when either of these holds:
- `session.last_ts > mark.last_ts` and `session.state` is `thinking`, `working` or `waiting`. This means a new state event (prompt, tool start or tool end) arrived after the buddy was sent home. Notifications never change `last_ts`, so they never bring it back.
- `session.pending` contains a request id that was not in `mark.pending`. This covers a new question or permission request, which does not change `last_ts`.

The manager checks this on `session_changed` and on every re-plan, then removes the mark. The next plan lets the buddy walk in as usual. Its hue may differ if its old hue is now taken.

### D3. Going home by itself after 15 minutes asleep
`AvatarMood` records `asleep_since_msec`: the time `asleep` became true, or -1 while awake. A new `wants_home(now_msec)` is true when it has been asleep for `HOME_AFTER_ASLEEP_MS = 15 × 60 × 1000`.
- **Leaving:** each re-plan, the manager sends home every avatar that wants to go: it marks the session away and calls `leave(false)`. The buddy then wakes up (the mood's leaving phase plays `walk`) and walks off.
- **Total time:** a session left idle is asleep after 2 minutes and gone after 17. A click wakes the buddy and restarts both timers.

### D4. Context menu with Godot's `NativeMenu`
On a right click, the manager builds a `NativeMenu` menu and shows it with `NativeMenu.popup(rid, DisplayServer.mouse_get_position())`, which shows a real macOS `NSMenu` at the pointer.
- **Items:**
  - "Send home";
  - in debug mode also "Type here (debug)".
- **Choosing an item:** each item has a callback (`set_item_callback`). "Send home" calls the manager's `send_home(session_id)`. "Type here (debug)" emits `avatar_text_requested(avatar)`, which `main.gd` connects to `_text_field.open_at`. That replaces `avatar_right_clicked`.
- **Freeing:** the menu is freed when it closes (`set_popup_close_callback`).

**Spike S1:** check that the native context menu:
- opens from the unfocusable overlay windows on both displays at the pointer;
- runs its callbacks;
- closes on Escape or a click elsewhere;
- leaves the previously frontmost app with keyboard focus (typing in a terminal goes on in the terminal);
- does not show the app in the Dock or Cmd-Tab.

**Fallback:**
- If the menu does not open from an unfocusable window, request focus for the duration of the menu (`Overlay.request_focus`), then release it so focus is handed back.
- If that is not reliable, draw a small menu inside the strip instead: a dark pill with buttons next to the buddy, registered as a region, which closes after 5 s or after a click on an item.
- **Result S1 (task 2.3, 2026-11-23, by hand):** passed without the fallback.
  - The native menu opens at the pointer from the unfocusable overlay window.
  - "Send home" runs its callback.
  - Escape closes the menu without a change, and typing goes on in the terminal.
  - No Dock or Cmd-Tab entry appears.
  - Checked on the built-in display only, because the LG was disconnected. The external strip windows use the same window flags and the same code path.

### D5. Tests
- **Pure tests:**
  - `AvatarCast.plan` with away sessions (they free a place, and an away session's avatar leaves);
  - `AvatarCast.comes_back` (prompt, tool start, request, and notification-only);
  - `AvatarMood.wants_home`, including a click restarting the timer.
- **In the app:**
  - `game_eval` for the manager's `send_home` and the return on a fake prompt;
  - `fake_sessions` for the full flow.
- **By hand:** the native menu (spike S1).

### Godot and macOS assumptions
- Godot 4.7: the `NativeMenu` singleton supports `create_menu`, `add_item`, `set_item_callback`, `popup(rid, position)` and `set_popup_close_callback` on macOS (`NativeMenu.has_feature(FEATURE_POPUP_MENU)`). The position is in screen pixels, the same space as `DisplayServer.mouse_get_position()`.
- macOS: `NSMenu popUpMenuPositioningItem` tracks the menu modally without making the app's windows key, so the frontmost app keeps keyboard focus (spike S1).

## Risks / Trade-offs

- [After an app restart, away sessions are no longer marked, so an open session that sends an event gets a buddy again] → Accepted: it falls asleep and goes home by itself after 17 minutes. Persisting away state would need stable session ids across restarts, and is not worth it for now.
- [A session that was sent home while `working` (a long task) only comes back on its next state event] → That is intended: the user chose to send it away. A finished turn (`done`) does not bring it back either. Only real use does.
- [`NativeMenu` callbacks run while the menu is tracked modally, so the app's frame loop may pause during the menu] → Harmless: the overlay is static for that moment, and the spike checks it.
- [The hue can change when a buddy comes back] → The hue is still picked from the name hash first, so it usually returns in the same colour.
