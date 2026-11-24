# Tasks

## 1. Detecting the Dock

- [x] 1.1 Add the pure `DockWatch` (`scripts/core/dock_watch.gd`, design D1), pointer path. Verify with headless tests in `tests/test_dock_watch.gd`:
  - autohide off or a left/right Dock always returns -1
  - resting on the bottom edge returns the display id only after the show delay, including with the pointer pushed against the edge (y == bottom)
  - a brief touch does nothing
  - staying within the Dock height keeps it shown, including the magnified height
  - moving higher hides it at once
  - moving to another display hides it
  - the second display's bottom edge shows it there
- [x] 1.2 Add `MacOverlay.get_dock_prefs()` (design D2) and rebuild the extension. Verify: `game_eval` returns autohide true, tilesize 53 and show delay 0 on the user's machine. (Changing the user's Dock settings to test the 1 s re-read was skipped on purpose.)
- [x] 1.3 Add the GDScript fallback with `defaults read` and the missing-key defaults (design D2). Verify: `game_eval` shows the same prefs as 1.2.
- [x] 1.4 Add `MacOverlay.is_accessibility_trusted(prompt)` and `get_dock_frame()` (design D1, D3), and link ApplicationServices. Verify: after the user granted Godot access, `game_eval` returns the frame 1264×73 pt with its top at 982 while hidden.
- [x] 1.5 Add `DockWatch.update_frame()` with the bottom margin (design D1). Verify with headless tests: hidden below the display; sliding in, which shows at once; fully shown at 899 for a 73 pt frame; sliding away, which hides at once; coming back; another display; stacked displays; autohide off; unknown frame.
- [x] 1.6 Wire both paths into `OverlayController` (design D3): prefs and permission on the poll, the frame every frame near the bottom and every 0.25 s otherwise, `dock_changed`, `dock_lift_pt` and `debug_force_dock`. Verify: a recorder in the running app logs `Dock shown` on the frame where the Dock appears and `Dock hidden` on the first frame it slides away.
- [x] 1.7 Manual check: the user brings up the Dock several times, also beside it and over its icons. The buddies react at the right moment (confirmed by the user after two fixes; see design D1 and D3).

## 2. The hop

- [x] 2.1 Add `DockHop` (design D4): the clamp and the hop curve, with headless tests. The clamp keeps an XL head and label inside; the hop reaches the target in `HOP_SEC` with at most `HOP_ARC_PT` overshoot; it goes back down to 0; a new target mid-hop continues smoothly; hops are counted.
- [x] 2.2 Add the lift to `SessionAvatar` and the `dock_hop` jump clip (design D4), rebuilt with `tools/build_monster_clips.gd`. Verify: `test_monster_clips.gd` covers the new one-shot clip, and the recorder shows the buddies rising from 352 to 269 and playing `dock_hop`.
- [ ] 2.3 Verify click regions and labels: with `Overlay.debug_force_dock(1)`, `game_eval` shows each avatar's region and label raised by the lift, a click in the region reaches the avatar, and the old floor area is pass-through. Reset with `debug_force_dock(-2)`.
- [x] 2.4 Manual check: the user brings up the Dock. The buddies jump up onto it with the jump animation, react quickly enough, and jump back down when it hides (confirmed by the user).

## 3. Multiple displays and edge cases

- [ ] 3.1 Spike S3: with a second display, check that the buddies jump only on the display where the Dock appears, with *Displays have separate Spaces* both on and off. Record the result in `design.md`.
- [ ] 3.2 Manual check: with autohide turned off (⌥⌘D), the buddies stand above the Dock as before and never jump. Turning autohide on again with ⌥⌘D makes them react within a second.

## 4. Documentation and integration

- [x] 4.1 Update `README.md` ("The buddies"): with an auto-hidden Dock, the buddies jump onto it when it appears. Mention the Accessibility permission, the pointer fallback, and the limit to a bottom Dock.
- [ ] 4.2 Walk through every scenario in this change's spec by test or by hand, and tick them off in a short checklist in the PR description. Any deviation is either fixed or explicitly accepted by the user.
