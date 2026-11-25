# Tasks

## 1. Walkway: climb links and route planner

- [x] 1.1 Pass each display's frame in points into `Walkway.build()` (from `Displays.match` via `Overlay._update_layout`) and store it per segment. Verify: existing `godot/tests/test_walkway.gd` still passes and a new test checks the stored frames.
- [x] 1.2 Build a `Link` per pair of neighbours with `edge` or `climb` kind, climb height and qualifying sides (design D1). Verify: tests for the user's layout (built-in `0,0,1512,982`, HP `-229,982,1920,1080` → climb link with both sides), a narrower centred display above (edge), side by side at different heights (edge), upper display flush with one edge (one side), three displays with one stacked pair.
- [x] 1.3 Add `next_step(from_index, x, to_index)` with the shortest-side choice (design D2). Verify: tests that a buddy near the right edge of the lower display gets the right side, one near the left gets the left side, and an edge link gives today's walk past the end.
- [x] 1.4 Run the Godot test suite headless (`godot --headless --path godot -s res://tests/run_tests.gd`). Verify: all tests pass.
- [ ] 1.5 Manual check: start the app with the HP above the built-in display; the log line for each strip also shows the link between them (`climb`, sides left and right).

## 2. Overlay: room to climb and drawing over the seam

- [x] 2.1 Spike S1 (design D5, result: fallback taken): grow the built-in strip window to the display's frame top with a debug key and put a debug monster at the top. Verify by hand: it is drawn in front of the menu bar (also next to the notch), menu bar items next to it still open, and the window keeps its rect. Record the result in design.md; take the fallback if it fails.
- [x] 2.2 Add `begin_climb_room(i)` / `end_climb_room(i)` / `climb_room_pt(i)`, sharing the placement and rect re-check with the carry headroom, with a 0.5 s linger. Verify: a test or debug check that the room is reference counted per strip and the window returns to its strip rect after the linger.
- [x] 2.3 Add the desk-offset mapping between two strips and the `extra_view` hook in `WalkwayBody` (design D4). Verify: a test in `godot/tests/test_walkway_body.gd` (or a pure helper test) that a point at the lower frame's top maps to the bottom edge of the upper strip window.
- [x] 2.4 Manual check: with the debug monster placed at the top of the built-in display's right edge, half of it shows on the built-in display and half on the HP, with no gap or offset at the seam; after release, clicks above the built-in strip reach the windows behind within a second.

## 3. The climb clip

- [x] 3.1 Add a looping `climb` clip to `godot/tools/build_monster_clips.gd` (design D7) and rebuild `body_clips.tres`. Verify: the monster preview scene plays `climb` in a loop without a visible jump at the restart.
- [x] 3.2 Manual check: in the monster preview at normal and small size, `climb` reads as climbing hand over hand and is clearly different from `walk`, `dangle` and `waiting`.

## 4. Avatars: travel over a climb route

- [x] 4.1 Make `travel` in `godot/scripts/avatars/session_avatar.gd` follow `Walkway.next_step()`, with the climb sub-state (design D3): climb speed, facing the edge, hand-over at the top with the `dock_hop` clip, climb room begin/end, and the extra view. Verify: the avatar tests (or a scripted scene) show a buddy travelling from lower to upper and back ends at its slot on the home display.
- [ ] 4.2 No grab, no label and no balloon while climbing; balloon content waits (design D3). Verify: a test that `can_grab()` is false during a climb, and by hand that a question asked during a climb appears after the buddy stands.
- [ ] 4.3 Walk-off exits at the nearer end of the buddy's own segment when the far end lies across a climb link, and a layout change during a climb puts the buddy on the lower floor (design D6). Verify: tests for the exit choice; by hand, move the HP in Display Settings during a climb.
- [x] 4.4 Run the Godot test suite headless. Verify: all tests pass.
- [ ] 4.5 Manual check: with the HP above the built-in display and the screen setting on automatic, move the pointer to the HP and wait. Each Wobbo walks to a side edge of the built-in display, climbs up, steps onto the HP and walks to its spot. Move the pointer back: they climb down. With the displays side by side again (Display Settings), they cross as before.

## 5. Jumping down and carrying over the seam

- [x] 5.1 Add `SwingPhysics.throw()` and `shift()` (design D8, D9). Verify: tests in `godot/tests/test_swing_physics.gd` that a thrown body lands upright on the floor and that `shift()` moves the flight.
- [x] 5.2 Going down jumps off the upper display with a spin and lands on the lower floor, keeping its slot (design D8). Verify by hand: move the pointer back to the built-in display; the Wobbo jumps off the HP above the built-in's edge, tumbles and lands.
- [x] 5.3 Carry within the run, over the seam where a display stands on top, and throw up onto it (design D9). Verify: tests for `Walkway.over_seam()` and `open_above()`; by hand, carry a Wobbo up from the built-in onto the HP and back, and throw one up out of the top of the built-in so it lands on the HP.

## Workflow follow-up

- Sync the delta specs and archive the change after the manual checks pass.
- Ship as in the usual flow (test, push, fast-forward main, release).
