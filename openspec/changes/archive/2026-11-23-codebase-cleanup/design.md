# Design: codebase-cleanup

## Context

See `proposal.md` for the motivation and `docs/codebase-audit.md` for the findings (F01–F18), with file and line references at commit `3f03baf`, the architecture overview and the list of things to leave alone.

What shapes the approach:

- **Tests:** the headless Godot suite (192 tests in 21 files) covers the pure helpers in `scripts/core/` (including `dock_watch`, `dock_hop`, `grab_gesture`, `swing_physics`), the bridge server, the monster rig and clips, headroom and walkway bodies. The bridge has 30 `bun test` tests and a clean `tsc --noEmit`. Windows, click-through, focus, the Dock and multi-display behaviour are verified by hand only.
- **Conventions:** scripts reference each other with `const X := preload(...)`; only `Monster` has a `class_name`. Small inner classes hold structured state (`OverlayController.Strip`, `Walkway.Segment`, `SessionRegistry.Session`). `scripts/core/` holds pure helpers only. Comments trace decisions to OpenSpec designs.
- **Other changes:** none are active; `dock-dodge`, `edges-first-slots`, `always-go-to-session` and `buddy-drag` are archived.
- **Engine and platform:** Godot 4.7.2, GDScript 2.0, macOS only. The native extension is built with SCons against godot-cpp. Dock tracking uses `CFPreferences` (or `defaults read com.apple.dock` without the native build) and, when the user grants Accessibility access, the Dock's `AXList` frame via `AXUIElement` (`MacOverlay.is_accessibility_trusted`, `get_dock_frame`).

## Goals / Non-Goals

**Goals:**
- Identical behaviour before and after every task group, shown by the unchanged test suite plus a manual check.
- Each group is one small pull request that can be reviewed in minutes and reverted on its own.
- After the change, each fact the findings name (states, normal height, defaults, version) has one source, and `OverlayController` no longer contains Dock tracking.

**Non-Goals:**
- Raising test coverage in general. New tests are added only where a task moves logic (the `defaults read` parser) or replaces a duplicated fact with a check (versions, clip lists).
- Changing public method names of the autoloads, the settings file format, or the bridge protocol.
- Any further split of `OverlayController` (D6).

## Decisions

### D1. Behaviour is the contract; tests do not change to fit the code
- Existing test expectations stay as they are. Allowed test edits: deleting a test of a function that this change deletes, renaming a call to something this change renames, and adding new tests.
- Every task group runs the headless Godot suite (and, for bridge work, `bun test` plus `bunx tsc --noEmit`). Groups that touch nodes end with the manual smoke check from the audit (section F).
- If a task reveals a real bug, it is written down in the PR and in `docs/codebase-audit.md`, and left unfixed until the user approves a fix.
- *Alternative considered:* golden-file or screenshot tests for the overlay. Rejected: much more machinery than this refactor needs, and window behaviour depends on the macOS session.

### D2. Design references name their change
- Format: `(<change-name> Dn)`, for example `(overlay-window D5)`, `(multi-display D10, spike S2)`. Change names are the ones in `openspec/changes/archive/<date>-<change-name>/`. Comments added since `dock-dodge` already follow this.
- File paths in comments are avoided; the change name is stable, the archive path contains a date. The README gets one sentence on where to find them.
- The `OverlayController` header keeps the coordinate explanation and replaces the hand-written "Public API" list with one paragraph of responsibilities; the API is the set of functions without a leading underscore.
- *Alternative considered:* removing the references. Rejected: they are how a reader finds the reasoning behind macOS workarounds.

### D3. Dead code: remove only what is proven unused
- "Proven unused" means: no reference in `godot/` (scripts, scenes, tests, tools), `bridge/`, `native/`, `openspec/` or the README, checked with a full-text search in the same PR.
- Functions only used by tests stay when the test states intent (`AvatarMood.work_clip`, `RegionRegistry.has_region`, `Monster.face_left/face_right`, `SessionRegistry.most_recent`, `GrabGesture.is_grabbed`).
- Debug knobs meant for `game_eval` during manual checks stay (`Overlay.restore_frontmost_on_click`, `QuietFps.check_pointer`, `Overlay.debug_force_dock`), and their comments say so.
- **Confirmed by the user (2026-11-23):**
  - `Walkway.side_by_side()` and `Walkway.to_walkway()`: no caller in the app; the multi-display spec behaviour emerges from per-strip views. Remove, with their tests.
  - Native `set_window_level`, `get_window_level`, `set_ignores_mouse_events` (spike tools; `NSWindow.level`, `NSWindow.ignoresMouseEvents`): remove. `find_app_of` (walks parent processes with `sysctl(KERN_PROC_PID)`, finds the `NSRunningApplication`): keep, as a debugging aid for "go to session".

### D4. Types through the existing preload constants
- Use the `preload` constants a file already has, or adds, as static types: `SessionAvatar`, `SessionRegistry.Session`, `Walkway.Segment`, `Monster`. Typed `for` loops and typed returns where the type is known.
- GDScript 2.0 in Godot 4.7 accepts a preloaded script constant and its inner classes as types; no cyclic preloads exist today (`avatar_manager → session_avatar → walkway_body → monster`, `bridge_server → session_registry → protocol`).
- `Walkway.build()` creates its own script with `load(...)` and returns an untyped value. **Confirmed by the user (2026-11-23):** give `walkway.gd` a `class_name Walkway` so `build()` can return `Walkway`. The vendored addon registers only `Mcp*` names, so there is no clash. *Spike:* confirm that `static func build(...) -> Walkway` with `Walkway.new()` loads headless and in the editor without a cyclic-reference error. *Fallback:* keep `load()` and leave the return untyped, with a comment.
  *Spike result (task 5.1):* works. With `class_name Walkway`, `build()` returns `Walkway` through `Walkway.new()`. The three local `const Walkway := preload(...)` lines (in `overlay_controller.gd`, `tests/test_walkway.gd`, `tests/test_overlay_headroom.gd`) had to go, because they would shadow the global name. `--import` registers the class; the headless suite, a load of every script, and a headless editor start show no errors.
