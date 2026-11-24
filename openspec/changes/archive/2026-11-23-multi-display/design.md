# Design: multi-display

## Context

Today the `Overlay` autoload (OverlayController) owns the root window and sizes it to the bottom strip of the main display. Content uses window-local pixels:
- `Overlay.strip_rect` and `Overlay.points_to_px()`;
- `Overlay.set_region(id, rect)` for the pass-through polygon;
- a debug layer, the debug monster (`DebugBlob`, which owns a `Monster`), a debug text field, and the session panel from `claude-bridge`.

`MacOverlay` configures one native window.

Godot facts observed on this machine (Godot 4.7.2, built-in Retina display plus a 3440×1440 external display):
- `DisplayServer` reports screen positions and sizes in one global pixel space, scaled by the **largest** screen scale. The external display at scale 1 reports 6880×2880, so all coordinates use 2× even where the physical pixels are 1×.
- `screen_get_scale(i)` gives each screen's own scale (2 and 1).
- The external display is placed to the right of the built-in one and higher up. Its bottom edge is at a different height from the built-in display's.

See proposal.md for motivation and the specs for the required behaviour.

## Goals / Non-Goals

**Goals:**
- One coordinate system for content, the walkway in points, so `session-avatars` places avatars without knowing about windows.
- Each display's strip behaves exactly like today's single strip: click-through, all Spaces, above fullscreen, no focus.
- Pure logic (walkway geometry, home display choice) is unit tested. Windows and crossing are checked by hand.

**Non-Goals:**
- A shared world that is rendered into several windows at once (rejected in D3).
- Strips on other edges than the bottom.

## Decisions

### D1. One strip window per display
- The root window stays the strip of the main display.
- `Overlay` creates one `Window` node per other display, with `display/window/subwindows/embed_subwindows=false`, so each is a real native window. Each is borderless, transparent, always on top and unfocusable (the same flags as the root window from `overlay-window` D1), and is configured with `MacOverlay.configure_window()` using its own native handle (`window_get_native_handle(WINDOW_HANDLE, window_id)`).
- Strip windows are created and destroyed when displays connect and disconnect, as part of the 1 s layout poll that already exists (`overlay-window` D2).

**Spike S1:** check that extra native windows from Godot get the full overlay behaviour (transparency, per-window pass-through polygon, all Spaces, above fullscreen, no focus, no Dock or Cmd-Tab entry) on the external display. **Fallback:** if a `Window` node cannot be configured that way, run a second root window per display by spawning a child process with `--display <id>`. That is heavier, so it is only used if needed.
- **Result S1, technical part (task 2.1, 2026-11-23, Godot 4.7.2):** with `embed_subwindows=false` the `Window` node is a real native window (`is_embedded() == false`). It sits exactly on the external display's strip rect and has window level 25 after `configure_window`, like the root window. Godot destroys the native window of a hidden `Window` and creates a new one on `show()`, so the native configuration is applied again on every show, and the 1 s re-apply skips hidden windows. By hand (task 2.6): the external strip passes clicks and scrolls through, stays on other Spaces and above fullscreen apps, and adds no Dock or Cmd-Tab entry.

### D2. The walkway: one coordinate space in points
`scripts/core/walkway.gd` is pure and unit tested. It builds an ordered list of segments from the connected displays: `{display_id, name, usable_rect_global_px, scale}`.
- **Order:** segments are sorted by the display's global left edge (ties by top edge).
- **Coordinates:** walkway x runs from 0 to the sum of the segment widths in points. Each segment covers `[start, start + width_pt)`. Walkway y is in points from the strip's top, and every strip is `STRIP_HEIGHT_PT` high, so a floor at `y = height - gap` is the same on every display.
- **Mapping:** `to_segment(x) -> {segment, local_x_pt}` and `to_walkway(segment, local_x_pt)`.
- **Adjacency:** `side_by_side(a, b)` is true when b's global left edge equals a's global right edge within 2 px. It decides between a walk-over and an edge-to-edge hop (spec "Walking to the home display").
- **Reconnect:** `rebuild(displays, previous) -> {walkway, remap}`. It moves positions on a vanished segment to the nearest edge of the closest remaining segment.

Every display's strip stays at its own bottom edge on the desk. The walkway only defines the order and the in-between: a buddy at the right end of segment A continues at the left end of segment B.

