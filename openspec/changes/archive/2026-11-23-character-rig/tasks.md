# Tasks

## 1. Monster artwork (SVG source)

- [x] 1.1 Draw `art/monster/monster.svg` from scratch on a `0 0 400 440` artboard, following design D1: the part groups `part-body`, `part-spots`, `part-brows`, `part-eye_white`, `part-pupil`, `part-eyelid`, `part-mouth_neutral`, `part-mouth_smile`, `part-mouth_open`, `part-mouth_laugh`, `part-fangs`, `part-arm_r_think`, `part-ear_l`, `part-ear_r`, `part-arm_l`, `part-arm_r`, `part-leg_l`, `part-leg_r`, each with one `class="pivot"` marker and overlap at the joints. Only the neutral mouth is visible in the default pose; the eyelid is open. Verify: a headless rasterise of the full SVG (saved to the scratchpad) shows every feature from spec "Monster appearance", in the reference's proportions and two greens.
- [x] 1.2 Document the art source, layer naming and pivot markers in `art/monster/README.md`. Verify: every part group in the SVG is listed there.
- [x] 1.3 Manual check: the user reviews the full drawing and confirms it is the project's own (spec "Original artwork").

## 2. Part export pipeline (spike S1)

- [x] 2.1 Implement `godot/tools/export_monster.gd` (design D2): it rasterises each part on the full canvas, crops it to its used rect, writes `godot/assets/monster/parts/<name>.png`, and writes `manifest.json` with each part's offset, size and pivot. Set the part textures' import to `mipmaps/generate=true`. Verify: running the export twice in a row leaves `git status` clean the second time.
- [x] 2.2 Add a headless test `test_monster_manifest.gd`: every part from the SVG has a PNG, every pivot lies inside or on the edge of its part's canvas rect, and the figure height in the manifest matches the export scale. Verify: the test runner passes, and fails when a PNG is removed.
- [x] 2.3 Spike S1 result: recomposite all part PNGs at their manifest offsets and compare with a full render of the SVG at the same scale (average pixel difference < 1%). Record the result and any shape changes it needed in `design.md` under D2.
- [x] 2.4 Document the export command in `README.md` (section "Character art"). Verify: the documented command runs as written from the repo root.
- [x] 2.5 Manual check: the user looks at the recomposited image and the full render side by side and sees no missing parts, gaps or shifted parts.

## 3. Rig and character API

- [x] 3.1 Build `godot/characters/monster/monster.tscn` with the `Skeleton2D` and `Bone2D` hierarchy from design D3, plus a `Sprite2D` per part and the draw order from D3. `monster.gd` applies textures, sprite offsets and bone rest positions from `manifest.json` in `_ready()`. Verify: a game screenshot of the monster in rest pose matches the full SVG render (same parts, positions and stacking).
- [x] 3.2 Implement the `Monster` API: `play(clip)` with the unknown-clip warning, `face_left`/`face_right` mirroring around the monster's own position, `look_at_point()` / `clear_look_target()` with eased pupil movement via a pure `LookMath.pupil_offset()`, and display height from `Overlay.points_to_px(110)`, updated on `layout_changed`. Verify: new headless tests cover pupil clamping (inside, on the edge, far outside, zero), that mirroring keeps the global position, and that an unknown clip leaves the current clip unchanged.
- [x] 3.3 Add `monster_skin.gdshader` (HSV hue rotation of saturated pixels only, design D6) as one per-instance material on `Skeleton2D` that every part uses, and `Monster.hue` (degrees; unset gives shift 0). Verify: a test asserts that the default hue gives `hue_shift == 0` and that each monster has its own material; overlay screenshots at ten hues (including 97.6° green and 277.6° purple) show the expected skins with white eyes and fangs.
- [x] 3.4 Manual check: run a temporary scene with three monsters (default green, purple, orange) in rest pose on the overlay. The user confirms the rest pose looks like the drawing and the colours are clearly different, with white eyes and fangs.

## 4. Animation clips

- [x] 4.1 Implement `godot/tools/build_monster_clips.gd` (design D4). It generates `monster_clips.tres` with `idle`, `walk`, `sleep`, `thinking`, `working` and `waiting` (looping) and `wave`, `happy` and `error` (one-shot) on `BodyPlayer`, and `blink` on `FacePlayer`. Verify: a headless test asserts all ten clips exist with the right loop mode, that looping clips have equal first and last keys on every track, and that each one-shot is followed by `idle` after `advance()` past its length.
- [x] 4.2 Add auto-blink during `idle` (random 2–6 s, design D4), and keep the eyelid closed without auto-blink during `sleep`. Verify: a test with a seeded RNG and `advance()` counts several blinks in 30 s of `idle` at different intervals, and none during `sleep`.
- [x] 4.3 Build `monster_preview.tscn` (design D8): ten monsters in the strip, one per clip, with labels, spread hues and pupils following the cursor. Verify: it runs via `project_run(mode="custom")` without errors, and a game screenshot shows ten labelled monsters.
- [x] 4.4 Document in `README.md` that clip timing lives in the builder and how to regenerate and preview the clips. Verify: the documented commands run as written.
- [x] 4.5 Manual check: the user watches the preview at real size. Every clip matches its meaning in spec "Clip meaning" and the clips can be told apart; looping clips show no jump; one-shots return smoothly to idle; idle blinks irregularly. Tune the builder data until the user is satisfied.

## 5. Overlay integration (spike S2)

- [x] 5.1 Make `DebugBlob` show a `Monster` (design D8): `walk` while moving, facing its walking direction, left-click plays `happy` and rotates the hue by 60°, and the region is the monster's bounds plus 4 pt. Verify: in debug mode the region outline follows the walking monster, and the click count still increases in the log.
- [x] 5.2 Spike S2 result: check the monster's edges on the transparent overlay, on the Retina display and on the 1× external display. If halos appear, apply the premultiplied-alpha fallback from D7. Record the result in `design.md` under D7.
- [x] 5.3 Measure CPU (standalone run, `top`) with the walking monster and compare with the 3.7% baseline from `overlay-window`. Record the number in `design.md` and act on the D7/risks mitigation if it rises noticeably.
- [x] 5.4 Manual check: on the real desktop the monster is about 110 pt tall, sharp on both displays, fully visible at the bottom of the strip with room above it for a balloon, and clicking it still works as described in 5.1.

## 6. Integration check

- [x] 6.1 Walk through every scenario in `specs/avatar-character/spec.md` by hand or by test, and tick them off in a short checklist in the PR description. Any deviation found by a spike is either fixed or explicitly accepted by the user.
  - Result (2026-11-23): every scenario checked by test or by hand (checklist in the PR description). Deviations from the original plan, all accepted by the user: the monster was redrawn with its own face and details, plus extra detail and pink cheeks; the resting mouth smiles; `thinking` taps the chin with a drawn front arm; `happy` laughs; `waiting` uses the neutral mouth; CPU with one walking monster is 4.5% (was 3.7%).

## Workflow follow-up

- After review and merge: archive the change with `openspec archive character-rig` so the spec moves to `openspec/specs/avatar-character/`.
- Next change: `claude-bridge` (hooks plus MCP bridge over a local WebSocket).
