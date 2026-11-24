# Design

## Context

- Each display's strip window spans the bottom of the display's usable rect and is `STRIP_HEIGHT_PT` = 360 pt tall (`overlay_controller.gd` `_strip_rect`). With autohide on, the usable rect reaches the bottom of the screen (measured: strip bottom = screen bottom, 1964 px).
- The strip windows sit at `NSStatusWindowLevel` (25), above the Dock's level (20). A shown Dock is therefore drawn *under* the buddies.
- Avatars stand at `_floor_y()` and set `position.y` from it every frame (`session_avatar.gd`). Click regions (`Overlay.set_region`) and name labels follow `position`, so a change to the floor carries over to both.
- Measured on the user's machine (macOS 27, 1512×982 pt display):
  - Dock preferences: `autohide` = 1, `tilesize` = 53, `autohide-delay` = 0, `autohide-time-modifier` = 0.15, and no `orientation` key (bottom is the default).
  - `CGWindowListCopyWindowInfo` shows a single Dock-owned window at layer 20 spanning the whole display, both shown and hidden. It cannot tell the states apart.
  - The Dock's `AXList` frame is 1264×73 pt with x 124. Hidden, its top is at 982, the screen edge. Fully shown, its top is at 899, so it floats 10 pt above the edge with 83 pt in view. Sliding in or out passes values such as 970, 944 and 912.
  - At the bottom of the screen, `DisplayServer.mouse_get_position()` reports y = 1964, which equals the screen's height in px. That is one row *outside* the screen rect.
- Buddy heights run from 80 to 170 pt (`buddy_size.gd`, uncommitted `buddy-size` change).

## Goals / Non-Goals

**Goals:**
- Buddies on the display with the shown Dock stand above it from the moment it appears, and come back down as it leaves.
- Pure, unit-tested detection and hop logic, in the same shape as `home_display.gd`.

**Non-Goals:**
- See the proposal for the full out-of-scope list.

## Decisions

### D1. Detect the Dock from its Accessibility frame, fall back to the pointer
A pure `DockWatch` (`scripts/core/dock_watch.gd`) has two entry points:

- **`update_frame(prefs, displays, dock_frame) -> int`** is the main path. `displays` holds `{id, frame_pt}` and `dock_frame` is the `AXList` frame, both in points with a top-left origin at the main display's top-left corner. For each display under the Dock's centre x:
  - `visible = display bottom - frame top`. The display only counts when `-1 <= visible <= frame height + MAX_BOTTOM_MARGIN_PT` (24 pt). This keeps a Dock hidden below display A from counting as "shown" on a display C stacked under A.
  - When `visible > frame height`, the difference is the Dock's gap above the edge, kept as `bottom_margin_pt` (10 pt measured; 10 pt default).
  - The Dock is **shown** while `visible >= VISIBLE_MIN_PT` (1 pt) and it is not **receding** (`visible` lower than the previous reading). As a result the buddy jumps on the first frame the Dock appears and starts down on the first frame the Dock slides away.
  - `shown_height_pt() = frame height + bottom_margin_pt` gives the lift height (83 pt measured).
- **`update(prefs, displays, pointer_px, px_per_pt, now_sec) -> int`** is the fallback without the permission, unchanged from the first version. The pointer arms on the bottom `EDGE_PX` rows, including the row just below the rect where macOS reports a pointer pushed against the edge. The Dock counts as shown after `show_delay_sec`, and stays shown while the pointer is within `dock_height_pt(prefs)`, which is `max(tilesize, largesize if magnification) + DOCK_PADDING_PT` with padding 20 pt.

Both return -1 when `autohide` is off or `orientation != "bottom"`.

**First version (pointer only), replaced:** the user reported the buddy reacted "sometimes too early, sometimes too late". Three causes:
- The Dock covers only part of the width (x 152–1360 of 1512), so touching the edge beside it armed the watcher with no Dock appearing.
- Leaving the Dock sideways hid the real Dock while the buddy stayed up.
- The Dock slides in 0.15 s, which made any delay visible.

**Bug found by measuring:** the first frame-based version accepted at most `frame height + 2` pt in view. It therefore rejected the fully shown Dock (83 pt for a 73 pt frame), and the user saw no jump up, only a short hop while the Dock slid away. The margin and its test (`test_frame_floating_above_the_edge`) come from that recording.

### D2. Dock preferences and permission
`prefs = {autohide, orientation, tilesize, magnification, largesize, show_delay_sec}`. They are read on the existing 1 s layout poll and on application focus-in, so ⌥⌘D and System Settings changes are picked up within a second.