### D3. Content as model plus per-window views
Content that moves over the walkway, like the debug monster now and the avatars in `session-avatars`, is split in two:
- **Model:** a `WalkwayBody` with walkway position, facing, current clip, clip time, hue and look target. It is updated once per frame.
- **Views:** `Overlay.views_for(rect_walkway)` returns the strip windows a rect overlaps. Each window that shows part of the body gets a view, which is a `Monster` instance positioned in that window's local coordinates. Views are created when a body enters a window and freed when it leaves. A view copies the model each frame: position, facing, hue, look, and clip plus playback position (`BodyPlayer.play(clip)` followed by `seek(time)` when it drifts more than one frame).

While crossing, two views exist: one leaving the right edge of A, one entering the left edge of B. They show the same pose, so the crossing looks like one buddy.

Input works without extra plumbing: each view is in its own window, and that window's pass-through region is the view's rect.
- *Alternative:* one shared `World2D` rendered into every window with a per-window canvas transform. It is less code for drawing, but input, `Control`s and `CanvasLayer`s belong to a single viewport. Events from other windows would have to be forwarded and re-transformed, and the floors at different desk heights would need per-window y offsets anyway. Rejected.
- **Spike S2:** check that two views of a crossing monster stay in sync (no visible pose difference or one-frame lag at the seam), with the clip and the look-at mirrored.

### D4. Coordinates and scale per window (spike S3)
- **Global to window:** each strip window keeps today's rule: its window rect equals its display's computed strip rect in Godot's global pixel space.
- **Points to pixels:** a window's local content scale in pixels per point is the global scale (the maximum screen scale), because Godot sizes and positions windows in that global space. On the 1× display the window's framebuffer is still 1× in physical pixels; Godot and macOS scale it.
- **Spike S3:** check the mixed-DPI model. On the 1× external display, a 110 pt monster must be 110 pt tall (measured with `screencapture`) and sharp. A window placed at a display's strip rect must cover exactly that strip. **Fallback:** if Godot's per-window framebuffer on the 1× display turns out to be 2× or blurry, set each window's `content_scale_factor` to its own screen scale divided by the max scale, and size its viewport per display. The walkway in points is unaffected.
- **Result S3 (task 2.5, 2026-11-23):** passed without the fallback. The external display's strip window covers its strip exactly, as the outline in debug mode shows. In a 1:1-point capture of the external display the monster is about 110 pt tall, the same as on the Retina display, and it is sharp enough at 1× thanks to the mipmaps.
- **Result S2 (task 3.3, 2026-11-23):** passed. Captures of both sides of the seam taken at the same moment show the monster split across the two displays, with the left part on the built-in display and the right part on the external one. Height, floor line and pose match. The external (1×) half is a little softer, as expected. View hand-over at the primary changes copies clip, animation position, eyelid and look offset (`Monster.mirror`).

### D5. Regions and pass-through per window
`Overlay.set_region(id, rect)` takes walkway points (BREAKING for content code inside this repository only; all callers are updated in this change). Every frame the controller:
1. finds the window under the cursor (`DisplayServer.mouse_get_position()` in global px);
2. hit-tests the regions converted to that window's local px with the existing `RegionRegistry` logic, including drag capture;
3. sets that window's pass-through polygon. All other windows get the degenerate outside polygon (everything passes through).

The root window uses `DisplayServer.window_set_mouse_passthrough(polygon, window_id)`; the `Window` nodes use their `mouse_passthrough_polygon` property. The `overlay-window` S1 result (polygon switching is fast enough) carries over per window.

### D6. Home display
`scripts/core/home_display.gd` is pure and unit tested. It takes the setting `screen` (`"auto"` or a display id), the connected displays, the display under the pointer and the time, and returns the home display:
- **A chosen display:** that display if it is connected, else the main display. The choice stays remembered.
- **Automatic:** the display under the pointer, once the pointer has stayed there for `DWELL_SEC = 2.0`. Brief visits are ignored.

Display ids are stable across restarts and reconnects: `MacOverlay.get_displays()` returns `NSScreenNumber` (`CGDirectDisplayID`), `localizedName` and frame. They are matched to Godot screen indices by frame. The setting stores the id, with the name in `screen_name`, so a disconnected choice can still be shown in the menu.

