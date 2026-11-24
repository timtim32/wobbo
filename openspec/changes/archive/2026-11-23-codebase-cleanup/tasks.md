# Tasks

Behaviour must stay identical (design D1). Findings F01–F18 are in `docs/codebase-audit.md`.

Commands used below:
- **Godot suite:** `/Applications/Godot.app/Contents/MacOS/Godot --headless --path godot --script res://tests/run_tests.gd` (must end with `0 failed`).
- **Bridge checks:** `cd bridge && bun test && bunx tsc --noEmit`.
- **Smoke check:** run the app; Play Demo and watch buddies walk in, think, work, jump while waiting, react, sleep and leave; click a buddy and see its app come forward; pick a buddy up, swing it and drop it into another slot; right-click a buddy → Send home; menu bar Size (Small, Extra large), Show Names, Hide/Show Buddies, Screen; click on the desktop next to a buddy and confirm the click reaches the app below; Quit.

Each numbered group is one pull request. Recommended order: 1, 2, 3, 4, 6, 5, 7 (design D7). When a group lands, mark its findings as done in `docs/codebase-audit.md`.

## 1. References and comments (F04, F11 comment)

- [x] 1.1 Qualify every "design Dn" / "spike Sn" reference in first-party code comments (`godot/scripts`, `godot/characters`, `godot/tools`, `bridge/src`, `bridge/scripts`, `native/src`) as `(<change> Dn)` per design D2. Verify: `grep -rnE "design D[0-9]|spike S[0-9]|\(D[0-9]+\)" godot/scripts godot/characters godot/tools bridge/src bridge/scripts native/src` shows no reference without a change name; the Godot suite and bridge checks pass.
- [x] 1.2 Fix the stale comments: the archived multi-display path and the "(design D10)" reference in `overlay_controller.gd`, the units in the `region_registry.gd` header (walkway points, not window pixels), and replace the `OverlayController` "Public API" list with a responsibility summary (design D2). Verify: the diff contains comment lines only.
- [x] 1.3 Move the misplaced doc comment in `bridge/src/adapters/claude_code.ts` from above `WAITS_FOR_USER` to `toEvent`. Verify: bridge checks pass.
- [x] 1.4 Add one sentence to `README.md` saying that design references name the change and live in `openspec/changes/archive/<date>-<change>/`. Verify: the sentence points to an existing folder.
- [ ] 1.5 Manual check: the user opens two files of their choice, follows one design reference in each to its archived `design.md`, and finds the decision it names.

## 2. One source for each fact (F02, F03, F13)

- [x] 2.1 Use `Protocol.STATE_*` for session states in `avatar_cast.gd` (drop its own `STATE_WAITING`/`STATE_ENDED`; build `IN_USE` from `Protocol`), `click_action.gd`, `avatar_manager.gd`, `demo_player.gd` and `session_panel.gd`. Verify: `grep -rnE '&"(waiting|ended)"' godot/scripts --include='*.gd'` only matches `protocol.gd` and clip names; the Godot suite passes.
- [x] 2.2 Make `SessionAvatar._speed_scale()` divide by `BuddySize.height_of(BuddySize.DEFAULT)`, default `WalkwayBody.height_pt` to `Monster.DISPLAY_HEIGHT_PT`, and start `SwingPhysics._height` at `0.0` with a comment that `grab()` sets it. Verify: no literal `110` remains outside `buddy_size.gd`, `monster.gd`, tools and tests; the Godot suite (including `test_swing_physics.gd`) passes.
- [x] 2.3 Replace the magic numbers named in F13 with named constants and a one-line comment each: the walk-in start offset and exit margin in `session_avatar.gd`, the field height in `debug_text_field.gd`, and `_OUTSIDE` in `overlay_controller.gd`. Verify: values are unchanged in the diff; the Godot suite passes.
- [ ] 2.4 Manual check: smoke check, paying attention to the walking pace at Small and Extra large (unchanged), buddies walking in from and off past the walkway ends as before, and a click on an idle buddy still bringing its app forward.

## 3. Dead code (F06)

