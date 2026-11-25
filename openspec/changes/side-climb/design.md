# Design: side-climb

## Context

See proposal.md for the motivation.

Current state (from `multi-display` design D2/D3, `buddy-drag` D6):
- `Walkway` (`godot/scripts/core/walkway.gd`) is a 1-D line: one segment per display strip, sorted by the display's global left edge (ties by top edge), each `width` points long, laid end to end. Walkway y is in points from the strip top; y < 0 lies above the strip.
- `WalkwayBody` draws one `Monster` view per strip window whose walkway x span overlaps the body (`indices_overlapping`), placed by `Overlay.walkway_to_local(i, position)`.
- `SessionAvatar` travels with `_walk_to(target_x)`: it just moves along walkway x. Between two displays that are not side by side that is the edge-to-edge hop.
- `Overlay.begin_headroom()` / `end_headroom()` (reference counted) grow **every** strip window up to the top of its display's **usable** area (below the menu bar) while a buddy is carried. `headroom_pt(i)` is that room.
- Strip windows get window level 25 from `MacOverlay.configure_window()`, which is above the menu bar (level 24).

Observed on the user's Mac (NSScreen frames, bottom-left origin, points): built-in `(0, 0, 1512, 982)`, HP `(-229, 982, 1920, 1080)`. The HP stands on the built-in, sticks out 229 pt on the left and 179 pt on the right. Walkway order today: HP (starts further left), then built-in.

Godot: 4.7.2, GL Compatibility. macOS only.

## Goals / Non-Goals

**Goals:**
- Climb routes are plain data of the walkway, built and unit tested headless like the rest of `Walkway`.
- Travel asks a pure route planner for its next waypoint, so the avatar code does not reason about display geometry.
- Everything that already works for side-by-side displays stays unchanged.

**Non-Goals:**
- A general 2-D desk graph with paths over any number of displays. Links only join neighbours in the existing walkway order.
- Carrying a buddy across a climb route.

## Decisions