### D7. Walking to the home display
The debug monster (and later each avatar) gets a simple walkway movement:
- **On the home segment:** stroll there at `SPEED_PT = 60` and turn at the segment's ends.
- **Off the home segment:** travel towards it at `TRAVEL_SPEED_PT = 180` with the `walk` clip, facing the travel direction.
- **Neighbouring segments that are side by side:** walk straight across (two views during the crossing).
- **Neighbouring segments that are not side by side:** walk off at the edge (the views clip at the window edge), then appear at the facing edge of the next segment and walk in.
- **Arrival:** stop travelling once the whole body is inside the home segment.

### D8. Menu: "Screen" submenu
The menu bar script adds a `PopupMenu` submenu "Screen", with radio items "Automatic (follow the mouse)", a separator, and one item per connected display (`localizedName`, plus "(main)" for the main display). A remembered display that is not connected is listed as "<name> (not connected)" and disabled but checked. The list is rebuilt on `about_to_popup`.
- **Spike S4 (small):** check that a submenu with radio check items works in the native `StatusIndicator` menu and is rebuilt correctly. **Fallback:** a flat list of items under a "Screen" header.
- **Result S4 (task 4.3, 2026-11-23):** passed. The "Screen" submenu with radio items works in the real menu bar. Choosing the external display checks it, the buddies walk there and stay, and after a restart they start there with the item still checked. Disconnecting a display was not tried by hand; the remapping is covered by tests and a simulated rebuild.

### D9. Debug tools and the session panel
- **Debug outlines:** the debug layer draws each strip's outline in its own window, and region outlines in every window they overlap.
- **Session panel:** the panel and the debug text field are reparented to the home display's window when the home changes.

### D10. Performance (spike S5)
A transparent strip window per display costs rendering time even when empty. A strip window with no views and no debug drawing gets `Window.visible = false` after 1 s and is shown again just before a view enters it. Showing and hiding must not steal focus; it calls `configure_window` again.
- **Spike S5:** measure CPU with two displays, comparing an empty second strip (hidden) with one that has a walking monster. **Fallback:** if hiding and showing flickers or loses the native configuration, keep the window visible and lower the frame rate of strips without content to 5 fps.
- **Result S5 (task 3.4, standalone, `top`, M5 Pro, 30 fps):**
  - Monster on the built-in display (external strip hidden): **5.6%**.
  - Monster on the external display (root strip empty but still drawn, because Godot cannot hide its root window): **6.9%**.
  - Single display before this change: 4.5%.
  - Hiding works without flicker or focus changes; the native configuration is re-applied on show.
  - The remaining cost is the root window drawing an empty strip when the buddies are elsewhere. A later improvement could keep the root window off-screen in that case.

### Godot and macOS assumptions
- Godot 4.7: `Window` nodes as native windows (`embed_subwindows=false`), `Window.mouse_passthrough_polygon`, `window_get_native_handle(..., window_id)`, `DisplayServer.screen_get_*` in max-scale global space, and `PopupMenu.add_submenu_node_item` in a `StatusIndicator` menu.
- macOS: `NSScreen.screens`, `localizedName`, `deviceDescription["NSScreenNumber"]`, and the same collection behaviour and level per window as in `overlay-window` D4.

## Risks / Trade-offs

- [Two views of one buddy drift apart (animation or look-at), so the seam is visible during a crossing] → The view copies clip time and look offset from the model every frame (S2). Crossings are short.
- [Mixed DPI makes the buddy a different size or blurry on the 1× display] → Spike S3, with the per-window content scale as fallback.
- [More windows cost more CPU] → Hide empty strips (S5).
- [Automatic mode makes buddies run back and forth] → A 2 s dwell, and travel only starts once the home display changed.
- [Displays not side by side make the walkway look odd] → An edge-to-edge hop is explicitly allowed by the spec and documented.
- [The `set_region` coordinates change (window px to walkway points)] → All callers are in this repository and are updated here. Later changes only use walkway points.

## Migration Plan

- Settings get the keys `screen` (default `"auto"`) and `screen_name`. Older settings files without them load with the defaults.
- Content code in this repository moves to walkway coordinates in this change.

## Open Questions

- The exact dwell time (2 s) and travel speed (180 pt/s) are tuned in the manual checks. This changes neither the specs nor the tasks.
