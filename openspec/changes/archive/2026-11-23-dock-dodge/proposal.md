# Proposal

## Why

With the Dock set to hide automatically, macOS barely keeps any space free for it, so the buddy strip sits at the very bottom of the screen. When the user brings up the Dock, it slides up right where the buddies stand. The overlay sits above the Dock's window level, so the buddies cover Dock icons and can block clicks on them. The buddies should make way: jump up onto the Dock while it is shown and jump back down when it hides.

## What Changes

- The app watches the auto-hidden Dock through the macOS Accessibility API. It reads the frame of the Dock's icon list, which sits just below the screen while the Dock is hidden and slides into view when it is shown. This needs a one-time Accessibility permission for the app; macOS asks for it the first time.
- Without that permission the app falls back to following the pointer. The Dock counts as shown once the pointer rests on a display's bottom edge, and as hidden once the pointer moves higher than the Dock's height. This is less exact.
- While the Dock is shown on a display, every buddy on that display jumps up to stand on top of it. As soon as the Dock starts to slide away, the buddy jumps back down to the floor. Each jump plays a short jump clip (stretch with arms up, landing squash). The buddy keeps walking and strolling, and its click region and name label move with it.
- The lift is limited so the buddy's head and name label stay inside the 360 pt strip. The overlay window itself does not move or change size.
- Nothing changes when the Dock does not hide automatically (the strip already sits above the Dock) or when the Dock is on the left or right side.

Out of scope:
- A menu bar setting to turn this off. The behaviour is always on, and a setting can follow if needed.
- Dodging only the part of the strip under the Dock: every buddy on that display jumps, even though the Dock's width is now known.
- A left or right Dock.
- Showing the permission under the app's own name ("ai-buddy"). During editor runs macOS lists it under Godot. An exported, renamed app is a separate change.

## Capabilities

### New Capabilities
<!-- none -->

### Modified Capabilities
- `session-avatars`: adds requirements that the app notices the auto-hidden Dock, and that avatars make way for it while it is shown and return to the floor when it hides.

## Impact

- `native/src/mac_overlay.{h,mm}`: `get_dock_prefs()` (CFPreferences), `is_accessibility_trusted(prompt)` and `get_dock_frame()` (the Dock's `AXList` frame); links ApplicationServices.
- New pure helpers `godot/scripts/core/dock_watch.gd` (Dock shown/hidden from the frame, or from the pointer) and `godot/scripts/core/dock_hop.gd` (the lift and its hop curve), with tests.
- `godot/scripts/core/displays.gd`: keeps each display's native frame (`frame_pt`).
- `godot/scripts/autoload/overlay_controller.gd`: reads the preferences and the permission, runs the watcher, and exposes `dock_lift_pt(strip)`, `dock_changed` and `debug_force_dock(id)`.
- `godot/scripts/avatars/session_avatar.gd`: the lift in `_floor_y()` and the jump clip.
- `godot/tools/build_monster_clips.gd` and `godot/characters/monster/`: the new `dock_hop` clip.
- Interacts with the uncommitted `buddy-size` change, since bigger buddies leave less room for the lift. The clamp uses the current buddy height.