### D1. Links between neighbouring segments
`Walkway.build()` keeps the segment order and positions as they are. In addition, each segment remembers its whole display rect in Godot's global px (`frame_px`, from `DisplayServer.screen_get_position/size`, the same space as the strip rects; so no conversion from native frames is needed), and the walkway gets one `Link` per pair of neighbours `(i, i + 1)`:
- `kind = &"edge"`: today's crossing, right end of `i` to left end of `i + 1`.
- `kind = &"climb"`: when the two frames are stacked: the top of one frame equals the bottom of the other within 1 pt, and their x ranges overlap. The link records `lower`, `upper` (segment indices), `height_pt` (the lower frame's height minus the lower strip's height above its floor, so the climb runs from the lower floor to the lower frame's top) and up to two `sides`. A side is the lower frame's left or right edge, kept when the upper frame covers that edge's x and also has at least one body width (the largest buddy size) on the inner side of it. Each side stores its walkway x on the lower segment and on the upper segment (the same desk x, inset by half a body so the body stays inside both displays).

A climb link with no side falls back to `&"edge"`.

On the user's layout the link between HP (0) and built-in (1) is a climb link with both sides: right (desk x 1512) and left (desk x 0).

- *Alternative:* re-order the walkway by desk position in 2-D. Rejected: the line order and today's crossings would change for side-by-side layouts that work fine.
- *Alternative:* a separate vertical segment for the climb inside walkway x. Rejected: the climb is attached in the middle of the upper segment, not at its end, so it does not fit a single line.

### D2. Route planner
`Walkway.next_step(from_index, x, to_index) -> {kind: &"walk", x} | {kind: &"climb", link, side}` (pure):
- Same segment: walk to the target x.
- Otherwise look at the link towards `to_index` (one step left or right in the order). An `&"edge"` link gives `walk` to just beyond the shared end, as now. A `&"climb"` link gives `walk` to the chosen side's x on the current segment, and once there, `climb`.
- Side choice: the side with the shortest total distance, walking on the current segment plus walking on the next segment to the target x. Chosen once per link at the start of the step and kept until the climb is done, so the buddy does not turn around halfway.
- `direction_to()` is replaced for travel by this planner. `fully_on()` stays.

Unit tests in `godot/tests/test_walkway.gd`: the user's layout, a wider display above (both sides), a narrower centred display above (edge fallback), side-by-side at different heights (edge), upper display flush with one edge (one side), three displays where only one pair is stacked.

### D3. Climbing in walkway coordinates of the lower strip
A climb is a sub-state of `travel` in `SessionAvatar`: `_climb = {link, side, up}` and a progress `t` in points from the lower floor.
- On the lower strip the body stays at the side's lower walkway x, and `position.y = floor_y - t`. That is y < 0 above the strip, the same space a carried buddy uses.
- At `t = height_pt`, the feet reach the lower frame's top. The body hands over to the upper segment at the side's upper x with `position.y` at the upper strip's bottom edge, and then hops the `BOTTOM_GAP_PT` up onto the floor with the existing `dock_hop` clip. Going down is the reverse: step off the upper floor to the strip bottom, hand over to the lower strip at `t = height_pt`, and climb down to `t = 0`.
- Speed: `CLIMB_SPEED_PT = 150` points per second, times `_speed_scale()` (the built-in display takes about 6 s).
- Facing: towards the side edge (`facing = 1` on the right side).
- While climbing: `can_grab()` is false, labels are hidden like during a carry, and `_update_balloon()` treats it like a carry (no balloon; content waits). The Dock lift is not applied.

### D4. Drawing over the seam at the top
`WalkwayBody._update_views()` adds an `extra_view` hook: during a climb the avatar returns the link's other segment. That segment gets a view placed by desk offset instead of walkway x: `Overlay.local_on_other(i_from, i_to, point)` converts walkway point → global px through strip `i_from`'s window, and back to window-local px of strip `i_to`. The upper strip window sits right above the lower frame's top, so the head shows there while the feet are still on the lower display. Only the window rects matter, so the same code also covers going down. The views mirror the primary view as today (`multi-display` S2).

### D5. Full-height grow for one strip
`Overlay.begin_climb_room(i)` / `end_climb_room(i)` (reference counted per strip) grow only strip `i`'s window; after S1 up to the **usable** top, like the carry headroom; `climb_room_pt(i)` gives that room. It shares the placement code with the carry headroom (`_window_rect`, `_head_px`, the rect re-check) and lingers ~0.5 s after the last `end`, like the headroom. When both are active, the larger room wins. Pass-through keeps working because only the climbing body's region is interactive.

**Result S1 (2026-11-25, Godot 4.7.2, built-in display with notch):** failed. A strip window grown over the menu bar was moved down by macOS and then sat below other apps' windows, so a climbing buddy was hidden behind them. The fallback is taken: the climb room is the same as the carry headroom (up to the usable top); at the seam the buddy is not drawn for the height of the menu bar (about 33 pt), which reads fine.

**Spike S1 (original question):** a strip window at level 25 placed over the menu bar area: is it drawn in front of the menu bar, does the menu bar stay clickable around the buddy, and does macOS leave the frame where Godot puts it (no constraining to the visible frame)? Check on the built-in display with the notch too. **Fallback:** grow only to the top of the usable area (as for carrying), and hide the last bit by letting the body slip behind the menu bar: the view is clipped at the window top while the upper display's view already shows the head. The climb then still reads as one movement.

### D6. Leaving and display changes
- Walk-off and walk-in: the exit (and the entry) is the nearer end of the buddy's run of segments joined by edges (`Walkway.run_bounds`); without climb links that is the whole walkway, as today. Such an inner end lies next to another segment in walkway x, so the body sets `only_run`: it is then drawn only on segments of its own run, and beyond the end it is placed outside its own window instead of showing up at the edge of the neighbouring display.
- `_on_layout_changed` during a climb: end the climb, put the body on the floor of the lower segment at the side's x (remapped), release the climb room. The travel picks up the new route next frame.
- Trailer mode only has the main display, so no links.

### D8. Jumping down instead of climbing down
Climbing down a whole display was slow and dull, so going down is a jump (the user's request during the manual check). At the climb point on the upper display, the body moves to the same desk spot in the lower strip's coordinates and `SwingPhysics.throw()` launches it inwards and upwards (140, -420 pt/s at Normal size) with about 1.1 turns per second, as `_carry = &"falling"`. The existing carry code flies, lands and stands it up; it stays within the lower display's x range with no top limit, does not emit `landed` (so it keeps its slot), and holds the climb room on the lower strip until it stands. Travel then continues to the slot.

### D9. Carrying and throwing over the seam
`_process_carry` limits the body to the run of segments it is on (`run_bounds`), so it no longer slides sideways into the strip beyond a climb link. Where a display stands on top (`Walkway.open_above`), the top limit is lifted. After each physics step, `Walkway.over_seam()` checks whether the feet crossed the lower display's top edge (or, held, the upper strip's bottom edge) where the other display is; then `SwingPhysics.shift()` moves the whole state into the other strip's coordinates. When the pointer is on a display outside the body's run, it is mapped into the body's strip by desk position (`Overlay.pointer_on`). A buddy thrown up lands on the upper display's floor; if that is not home, the travel jumps it back down. While carried, climbing or jumping, the body is also drawn on the display across the seam (D4).

### D7. The `climb` clip
Built in `godot/tools/build_monster_clips.gd` like the other body clips, into `body_clips.tres`: a looping cycle of about 0.6 s. Arms reach up in turns (upper arm rotates up to about −150°, the other down to about −60°), legs bend in counter-phase, the body leans a little towards the facing side, ears sway, the eye looks up (via the existing look offset). It is used for going up only; going down is a jump (D8). `Monster.LOOPING_CLIPS` lists it, or `play()` refuses it.

## Risks / Trade-offs

- [Menu bar cover, S1] → Fallback in D5.
- [A climb of a whole display height is slow with many buddies] → Each buddy climbs on its own; they start from different slots and their sides may differ, so they rarely overlap exactly. If they do, it looks like a little queue, which is fine. Speed is one constant to tune.
- [The upper display's strip may sit higher than the lower frame's top, when the Dock is shown at the bottom of the upper display] → The hand-over uses the upper strip's own bottom, and the `dock_hop` rule already lifts the buddy onto the Dock. The small gap between the lower frame top and the upper strip bottom is drawn by neither window for one hop; acceptable.
- [Stacked frames that are off by a point] → The 1 pt tolerance in D1.
- [The walkway order puts a stacked pair apart, with a third display between them] → No link; today's behaviour (out of scope).

## Migration Plan

No data or settings change. A release ships it; rolling back is reverting the change.

## Open Questions

- The exact climb speed and the clip's timing; tuned by eye during the manual check.