- [x] 3.1 Remove the functions verified as unused everywhere (design D3): `Overlay.has_keyboard_focus_request()`, `Overlay.home_id()`, `RegionRegistry.captured_id()`, `AvatarManager.avatar_for()`, `AvatarManager.is_away()`, `SessionRegistry.Session.to_dict()`, `AppConnection.finish()` in the bridge. Re-run the full-text search for each name in the PR. Verify: no references remain; the Godot suite and bridge checks pass.
- [x] 3.2 Remove (confirmed, design D3) `Walkway.side_by_side()` and `Walkway.to_walkway()` with their tests, and the native `set_window_level`, `get_window_level` and `set_ignores_mouse_events` (header, implementation, bindings). Rebuild with `scons -C native -j8`. Keep `find_app_of`. Verify: the build succeeds, the app log shows "MacOverlay active", and the Godot suite passes.
- [x] 3.3 Comment the debug knobs that stay (`Overlay.restore_frontmost_on_click`, `QuietFps.check_pointer`, `Overlay.debug_force_dock`) as existing for `game_eval` checks. Verify: the diff is comments only.
- [ ] 3.4 Manual check: smoke check; with the native rebuild, also check that the buddies stay visible on another Space and above a fullscreen app, and that the Dock hop still works.

## 4. Readable internal state and names (F08 bridge part, F09, F12, F14, F18)

- [x] 4.1 In `bridge_server.gd`, replace the connection dictionaries with an inner class `Connection` whose fields (`ws`, `ready`, `deadline`, `client`, `session`, `close_at`, `rejected`) are all declared up front. Verify: `tests/test_bridge_server.gd` passes unchanged.
- [x] 4.2 Rename `BridgeServer._session_info()` to `_resolve_session()` and split the MCP attribution into `_attribute_mcp_connection()`, with doc comments naming the side effects (creates sessions, moves connection counts, emits `session_added`). Verify: the Godot suite passes (the running-app check is part of 4.6).
- [x] 4.3 Rename locals and parameters that shadow `Node.name` in `menu_bar.gd` and `demo_player.gd` (`run_tests.gd` extends `SceneTree`, which has no `name`, so it needs no change); move the `quiet_fps` declaration in `quiet_fps.gd` up to the other variables. Verify: opening the project in the editor shows no `SHADOWED_VARIABLE_BASE_CLASS` warnings for these files; the Godot suite passes.
- [x] 4.4 In `walkway_body.gd`, set `mirroring = false` once after the hand-over `if/else` (F14). Verify: the Godot suite (including `test_walkway_body.gd`) passes.
- [x] 4.5 Rename `SwingPhysics._carry` to `_leftover_sec` (F18). Verify: `test_swing_physics.gd` passes unchanged.
- [ ] 4.6 Manual check: smoke check, plus `bun bridge/scripts/demo_client.ts` (the demo session and its question show in the debug panel) and answering a question from `fake_sessions.ts ask <name>` in the debug panel, and (with two displays) a buddy crossing from one display to the other, walking and carried, without a flicker or a frozen pose.

## 5. Typed boundaries and settings properties (F05, F10)

Design D4 is confirmed: `Walkway` gets a `class_name`, subject to the spike in 5.1.

- [x] 5.1 Spike for design D4: give `walkway.gd` `class_name Walkway`, make `build()` return `Walkway` via `Walkway.new()`, and check that the headless suite and the editor load it without a cyclic-reference error. Record the result in `design.md` under D4. If it fails, keep `load()` and add a comment instead.
- [x] 5.2 Type the boundary variables named in F05 using the existing `preload` constants: `avatar_manager.gd`, `session_avatar.gd`, `walkway_body.gd`, `bridge_server.gd`, `overlay_controller.gd` (`walkway`, `old_walkway`). Verify: `grep -rnE "^\s*var [a-z_]+ = " godot/scripts --include='*.gd'` returns only the deliberate exceptions listed in the PR; the Godot suite passes; the project opens in the editor without new errors.
- [x] 5.3 Add typed `Settings` properties `screen`, `screen_name`, `show_names` and `buddy_size` (design D5) and use them in `menu_bar.gd`, `session_avatar.gd` and `overlay_controller.gd`, removing the repeated fallbacks. Verify: `grep -rn 'get_value(&"' godot/scripts` only matches `settings.gd`; `tests/test_settings_store.gd` passes; an existing `settings.cfg` loads with the same values.
- [ ] 5.4 Manual check: smoke check; change Size, Show Names and Screen, quit, start again, and confirm all three choices were kept.

