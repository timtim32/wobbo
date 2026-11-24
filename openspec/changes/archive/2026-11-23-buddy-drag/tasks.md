# Tasks

Headless tests: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path godot --script res://tests/run_tests.gd`.
Start after `dock-dodge` has landed, or rebase on it (both touch `session_avatar.gd` and `_floor_y()`). Also after `always-go-to-session`: this change's "Looking and click reaction" text assumes a click goes to the session in every state.

## 1. Spikes

- [x] 1.1 Spike S1 (design D6): in a scratch branch, grow and shrink the root strip window and one secondary strip window to the full usable height while a buddy strolls, with the stage and UI offset by the headroom. Verify: screenshots or a screen recording show no black or flashing frame, the strolling buddy does not move on screen, and `MacOverlay.get_window_level_of()` is unchanged after the resize. Record the outcome (and the fallback chosen, if any) in design.md.
- [x] 1.2 Spike S3 (design D6): with the native build, press on a buddy and keep the button down while moving the pointer out of the strip; log `DisplayServer.mouse_get_position()` and `mouse_get_button_state()` each frame after `_restore_after_click` has run. Verify: the log shows the pointer and the held button all the way until release. Record the outcome in design.md.
- [x] 1.3 Manual check: the user watches the S1 resize recording and agrees the buddies stay calm while a strip grows and shrinks.

## 2. Gesture and physics (pure logic)

- [x] 2.1 Add `GrabGesture` (design D1) with `HOLD_SEC` = 0.25 and `MOVE_PT` = 6. Verify: `tests/test_grab_gesture.gd` covers quick click, hold without moving, move before the hold time, release exactly at the threshold, and a release after a grab returning `&"drop"`/no click.
- [x] 2.2 Add `SwingPhysics` (design D2): grab, carry step with fixed 1/240 s sub-steps, smoothed and clamped pivot acceleration, release into flight, landing with upright easing, walkway-end and top clamps. Verify: `tests/test_swing_physics.gd` checks that a still pivot ends hanging straight below within 3 s, a body grabbed by the ear tilts towards hanging under the ear, a circular pivot path at the natural frequency produces at least one full turn (|θ − θ0| > 2π) within 5 circles, a sideways flick then stop comes to rest, a released body moving left lands further left, landing ends with tilt a multiple of 2π (wrapped to 0) and feet on `floor_y`, and results are the same at 30 and 60 fps.
- [x] 2.3 Add `AvatarCast.drop_slot()` (design D5). Verify: tests in `tests/test_avatar_cast.gd` for nearest slot, both ends, and x outside the segment.
- [x] 2.4 Manual check: the user reads the test names and the tuned constants at the top of `swing_physics.gd` and agrees they match the intended feel (to be refined in 4.4).

## 3. Overlay: release signal and headroom

- [x] 3.1 Emit `region_released(id, point)` from `OverlayController._on_click_released`, also for the safety-net release in `_process` (design D1). Verify: a `game_eval` that presses and releases on an avatar region shows one `region_input` and one `region_released`.
- [x] 3.2 Add `begin_headroom()` / `end_headroom()` (reference counted, `HEADROOM_LINGER_SEC` = 0.3), the derived grown rect, stage and UI offsets, and `window_to_walkway` / `walkway_to_window` for the mouse handling and pass-through polygon (design D6). Use the fallback from 1.1 if the spike failed. Verify: headless test of the rect and coordinate helpers (grown rect keeps the bottom edge; `window_to_walkway(walkway_to_window(p)) == p` with and without headroom), and a `game_eval` showing a buddy's screen position unchanged before and after `begin_headroom()`.
- [x] 3.3 Make `_update_layout` ignore the grown size, and drop any carry when a real layout change happens mid-drag. Verify: with headroom active, the layout poll logs no strip change; unplugging/plugging a display mid-drag (or `debug` re-layout) drops the buddy.
- [x] 3.4 Let `QuietFps` run at 60 fps while headroom is active (design D6). Verify: `Engine.max_fps` is 60 during a drag and back to 30 a moment after landing.
- [x] 3.5 Manual check: the user turns on the debug region view, picks up a buddy (once 4.x exists, or via a debug call to `begin_headroom()` now) and sees the strip outline grow to the top of the usable area and shrink back, while clicks above the strip reach the window behind once the button is up.