- **Native:** `MacOverlay.get_dock_prefs()` uses `CFPreferencesAppSynchronize` plus `CFPreferencesCopyAppValue` on `com.apple.dock`.
- **Fallback (no native build):** `Overlay.read_dock_prefs_cli()` parses the top-level keys of `defaults read com.apple.dock` every 5 s. Measured: it gives the same values as the native path.
- **Permission:** `MacOverlay.is_accessibility_trusted(prompt)` wraps `AXIsProcessTrustedWithOptions`. The overlay checks it on every poll, and the first time it is missing while autohide is on, it asks once per run with the prompt. Once granted it switches to the frame without a restart (measured).

### D3. Overlay API and polling
`OverlayController` owns a `DockWatch` and exposes:
- `signal dock_changed(strip)` (-1 = hidden), logged as `Overlay: Dock shown on strip i (lift n pt)` / `Overlay: Dock hidden`.
- `dock_lift_pt(strip)`: the shown height minus any gap between the strip's bottom and the screen's bottom.
- `debug_force_dock(id)`: for checks without touching the Dock (-2 follows the Dock again).

`MacOverlay.get_dock_frame()` caches the Dock's `AXList` element, with a 50 ms AX messaging timeout so a busy Dock never stalls a frame. It looks the element up again after an error, for example after `killall Dock`. The frame is read every frame while the Dock is shown or the pointer is within `DOCK_NEAR_PT` (160 pt) of a bottom edge, the row below included. Otherwise it is read every 0.25 s, which also catches a Dock shown from the keyboard.

**Bug found by measuring:** before the bottom row counted, the pointer at y = 1964 was "not near", so reactions came about 230 ms late.

### D4. The hop and the jump clip
`DockHop` (`scripts/core/dock_hop.gd`) holds the lift.
- When the target changes, it starts a hop of `HOP_SEC` = 0.3 s: ease-out going up, ease-in coming down, plus a `HOP_ARC_PT` = 16 pt sine arc. It ends exactly on the target, and a new target mid-hop continues from the current value.
- `max_lift(floor_y, head_top, label_room)` is the clamp. The avatar passes `NameLabel.HEIGHT_PT + NameLabel.GAP_PT` as the label room.
- `hops` counts hops started.

`SessionAvatar` steps the hop each frame with the lift of the strip under its x. On every new hop it plays the one-shot `dock_hop` clip for `HOP_CLIP_SEC` = 0.36 s instead of the mood's clip; afterwards the mood's clip starts again. The mood keeps asking for its clip, so a reaction or work-prop clip that the jump interrupted is replayed. `dock_hop` (in `build_monster_clips.gd`) has no vertical motion of its own: a take-off stretch, arms up in front, legs tucked, ears up, mouth open and a landing squash.

### Godot and macOS assumptions
- Godot 4.7: `DisplayServer.mouse_get_position()` and `screen_get_position()`/`screen_get_size()` share one px space, with `screen_get_max_scale()` px per pt.
- macOS 27: the Accessibility API reports the Dock's `AXList` frame for an auto-hidden Dock, below the screen when hidden. Access is granted per responsible app. During editor runs that is Godot.app, so the entry shows as "Godot".
- CFPreferences reads `com.apple.dock` from a non-sandboxed app.

### Spikes (results)
- **S1 Show delay:** not needed on the main path, because the frame shows the real moment. The fallback keeps `DEFAULT_SHOW_DELAY_SEC` = 0.2 when `autohide-delay` is not set; the user's machine has 0.
- **S2 Dock height:** the real height comes from the frame: 73 pt plus a 10 pt gap at tile size 53. The fallback padding was raised from 16 to 20 pt to match.
- **S3 Dock on a secondary display:** not checked, since only one display was available. The frame-based logic picks the display under the Dock's centre and has a unit test for it. It still needs checking by hand once a second display is connected.

## Risks / Trade-offs

- **Accessibility permission:** a security prompt the user has to approve. Without it the less exact pointer fallback runs.
- **Per-frame AX call** while the pointer is near the bottom: an IPC call to the Dock with a 50 ms timeout. Elsewhere it runs 4 times a second, and never when autohide is off.
- **Work props hidden mid-jump:** the jump clip keys all body tracks, so a held laptop or tool disappears for 0.36 s.
- **XL buddy with a large magnified Dock:** the clamp limits the lift, so the buddy may still overlap the top of the Dock a little.
- **Quiet mode (10 fps):** delays a jump by at most 0.1 s. The pointer near the strip already ends quiet mode.
