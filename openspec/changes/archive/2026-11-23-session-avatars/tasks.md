# Tasks

## 1. Pure decisions: cast, slots, colours and mood

- [x] 1.1 Implement `AvatarCast` (`scripts/core/avatar_cast.gd`, design D1, D2, D6). It covers:
  - ranking (waiting first, then `updated_msec`, with 2 s hysteresis);
  - at most 5, or fewer slots on narrow displays;
  - slots filled from the centre, and stable slots;
  - `enter` / `leave(wave)` actions, with the slot freed only after an avatar has walked off;
  - hue assignment by name hash with collision avoidance.

  Verify: headless tests cover:
  - one session;
  - three sessions in slots 2, 1, 3;
  - a sixth active session evicting the quietest;
  - a waiting session never evicted;
  - hysteresis;
  - an ended session (wave) and a removed one (no wave);
  - a session without an avatar ending;
  - a narrow display;
  - unique and stable hues.
- [x] 1.2 Implement `AvatarMood` (`scripts/core/avatar_mood.gd`, design D3) with explicit times. Verify: headless tests cover:
  - each state's clip and motion;
  - `done` and `error` reactions followed by strolling;
  - sleep after 120 s in `idle`, `done` and `error`, and never in `thinking`, `working` or `waiting`;
  - waking on activity;
  - state changes while entering or travelling applied on arrival;
  - a click reaction, including waking from sleep;
  - `ended` leading to a wave and then walking off.
- [x] 1.3 Manual check: the user reads the table in design D3 against the test names and confirms the behaviour per state (thinking, working, waiting, done, error, idle, asleep, ended) is what they want.

## 2. Fake sessions and the avatar manager

- [x] 2.1 Write `bridge/scripts/fake_sessions.ts` (design D10): several fake sessions with commands `add`, `state`, `ask`, `end` and `add-many`. Verify: with the app running, `add website` shows a "website" session in the debug panel, and `end website` removes it after a few seconds.
- [x] 2.2 Implement `SessionAvatar` (`scripts/avatars/session_avatar.gd`, design D4) on top of `WalkwayBody`: mood-driven clip and motion, slot strolling, entering and leaving, travel to the home display, look at the pointer, and a region per avatar. Verify: in the running app, `game_eval` adding one avatar for a fake session shows it walking in and stopping at the centre slot.
- [x] 2.3 Implement the `Avatars` manager (`scripts/avatars/avatar_manager.gd`, design D1, D7). It connects the `Bridge` signals, a 0.5 s re-evaluation, `AvatarCast` actions and click routing. Replace `DebugBlob` in `main.tscn` / `main.gd` and delete `debug_blob.gd` (design D9). Verify:
  - existing tests stay green;
  - with no sessions the strip is empty and fully click-through (debug outlines show no regions);
  - `fake_sessions add-many 3` gives three avatars in separate slots.
- [x] 2.4 Manual check, with `fake_sessions`, the user watches:
  - avatars walking in for new sessions;
  - each state's behaviour (`state <name> thinking|working|done|error`, `ask`);
  - waving and walking off on `end`;
  - three avatars not overlapping;
  - a sixth session swapping out the quietest avatar.

- [x] 2.5 Add the "Play Demo" / "Stop Demo" menu item and the `DemoPlayer` (design D11), with `BridgeServer.local_event` and `local_request`. Verify:
  - headless tests: local events emit the same signals as received ones, a local request's answer is dropped safely, and the timeline is ordered and ends every pretend session;
  - in the app, choosing the item through `game_eval` brings in the pretend avatars, and "Stop Demo" sends them off.
- [x] 2.6 Manual check: the user plays the demo from the menu bar, watches it through, and stops a second run halfway. A real session's avatar is not affected.

## 3. Name labels and colours (spike S2)

- [x] 3.1 Add the view hooks to `WalkwayBody` and a name label per strip view to `SessionAvatar` (design D5): a pill style, 140 pt maximum with an ellipsis, 6 pt above the head, following the body across displays. Verify: a game screenshot shows the label above the avatar; a long project name is cut with "…"; while crossing a display edge the label shows on both windows.
- [x] 3.2 Spike S2: show candidate hues side by side in `monster_preview` at real size and pick the curated `HUES` list with the user (design D6). Record the result in `design.md` under D6, and apply the fallback if fewer than 5 hues stay readable.
- [x] 3.3 Manual check: with five fake sessions, the user confirms:
  - five clearly different colours;
  - readable labels on a light and a dark wallpaper;
  - the same project getting the same colour after an `end` and a new `add`.

- [x] 3.4 Add the `show_names` setting (default true) and a "Show Names" check item in the menu, which hides or shows every label at once, including on new avatars. Verify: a settings test covers the default and an old file without the key; `game_eval` toggling the item hides and shows all labels and updates the check mark.
- [x] 3.5 Manual check: the user turns "Show Names" off and on from the menu bar, and after a restart the choice is kept.

## 4. Clicks, looking and the quiet frame rate (spike S1)

- [x] 4.1 Route clicks (design D7): a left click gives the happy reaction, and a right click in debug mode opens the debug text field at that avatar. Verify: `game_eval` sending a click to an avatar's region shows `happy` and then the state clip; the text field opens at the right-clicked avatar in debug mode.
- [x] 4.2 Implement the quiet frame rate (design D8): quiet when no avatars are on screen or all are asleep (not while debug mode is on or the text field is open), with an immediate return on enter, wake, click or the pointer over a strip. Verify: `game_eval` shows `Engine.max_fps` switching between 30 and `QUIET_FPS` in each case.
- [x] 4.3 Spike S1: measure CPU standalone (`top`) for no avatars at 30 fps, no avatars at 5 and 10 fps, five sleeping avatars at 5 and 10 fps, and five strolling avatars at 30 fps. Pick `QUIET_FPS`, check that sleeping looks smooth enough, and record the result in `design.md` under D8. Apply the fallback if the quiet mode saves little.
- [x] 4.4 Manual check, the user confirms:
  - clicking an avatar makes it laugh while the terminal keeps keyboard focus;
  - clicks between avatars reach the window behind;
  - the eyes follow the mouse on both displays;
  - all avatars falling asleep after 2 minutes, and one waking within a second on a new prompt.

## 5. Real sessions, multi-display and documentation

- [x] 5.1 Update `README.md`: what the avatars show per state, colours and labels, the limit of 5, sleeping, and the `fake_sessions` script for development. Verify: the README describes these, and the debug monster is no longer mentioned.
- [x] 5.2 Manual check with real agents:
  - two Claude Code sessions in different projects each get their own avatar with the right label;
  - a prompt shows thinking and working, then happy;
  - a permission request shows waiting;
  - `/exit` makes the avatar wave and walk off;
  - switching the home display in "Screen" makes all avatars walk over and take their slots there.

## 6. Integration check

- [x] 6.1 Walk through every scenario in `specs/session-avatars/spec.md` by test or by hand, and tick them off in a short checklist in the PR description. Any deviation found by a spike is either fixed or explicitly accepted by the user.

## Workflow follow-up

- After review and merge: archive with `openspec archive session-avatars`, so the spec lands in `openspec/specs/`.
- Next change: `balloons-and-speech` (speech balloons, text-to-speech and answering requests at the avatar).
