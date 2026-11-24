# Proposal

## Why

The codebase is healthy, but thirteen features in a row left small, compounding costs: the same facts written in several places (session states, the normal buddy height, settings defaults, the bridge version), design references that do not say which change they mean or point to moved files, a few unused functions, and weak typing where scripts meet. `OverlayController` grew to 831 lines and eleven responsibilities with `dock-dodge` and `buddy-drag`; its Dock tracking is self-contained enough to stand on its own. No other change is in flight right now, so this is a good moment to clean up, while the code is small and well tested. The full investigation is in `docs/codebase-audit.md` (findings F01–F18).

## What Changes

All changes keep behaviour identical. Each group below is one small, independently reviewable pull request.

- **References and comments (F04):** every "design Dn" comment names its change (for example `(overlay-window D5)`); stale paths and wrong units are fixed; `OverlayController`'s hand-kept "Public API" list becomes a short responsibility summary; a misplaced doc comment in the bridge moves to its function; one README line explains where design references point.
- **One source for each fact (F02, F03, F13):** session states come from `Protocol.STATE_*` everywhere; walking speed scales against `BuddySize`'s normal height instead of a literal `110`; unexplained numbers become named constants.
- **Dead code (F06):** remove functions verified as unused everywhere (`Overlay.has_keyboard_focus_request`, `Overlay.home_id`, `RegionRegistry.captured_id`, `AvatarManager.avatar_for`, `AvatarManager.is_away`, `Session.to_dict`, `AppConnection.finish`). Native spike methods and `Walkway.side_by_side` / `to_walkway` are removed only if the user confirms (design D3).
- **Readable internal state (F08, F09, F12, F14, F18):** a `Connection` inner class in `BridgeServer`; `_session_info()` renamed and split so its side effects are visible; local variables no longer shadow `Node.name`; a redundant reset in the view hand-over removed; `SwingPhysics._carry` renamed so it no longer shares a name with the avatar's carry phase.
- **Typed boundaries and settings (F05, F10):** existing `preload` constants used as types for sessions, segments, avatars and monster views; typed `Settings` properties for every key, so call sites stop repeating defaults.
- **Bridge tidy-up (F11):** one hello-frame builder, one client-identity type, named time-outs with unchanged values, and one check that keeps the three version numbers in step.
- **Dock tracking out of `OverlayController` (F01, F07, F08):** the Dock state, preference reading, Accessibility prompt and frame polling move into their own script owned by the controller, with the public API unchanged; the `defaults read` parsing moves into the pure `DockWatch` with a test; one screen-rect helper replaces the copies; the `_hover` tuple becomes two named fields.
- **Optional (F15, F17):** a test that every clip the avatar plays exists in `Monster`'s clip lists; tests clean up the files they write into the app data folder.

Out of scope:
- Any change in what the user sees or does: animations, timing, speeds, physics, menu items, settings file format, bridge protocol, plugin behaviour. A bug found during the cleanup is reported, not fixed, unless the user approves the fix.
- Splitting the rest of `OverlayController` (windows, headroom, pass-through, input, focus) into separate scripts (design D6).
- New architecture: no event bus, dependency injection, state-machine framework, base classes or shared registries.
- Renaming public `Overlay` or `Bridge` methods, signals or autoload names.
- Mass renames, reformatting, or rewriting files only to look different.
- The vendored `godot/addons/godot_ai/` and the `native/godot-cpp` submodule.

## Capabilities

### New Capabilities
<!-- none -->

### Modified Capabilities
<!-- none: a pure refactor with no spec-level behaviour change, so `.openspec.yaml` sets `skip_specs: true`. -->

## Impact

- **Godot scripts:** `scripts/autoload/{overlay_controller,settings}.gd`, new `scripts/overlay/dock_tracker.gd`, `scripts/avatars/{avatar_manager,session_avatar,demo_player,quiet_fps}.gd`, `scripts/walkway/walkway_body.gd`, `scripts/bridge/bridge_server.gd`, `scripts/core/{avatar_cast,click_action,region_registry,session_registry,walkway,dock_watch,swing_physics}.gd`, `scripts/debug/{session_panel,debug_text_field}.gd`, `scripts/menu_bar.gd`, comments in most other first-party scripts, `tests/run_tests.gd` and a few tests.
- **Bridge:** `bridge/src/{app_client,mcp_server,protocol}.ts`, `bridge/src/adapters/claude_code.ts`, one new test.
- **Native (only with user approval):** `native/src/mac_overlay.{h,mm}`; requires rebuilding the extension.
- **Docs:** `README.md` (one line), `docs/codebase-audit.md` (findings marked done as groups land).
- **Other changes:** none are active. A feature change started during the cleanup rebases onto whatever groups have landed (design D7).
- **Saved data:** none. `settings.cfg` and `bridge.json` keep their format.