- *Alternative considered:* adopting `class_name` for every script. Rejected: a large, mechanical diff that changes the project convention for little gain.

### D5. Settings: one typed property per key
- `Settings` gets properties `screen: String`, `screen_name: String`, `show_names: bool` and `buddy_size: String`, built exactly like the existing `overlay_visible` and `debug_regions` (getter reads the store, setter calls `set_value`). Defaults stay only in `SettingsStore.DEFAULTS`.
- `get_value`, `set_value` and `changed(key, value)` stay, so listeners keep matching on the key.
- The settings file (`user://settings.cfg`, section `settings`) is untouched.

### D6. Dock tracking gets its own script; the rest of `OverlayController` stays
- **New script `scripts/overlay/dock_tracker.gd`:** a plain `RefCounted` that the controller creates in `_ready()` with the `native` object (or null). It holds what is now Dock state in the controller (`dock_prefs`, `_dock`, `_dock_id`, `_dock_forced`, `_dock_cli_left`, `_dock_ax`, `_dock_prompted`, `_dock_poll_left`) and the code of `_read_dock_prefs`, `_update_dock`, `_pointer_near_bottom` and the body of `dock_lift_pt`. It is not in `scripts/core/` because it calls `native`, `DisplayServer` and `OS`.
- **Interface, all inputs passed in:** `read_prefs(now: bool)`; `update(displays: Array, walkway, delta: float) -> bool` (true when the Dock's display changed); `shown_id() -> int`; `lift_pt(strip_index: int, strip_rect_px: Rect2i, displays: Array, walkway) -> float`; `forced: int` for the debug override. It never calls back into the controller.
- **The controller keeps its public API:** `dock_prefs` (a read-only property that returns the tracker's), `dock_lift_pt(i)`, `debug_force_dock(id)` and the signal `dock_changed(strip)`, emitted by the controller when `update()` returns true. Call order in `_process` and `_notification` stays as it is.
- **Pure parsing:** the text parsing of `read_dock_prefs_cli()` moves to `DockWatch.parse_defaults_output(text: String) -> Dictionary`, tested with a captured `defaults read com.apple.dock` sample; only `OS.execute("defaults", ...)` stays in the tracker.
- **Also in the controller:** one `_screen_rect_px(screen) -> Rect2i` helper replaces the copies (the tracker receives rects, not screen indices, where it can), and `_hover` becomes `_hover_strip: int` plus `_hover_target: StringName`.
- **Not now:** extracting headroom, pass-through, mouse routing or focus. They act on the same strip windows in a fixed frame order (`process_priority = 1000`, pass-through last); separate scripts would add indirection without making any one of them easier to change.
- *Alternatives considered:* (a) keep Dock code in the controller and only tidy it: leaves 110 lines and nine state variables of an unrelated concern in the file everyone reads for windows and input. (b) A child `Node` with its own `_process`: rejected because it would make the frame order implicit; the controller calls the tracker explicitly. (c) Splitting into `StripWindows`, `PointerRouter`, `FocusKeeper`: rejected, see "Not now".
- **Confirmed by the user (2026-11-23)** (audit section H, decision 5).

### D7. Order of the groups
- No other change is active, so every group can start. Recommended order: 1 (comments) → 2 (facts) → 3 (dead code) → 4 (names) → 6 (bridge, any time) → 5 (types) → 7 (Dock tracker). Comment-only work first keeps later diffs small; the structural move comes last, onto code that is already tidy.
- A feature change started meanwhile rebases onto whatever has landed. Group 7 should not run at the same time as a feature change that edits `overlay_controller.gd`.

### D8. One bridge version
- The version stays written in `bridge/package.json`, `bridge/src/protocol.ts` (`BRIDGE_VERSION`) and `bridge/plugin/.claude-plugin/plugin.json`, because each is read by a different tool. **Confirmed by the user (2026-11-23):** add a `bun test` that fails when the three differ, instead of importing `package.json` into the compiled binary.

## Risks / Trade-offs

- [A refactor changes timing in the overlay (pass-through, focus hand-back, Dock polling) without failing a test] → Groups 4 and 7 end with manual click-through, focus and Dock checks; `process_priority` and the order of calls in `_process` stay as they are; the Dock tracker is called explicitly, not from its own `_process`.
- [The Dock tracker behaves differently without the native build or without Accessibility access] → Task 7.4 checks all three paths: Accessibility frame, pointer fallback, and `defaults read` fallback (native object forced to null via `game_eval`).
- [Merge conflicts with a feature change started during the cleanup] → D7 ordering; each group is small enough to rebase by hand.
- [A type annotation is wrong and a script fails to load] → That fails the headless suite at once (every script is loaded by the tests or the main scene); the project is also opened in the editor once per typed group.
- [Removing a "dead" function that is used interactively through `game_eval`] → D3 keeps every documented debug knob; none of the removed functions is mentioned in any OpenSpec task or the README.
- [Comment churn hides a real change in review] → Group 1 contains comments and the README only; later groups do not mix in comment-only edits beyond the lines they change.
- [Native removal needs a rebuild that fails on the user's machine] → Task 3.2 is optional and separate; without the rebuild the old binary keeps working, because GDScript never calls the removed methods.
