# Proposal

## Why

When two displays are stacked (an external display above the built-in one), a Wobbo that travels to the other display walks off one side of its display and appears at the opposite side of the other one. That reads as a teleport. The two displays do touch: the side edge of the lower display runs straight up to the bottom of the upper one, so the Wobbo can climb up (or down) that edge instead.

## What Changes

- The walkway notices when two neighbouring displays are stacked and a side edge of the lower display ends under the upper display. That edge becomes a climb route between the two displays.
- A Wobbo that travels to the home display over such a link walks to the bottom of the edge, climbs up along the inside of the lower display's side, and pulls itself over the top onto the upper display's floor. Going down, it walks to the place above that edge and jumps off with a spin, like a thrown Wobbo, landing on the lower display's floor.
- When both side edges qualify, the Wobbo takes the one that makes its trip shortest.
- While a Wobbo climbs or jumps down, the lower display's strip grows up to the menu bar (not over it) and shrinks back within a second after the last climber has left it.
- A carried Wobbo follows the pointer over the seam onto the display above and back, and a Wobbo thrown up out of the top of the lower display flies on into the upper one and lands on its floor. Sideways it stays within its own display.
- A climbing Wobbo shows no balloon and no name label, and cannot be picked up. Both come back once it stands on a floor again.
- A Wobbo that leaves (walks off) leaves at the nearest outer end of the display it stands on when the way to the far end of the walkway would cross a climb route.
- New `climb` clip: the character climbs along a vertical edge, arms reaching up in turns and legs pushing, looking along the edge.
- Displays that are side by side, and stacked displays where no side edge of the lower display ends under the upper one (for example a narrow display centred above a wide one), keep today's behaviour.

### Out of scope

- Climbing anywhere else than along a side edge of a display: no climbing over windows, the Dock or the top edge of the upper display.
- Displays that touch only at a corner, or that are stacked with more than one display between them in the walkway order; those keep today's crossing.
- A Dock placed on the side where the Wobbo climbs: the Wobbo climbs in front of it.
- The trailer recording mode, which uses the main display only.

## Capabilities

### New Capabilities
<!-- none -->

### Modified Capabilities
- `multi-display`: "Walkway across displays" gains climb routes between stacked displays; "Walking to the home display" climbs over such a route instead of walking off one side and in at the other.
- `avatar-character`: "Animation clips" adds the looping `climb` clip, and a new requirement describes what it looks like.
- `overlay-window`: "Bottom strip placement" lets a strip grow to the full usable height of its display while a buddy climbs or jumps down there.
- `session-avatars`: "Picking up a buddy" excludes a climbing or jumping buddy; "Carrying over the whole screen" and "Dropping and landing" cross the seam of stacked displays; new "Quiet while climbing".

## Impact

- `godot/scripts/core/walkway.gd`: climb links between stacked neighbours and a pure route planner (next waypoint from segment and x to a target segment). Unit tests in `godot/tests/test_walkway.gd`.
- `godot/scripts/autoload/overlay_controller.gd`: desk-space helpers between strips, and a per-strip grow while climbing (reference counted, up to the usable top like the carry headroom).
- `godot/scripts/walkway/walkway_body.gd`: during a climb, also draw a view on the other display of the link, placed by desk position.
- `godot/scripts/avatars/session_avatar.gd`: travel follows the route, with a climbing sub-state and the jump down; walk-off end choice; carrying and throwing over the seam; no grab, balloon or label while climbing.
- `godot/scripts/core/swing_physics.gd`: `throw()` and `shift()` for the jump and the seam.
- `godot/tools/build_monster_clips.gd` and `godot/characters/monster/clips/body_clips.tres`: the `climb` clip.
