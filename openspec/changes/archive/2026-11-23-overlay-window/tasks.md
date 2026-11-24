# Tasks

## 1. Godot project baseline and settings store

- [x] 1.1 Set the window project settings from design D1 (borderless, transparent, per-pixel transparency, transparent background, always on top, no focus, `max_fps=60`) and the custom user dir `ClaudeBuddy` (D8). Verify: `project.godot` contains these keys and the project opens in Godot 4.7 without warnings.
- [x] 1.2 Add the `Settings` autoload (ConfigFile at `user://settings.cfg`, defaults `overlay_visible=true`, `debug_regions=false`, `changed` signal, falls back on load errors). Verify: the headless test runner `res://tests/run_tests.gd` passes tests for defaults, round-trip save/load, and a corrupt file.
- [x] 1.3 Add the headless test runner and document how to run it in `README.md`, along with how to run the project and to turn off "Embed Game on Next Play". Verify: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path godot --script res://tests/run_tests.gd` exits 0, and exits non-zero when a test is broken on purpose.
- [x] 1.4 Manual check: run the project. An empty, invisible strip appears with no frame, title bar or shadow, and the desktop behind it looks unchanged.

## 2. Overlay placement and hit-testing (spike S1)

- [x] 2.1 Implement the `OverlayController` autoload: size and position the window to the bottom strip of the main display's usable rect, poll layout every 1 s, and emit `layout_changed` (D1, D2). Verify: print the window rect and usable rect at startup. They should match, which confirms the hiDPI assumption in D1.
- [x] 2.2 Implement the region registry (`set_region`, `remove_region`) and the pure hit-test logic, including drag capture, in a testable class. Verify: unit tests cover a point inside one region, between two regions, on the edges, and drag capture while the cursor leaves the region.
- [x] 2.3 Wire up the dynamic pass-through polygon per frame, updating only when the hovered region changes (D3). Verify: with no regions, clicks and scrolls reach the window behind the strip.
- [x] 2.4 Add `DebugLayer` (strip outline and region outlines) and the `DebugBlob` placeholder that slides back and forth and changes colour when clicked (D9). Verify: with debug on, the outlines follow the moving blob.
- [x] 2.5 Spike S1 result: quickly click the moving blob 20 times. Write down the hit rate in `design.md` under D3. If clicks are missed, implement the native `set_ignores_mouse_events` fallback after group 3 and repeat.
- [x] 2.6 Measure idle CPU in Activity Monitor with the blob moving. Write the number in `design.md` and lower `max_fps` if it is above about 3%.
- [x] 2.7 Manual check: clicking the blob changes its colour. Clicking right next to it selects whatever is behind it (for example a Finder icon). Resizing the Dock moves the strip within 2 s.

## 3. Native GDExtension: Spaces, fullscreen and accessory app (spike S3)

- [x] 3.1 Scaffold `native/`: add godot-cpp as a git submodule, an SConstruct that builds `macos_overlay` against `Godot --dump-extension-api`, output to `godot/addons/macos_overlay/bin/`, and `macos_overlay.gdextension`. Verify: `scons -C native` builds without errors, and `ClassDB.class_exists("MacOverlay")` is true at runtime.
- [x] 3.2 Implement `configure_window(handle)` (collection behaviour, `NSStatusWindowLevel`, no shadow) and `set_accessory_app()`, and call them from `OverlayController` at startup with the graceful fallback from D4. Verify: if the dylib is temporarily removed, the project still starts and logs one warning.
- [x] 3.3 Document the native build steps (Xcode CLT, SCons, submodule init) in `README.md`. Verify: the steps work from a fresh clone.
- [x] 3.4 Spike S3 result: check the overlay on a second Space and above a fullscreen app (for example Safari in fullscreen). If it is not visible above fullscreen, try `NSScreenSaverWindowLevel - 1`. Record the result in `design.md` under D6, and discuss with the user if neither works.
- [x] 3.5 Manual check: no Dock icon and no Cmd-Tab entry. The blob is visible on every Space without moving along with the Space transition, and above a fullscreen app.

## 4. Focus behaviour (spike S2)

- [x] 4.1 Spike S2: type in Terminal, click the blob, and keep typing. Record whether the keystrokes still reach Terminal in `design.md` under D5.
- [x] 4.2 If S2 shows focus being stolen, implement `remember_frontmost_app` / `restore_frontmost_app` in the GDExtension and call them on mouse-down and mouse-up inside a region. Verify: repeat 4.1, and the keystrokes now keep reaching Terminal.
- [x] 4.3 Implement `request_keyboard_focus(owner)` / `release_keyboard_focus(owner)` with per-owner reference counting (D5), plus unit tests for the counting logic. Verify: the tests pass.
- [x] 4.4 Add a temporary debug text field (shown in debug mode, opened by right-clicking the blob) that requests focus while it is open. Verify: typing goes into the field, and after closing it (Esc or Enter) the previous app is frontmost and receives typing again.
- [x] 4.5 Manual check: going through 4.1 and 4.4 one after the other never leaves the keyboard focus "nowhere".

## 5. Menu bar control (spike S4)

- [x] 5.1 Create a monochrome menu bar icon from the monster's silhouette (PNG at 1x and 2x, `godot/assets/menubar/`). Verify: it looks sharp on a Retina display in both light and dark menu bars.
- [x] 5.2 Add `StatusIndicator` + `PopupMenu` with "Hide/Show Buddies", "Debug regions" (check item), a separator and "Quit Claude Buddy", connected to `Settings` (D7). Verify: every item behaves as described in `specs/menu-bar-control/spec.md`.
- [x] 5.3 Hiding the overlay clears all regions, so everything passes through, and stops the debug drawing. Verify: while hidden, clicks where the blob was reach the window behind.
- [x] 5.4 Spike S4 result: the menu works while the app is an accessory app with `NO_FOCUS`. If not, switch to `NativeMenu` (D7 fallback) and record the result in `design.md`.
- [x] 5.5 Manual check: hide the buddies, quit from the menu, and start again. The app starts hidden, the menu shows "Show Buddies", and the menu bar icon is gone after quitting.

## 6. Integration check

- [x] 6.1 Walk through every scenario in `specs/overlay-window/spec.md` and `specs/menu-bar-control/spec.md` by hand, and tick them off in a short checklist in the PR description. Any deviation found by a spike is either fixed or explicitly accepted by the user.
  - Result (2026-11-23): all scenarios walked through except "Display layout changes" for resolution/scale and display connect/disconnect (the Dock part passed) and the Mission Control window overview. Those two were not verified by hand; the user chose to proceed without them. S2 deviation (brief focus flicker) accepted. Checklist kept for the PR description.

## Workflow follow-up

- After review and merge: archive the change with `openspec archive overlay-window` so the specs move to `openspec/specs/`.
- Next change: `character-rig` (SVG redraw of the monster plus the Skeleton2D rig).