## 4. Carrying a buddy

- [x] 4.1 Add `tilt` to `WalkwayBody`: rotation on every view (primary and mirrored) and the rotated bounding box in `rect_pt()` (design D3). Verify: `tests/test_monster.gd` or a new walkway-body test shows `rect_pt()` of a body tilted by π/2 is the rotated box; existing tests stay green.
- [x] 4.2 Add the carry phases to `SessionAvatar` (`held`, `falling`, `landing`; design D4): skip mood motion, drive `position`/`tilt` from `SwingPhysics`, hide labels, keep looking at the pointer, land on `_floor_y()` (includes the Dock lift), refuse a grab while going. Verify: a `game_eval` script grabs a fake session's buddy, moves the pivot up 200 pt, releases, and checks the buddy is above the strip top while held, lands on `_floor_y()` with `tilt == 0`, and its labels are hidden then shown.
- [x] 4.3 Wire the gesture in `AvatarManager` (design D1, D5): left press starts a `GrabGesture`, `&"grab"` starts the carry and `begin_headroom()`, release drops, `&"click"` runs `go_to_session()`, catching a falling buddy grabs it again, and landing on the home segment swaps slots. Verify: `tests/test_click_action.gd` still passes; `game_eval` checks that a quick press/release on a buddy calls `go_to_session` and a held press does not; dropping the slot-1 buddy at slot 3's x swaps their `slot` values; dropping on another segment keeps the slot and starts travelling.
- [x] 4.4 Spike S2 (design D2): tune `GRAVITY_PT`, `DAMPING`, `MIN_ROD`, `MAX_ACCEL` and `MAX_SPIN` with the user on trackpad and mouse at Small, Normal and Extra large. Verify: the acceptance numbers in design S2 hold in the real app; update the constants and the 2.2 tests if they moved.
- [x] 4.5 Manual check: the user picks up a buddy by an ear, by its belly and by a foot, carries it to the middle of the screen and onto the other display, shakes it sideways, stirs small circles until it spins like a hinge, throws it, catches it in mid-air, and drops it near another buddy. Every scenario in `specs/session-avatars/spec.md` behaves as described, and a quick click on a buddy still brings its app to the front.

## 5. Dangle and land clips

- [x] 5.1 Add `dangle` (loop) and `land` (one-shot, ends in the `idle` pose) to `body_clips()` in `godot/tools/build_monster_clips.gd` (design D7), regenerate with the clip builder, and add both to the clip lists in `tests/test_monster_clips.gd`. Verify: the clip tests pass (loop without jump for `dangle`, one-shot returning to `idle` for `land`), and `monster_preview.tscn` shows both.
- [x] 5.2 Use `dangle` while held and falling and `land` on landing (design D4). Verify: `game_eval` shows `current_clip()` is `dangle` while held and `land` right after landing, then the mood's clip.
- [x] 5.3 Manual check: the user looks at both clips in the monster preview and in the real app at Normal size, and agrees `dangle` reads as "held up, kicking" and `land` as a squashy landing.

## 6. Documentation and integration

- [x] 6.1 Update `README.md` ("The buddies") with picking up, swinging and dropping, and that a click now acts on release. Verify: the README describes it.
- [x] 6.2 Walk through every scenario in this change's specs (session-avatars, overlay-window, avatar-character) by test or by hand, and tick them off in a short checklist in the PR description. Verify: the full headless test suite passes.
- [x] 6.3 Manual check: the user plays with the buddies for a few minutes with the Dock auto-hidden and two displays, and confirms nothing gets stuck (no buddy left floating, strips back to normal, clicks pass through above the strip).

## Workflow follow-up

- After review and merge: archive with `openspec archive buddy-drag`.
