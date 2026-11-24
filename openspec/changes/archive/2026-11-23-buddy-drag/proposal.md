# Proposal

## Why

Drag & drop is one of the avatar interactions the product promises, but today a buddy only reacts to a click and a right click. Picking a buddy up and carrying it somewhere else makes the buddies feel physical and playful: it should dangle from the pointer like a real thing on a hinge, swing as you move, spin round when you stir the pointer in small circles, and drop down when you let go.

## What Changes

- **Pick up**: pressing the left button on a buddy and holding it (or moving the pointer while holding) picks the buddy up. A quick press-and-release stays a click, so "go to the session" keeps working. Clicks now act on release instead of on press.
- **Dangle and swing**: while carried, the buddy hangs from the point where it was grabbed, which follows the pointer. It swings like a pendulum under gravity: moving the pointer sideways makes it swing, and small circular pointer movements pump it up until it spins all the way round the grab point, like a hinge. It plays a new `dangle` animation (legs kicking, arms flailing) and its eye keeps looking at the pointer.
- **Carry anywhere**: the buddy can be carried over the whole usable area of every display, not only the bottom strip. While a buddy is carried or falling, the overlay strips temporarily grow to the full usable height of their display; they shrink back once it has landed. Outside the carried buddy, the grown area stays click-through for everything except the drag itself.
- **Drop and land**: releasing the button lets the buddy go with the speed and spin it had: it flies a little, falls under gravity to the walkway floor and lands with a new `land` animation (squash, stand upright). A falling buddy can be caught again.
- **New spot**: after landing on the home display, the buddy takes the slot nearest to where it landed; the buddy that stood there swaps to the dropped buddy's old slot. Dropped on another display, it lands there and walks back to its slot on the home display.
- The name label is hidden while the buddy is carried or falling and comes back on landing.

Out of scope:
- Dropping a buddy *onto* something (another buddy, a window, the Dock, the menu bar) to trigger an action.
- Keeping a buddy at a free position where it landed: it always ends in a slot.
- Changing the home display by dropping a buddy on another display (the "Screen" menu stays the way to do that).
- Carrying a buddy that is walking off (leaving): it cannot be picked up.
- Remembering slot order across app restarts.
- Throwing a buddy off-screen or out of the walkway: it stays within the walkway's ends and below the top of the usable area.
- Sound effects, haptics, or physics between buddies (collisions, stacking).
- A setting to turn dragging off.

## Capabilities

### New Capabilities
<!-- none -->

### Modified Capabilities
- `session-avatars`: adds requirements for picking up, carrying (dangling, swinging, spinning), dropping, landing and taking a new slot; changes the click reaction so a click is a press-and-release without picking up.
- `overlay-window`: the bottom strip placement requirement allows the strips to grow to the full usable display height while a buddy is carried or falling.
- `avatar-character`: adds the `dangle` (looping) and `land` (one-shot) animation clips.

## Impact

- New pure helpers in `godot/scripts/core/`: `grab_gesture.gd` (press / hold / move threshold → click or grab), `swing_physics.gd` (pendulum with a moving pivot, throw, fall and landing) and a slot-swap function in `avatar_cast.gd`; unit tests in `godot/tests/`.
- `godot/scripts/autoload/overlay_controller.gd`: headroom (grow / shrink strip windows, stage and UI offset, pass-through and mouse coordinates), pointer capture across strips during a carry.
- `godot/scripts/walkway/walkway_body.gd`: a `tilt` rotation applied to every view; rotated bounds for regions.
- `godot/scripts/avatars/session_avatar.gd` and `avatar_manager.gd`: carried / falling / landing phases on top of the mood, click on release, slot swap.
- `godot/tools/build_monster_clips.gd` and the regenerated clip libraries: `dangle` and `land`.
- Possibly `native/src/mac_overlay.{h,mm}` if growing the windows needs native help (spike S1).
- Interacts with the in-progress `dock-dodge` change: landing uses the same floor height, including the Dock lift. Both changes add requirements to `session-avatars`.
- `README.md`: the buddies section describes picking up and dropping.
