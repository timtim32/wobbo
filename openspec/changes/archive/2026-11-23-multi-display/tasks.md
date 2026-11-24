# Tasks

## 1. Displays and the walkway model

- [x] 1.1 Add `MacOverlay.get_displays()` to the GDExtension (`NSScreenNumber`, `localizedName`, frame in points, main flag) and a GDScript helper that matches them to Godot screen indices by frame (design D6). Verify: in the running app, `game_eval` lists both displays with their macOS names and the right Godot screen index.
- [x] 1.2 Implement the pure `Walkway` (`scripts/core/walkway.gd`, design D2): ordered segments, mapping between walkway x and (segment, local x), `side_by_side`, and `rebuild` with remapping to the nearest edge. Verify: headless tests cover one display, two side by side, two not side by side, three displays, a display removed with positions on it, and a display added.
- [x] 1.3 Implement the pure `HomeDisplay` (`scripts/core/home_display.gd`, design D6): a chosen display, a missing chosen display (falls back to main, choice kept), automatic mode with a 2 s dwell, and brief visits ignored. Verify: headless tests cover each case with explicit times.
- [x] 1.4 Manual check: with both displays connected, the user confirms the display names the app prints and that the walkway order (built-in first, then the external display) matches the desk.

## 2. A strip window per display (spikes S1, S3)

- [x] 2.1 Make `Overlay` create and remove one strip window per display in its layout poll, with the overlay flags and `configure_window` per window (design D1). Keep the root window as the main display's strip. Verify: with two displays, `game_eval` shows two windows whose rects equal the computed strip rects, both at window level 25.
- [x] 2.2 Switch `Overlay.set_region` to walkway points and pass-through to per-window polygons (design D5), and update the `RegionRegistry` callers. Verify: headless tests for the region-to-window conversion (a region on one window, a region on the seam of two windows); existing tests stay green.
- [x] 2.3 Draw strip outlines in every window and region outlines in every window they overlap (design D9). Verify: game screenshots of both windows in debug mode show their outlines.
- [x] 2.4 Spike S1 result: on the external display, check transparency, click-through outside regions, all Spaces, above fullscreen, no focus stealing, and no extra Dock or Cmd-Tab entry. Record it in `design.md` under D1, and apply the fallback if needed.
- [x] 2.5 Spike S3 result: measure the strip on the 1× display (does the window cover the strip exactly) and, after group 3, the monster's size in points and its sharpness there. Record it in `design.md` under D4, and apply the fallback if needed.
- [x] 2.6 Manual check: in debug mode both displays show a strip outline. Clicks and scrolls on both strips reach the windows behind them. On the external display the strip stays visible on another Space and above a fullscreen app.

## 3. Walking across displays (spikes S2, S5)

- [x] 3.1 Implement `WalkwayBody` (model) and per-window `Monster` views that copy the model each frame (design D3). Move the debug monster onto it, with its region in walkway points. Verify: headless tests for view creation and freeing when a body's rect enters or leaves a window's span (pure helper); in the app, the monster strolls on the main display as before.
- [x] 3.2 Implement travel to the home display: stroll on the home segment, travel at 180 pt/s off it, cross side-by-side neighbours, and hop between neighbours that are not side by side (design D7). Verify: headless tests for the movement decisions (direction, crossing versus hop, arrival); `game_eval` setting the home display makes the monster walk over.
- [x] 3.3 Spike S2 result: record the crossing (game screenshots of both windows at the same moment, plus the user's view) and check that the two views match in pose and look. Record it in `design.md` under D3.
- [x] 3.4 Spike S5 result: hide strip windows without content (design D10), then measure CPU (standalone, `top`) with the monster on display 1 and display 2. Record it in `design.md` under D10, and apply the fallback if hiding flickers or loses the native configuration.
- [x] 3.5 Manual check: the user watches the monster walk from the built-in display over to the external display and back. It does not jump, it is the same size and sharp on both, and clicking it works on both displays.

## 4. Home display and the "Screen" menu (spike S4)

- [x] 4.1 Add the settings `screen` (default `"auto"`) and `screen_name`, with tests for defaults and round-trip (design D6, migration plan). Verify: the settings tests pass, including an old settings file without the keys.
- [x] 4.2 Add the "Screen" submenu with "Automatic (follow the mouse)", the connected displays and a remembered but disconnected display (design D8), connected to `Settings` and `HomeDisplay`. Verify: `game_eval` of the menu items after rebuilding; choosing an item updates the setting.
- [x] 4.3 Spike S4 result: check the submenu with radio items in the real menu bar. Record it in `design.md` under D8, and apply the flat-list fallback if needed.
- [x] 4.4 Handle display changes (design D2 `rebuild`): the walkway is rebuilt and bodies are remapped, and a chosen display that comes back becomes home again. Verify: headless tests via `Walkway.rebuild` and `HomeDisplay`; in the app, simulate a removal by calling the rebuild with one display in `game_eval`.
- [x] 4.5 Document the "Screen" menu and the multi-display behaviour in `README.md`. Verify: the README describes automatic mode, a chosen screen and disconnected displays.
- [x] 4.6 Manual check:
  - Choose the external display in "Screen": the monster walks over and stays there wherever the mouse goes.
  - Choose "Automatic": the monster follows the mouse to the other display after about 2 seconds, and ignores brief passes.
  - Quit and restart: the choice is kept.
  - If possible, disconnect the external display: the monster comes back to the built-in display, and walks over again when it is reconnected.

## 5. Panel and debug field on the home display

- [x] 5.1 Reparent the session panel and the debug text field to the home display's window when the home display changes (design D9). Verify: in debug mode with the home on the external display, a game screenshot of that window shows the panel, and the panel's region works there.
- [x] 5.2 Manual check: with the home on the external display, the session panel is there, its buttons work, and typing in the debug text field still hands focus back afterwards.

## 6. Integration check

- [x] 6.1 Walk through every scenario in `specs/multi-display/spec.md`, `specs/overlay-window/spec.md` and `specs/menu-bar-control/spec.md` by test or by hand, and tick them off in a short checklist in the PR description. Any deviation found by a spike is either fixed or explicitly accepted by the user.

## Workflow follow-up

- After review and merge: archive with `openspec archive multi-display`, so the deltas merge into `openspec/specs/`.
- Next change: `session-avatars` (one monster per session on the walkway).