## 6. Bridge tidy-up (F11)

- [x] 6.1 Add a `helloFrame(info, client)` helper in `app_client.ts` used by `sendOnce` and `AppConnection.connect`, and a `ClientIdentity` type alias for `Omit<ClientInfo, "bridge_version">`. Verify: bridge checks pass.
- [x] 6.2 Name the time-outs (`CONNECT_TIMEOUT_MS`, a hook-send time-out, the MCP connect time-out) with their current values (200, 300, 300 ms) and use the names everywhere. Verify: the diff changes no value; bridge checks pass.
- [x] 6.3 Add (confirmed, design D8) a test that `package.json`, `BRIDGE_VERSION` and `plugin/.claude-plugin/plugin.json` carry the same version. Verify: the test passes, and fails when one value is changed locally.
- [ ] 6.4 Manual check: `cd bridge && bun run build:plugin`, start a Claude Code session with `claude --plugin-dir bridge/plugin`, and confirm the buddy appears, works while a tool runs, and a permission prompt shows Allow/Deny in the debug panel.

## 7. Dock tracking out of OverlayController (F01, F07, F08 `_hover`)

Design D6 is confirmed. Runs after groups 1, 2 and 4, and not at the same time as a feature change that edits `overlay_controller.gd`.

- [x] 7.1 Move the text parsing of `read_dock_prefs_cli()` into `DockWatch.parse_defaults_output(text)` and add a test in `tests/test_dock_watch.gd` with a captured `defaults read com.apple.dock` sample (keys present, missing, quoted, and `autohide-delay` renamed to `show_delay_sec`). Verify: the new test and the Godot suite pass.
- [x] 7.2 Create `scripts/overlay/dock_tracker.gd` (design D6) and move the Dock state and code into it; the controller creates it in `_ready()`, calls `read_prefs()` and `update()` where it calls `_read_dock_prefs()` and `_update_dock()` today, emits `dock_changed`, and keeps `dock_prefs`, `dock_lift_pt()` and `debug_force_dock()` as delegations. Verify: the Godot suite passes; `grep -n "_dock" godot/scripts/autoload/overlay_controller.gd` shows only the tracker field and the delegations; `overlay_controller.gd` is about 110 lines shorter.
- [x] 7.3 Add `_screen_rect_px(screen)` and use it wherever the controller builds a screen rect (F07); replace `_hover` with `_hover_strip` and `_hover_target` (F08). Verify: the Godot suite passes.
- [ ] 7.4 Manual check: with the Dock on autohide and Accessibility access granted, buddies hop onto the Dock when it shows and back down when it hides; with access revoked, the pointer fallback still makes them hop; with the tracker's `native` forced to null via `game_eval`, the `defaults read` fallback still reads the preferences; with autohide off, nobody hops; with two displays, only buddies on the Dock's display hop. Also: click-through next to a buddy, focus hand-back after clicking a buddy, and carrying a buddy across displays.

## 8. Optional (F15, F17)

- [x] 8.1 Add a test that every clip name `AvatarMood` and `SessionAvatar` can play is in `Monster.LOOPING_CLIPS` or `Monster.ONE_SHOT_CLIPS`, and that each work clip with a prop has `_in` and `_out`. Verify: the test passes, and fails when a name is removed from `Monster` locally.
- [x] 8.2 Make `test_settings_store.gd` and `test_bridge_server.gd` delete the files they write under `user://` in `after_each`. Result: no change needed; both already do (`_remove_file()` in `before_each`/`after_each`, and `server.stop()` deletes the info file), and the audit's F17 is corrected. Verify: after the Godot suite, `~/Library/Application Support/ClaudeBuddy/` contains no `test_*` files.
- [ ] 8.3 Manual check: the user runs the Godot suite and looks in `~/Library/Application Support/ClaudeBuddy/`; only the app's own files are there.

## Workflow follow-up

- The five open decisions (two in D3, plus D4, D6 and D8) were confirmed by the user on 2026-11-23. The user still approves the proposal as a whole before any group starts.
- Implement group by group with the apply workflow, one pull request each.
- After the last group: sync `docs/codebase-audit.md` (findings marked done or explicitly skipped), then archive with `openspec archive codebase-cleanup`.
