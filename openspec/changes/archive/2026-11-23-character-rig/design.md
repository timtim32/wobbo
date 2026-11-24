# Design: character-rig

## Context

`overlay-window` is done: an `Overlay` autoload owns a transparent, click-through strip of 360 pt along the bottom of the main display. Content registers hit regions with `Overlay.set_region()` and converts points to pixels with `Overlay.points_to_px()`. The project runs Godot 4.7.2 with the GL Compatibility renderer, capped at 30 fps (about 3.7% CPU on an M5 Pro with a moving debug blob). A temporary `DebugBlob` (`godot/scripts/debug/debug_blob.gd`) walks along the strip, registers a region and reacts to clicks.

There is no character art yet. The target look is a flat illustration without outlines, in a light green (≈ `#6DB045`) and a dark green (≈ `#2F5A2A`), with an off-white eye and fangs and a near-black pupil. The menu bar icon already showed that Godot's built-in ThorVG rasteriser (`Image.load_svg_from_string`) renders our SVGs correctly, so no external tool is needed.

See proposal.md for motivation and `specs/avatar-character/spec.md` for the required behaviour.

## Goals / Non-Goals

**Goals:**
- Make the SVG the single source of truth. Redrawing a part means editing the SVG and re-running one export command; the rig and animations keep working.
- Keep the rig simple enough to build and adjust through the Godot MCP and code, without hand weight-painting.
- Make every clip and colour checkable in isolation, both visually and in headless tests.

**Non-Goals:**
- Mesh deformation or skinned polygons. The flat style works with rigid parts.
- Runtime switching between several character designs. There is one monster.
- An animation state machine driven by Claude's state. That is `session-avatars`.

## Decisions

### D1. One layered SVG as the source
`art/monster/monster.svg` holds the whole monster in its neutral pose on a fixed artboard (viewBox `0 0 400 440`, figure about 400 units tall, feet at the bottom). Every part is a top-level `<g id="part-<name>">`:

- body, spots, brows, eye_white, pupil (pupil plus highlight), eyelid, mouth_neutral (a gentle smile), mouth_smile, mouth_open, mouth_laugh, fangs, ear_l, ear_r, arm_l, arm_r, arm_r_think, leg_l, leg_r

*Added after user feedback during implementation:*
- The resting mouth is a gentle smile instead of a frown.
- `mouth_laugh` is a wide laughing mouth for `happy`.
- `arm_r_think` is the right arm bent in front of the body with the hand at the chin, for `thinking`. It is the only part with a thin dark outline, because a same-coloured limb in front of the body needs one to read. Rotating the hanging arm or stretching it behind the head did not read at overlay size.

Each part group also contains one invisible marker, `<circle class="pivot" r="0">`, that marks the part's joint, for example the shoulder for an arm. The parts overlap where they join (an arm continues behind the body), so rotating them leaves no gaps.

The monster is drawn from scratch with simple paths. *(Changed after user review:)* the first version was reworked. The final drawing keeps the body shape the user liked and redraws the details: a single raised brow and an eyelid fold instead of three brow arcs, an eye ring and an under-eye line; two highlights in the pupil; small fangs hanging down from the smile instead of upward tusks; a few large spots in new places instead of the dotted pattern; a light belly patch; light inner ears; three-fingered round hands; and legs without the dark band and toe lines. A second review round asked for more detail. That added a soft shadow around the eye, a light shade inside the top of the eye white, a shadow side and a highlight on the body, lighter centres in the big spots, shading on the ears and legs, lines between the fingers, three toes per foot, and pink cheeks. Shadows are semi-transparent dark fills (the body shadow is clipped to the body), so they work over both skin and belly and follow the hue shift.

- *Alternatives:* one SVG file per part means the parts lose their shared coordinate system and joints are hard to line up. Drawing directly in Godot with `Polygon2D` makes the art awkward to edit. Both rejected.

### D2. Export: full-canvas rasterise per part, then crop
A headless Godot tool, `godot/tools/export_monster.gd`, run as `Godot --headless --path godot --script res://tools/export_monster.gd`, does the following:
1. Finds the part groups and pivot markers with regular expressions. The SVG layout is our own and kept simple (top-level groups, plain shapes), so a full XML parse is not needed.
2. For each part, writes a copy of the SVG in which only that group is visible.
3. Rasterises each copy at the export scale (`EXPORT_PX_PER_UNIT`, so that the figure is about 440 px tall, twice the Retina display size) with `Image.load_svg_from_string()`.
4. Crops each raster with `Image.get_used_rect()`.
5. Saves `godot/assets/monster/parts/<name>.png`.
6. Writes `godot/assets/monster/manifest.json`, listing each part's crop offset and its pivot in canvas units. Pivots are read from the marker's `cx`/`cy`. They only use translate transforms, so nested transforms do not have to be resolved.

Because every part is rasterised on the same canvas, the offsets line up exactly. The output is deterministic, so re-running the export gives no diff.

- *Alternatives:* importing per-part SVGs with Godot's SVG importer needs each part's bounding box, which the tool would have to compute from path data. Inkscape or rsvg on the command line adds dependencies.
- **Spike S1:** check that ThorVG renders every part as in a full render: arcs, even-odd cut-outs and stroke-free shapes. Check also that recompositing all part PNGs at their offsets matches the full render with an average pixel difference below 1%.
- **Fallback:** move the problem shape into plain filled paths (no strokes or masks). If ThorVG itself is at fault, rasterise with `rsvg-convert` (Homebrew `librsvg`) after asking the user.
- **Result S1 (task 2.3, 2026-11-23, Godot 4.7.2):** passed without changes. All 16 parts render in ThorVG. Recompositing the visible parts at their manifest offsets differs from the full render by an average of **0.0023%** (premultiplied, per channel; the limit is 1%). The check is kept as the headless test `test_recomposited_parts_match_full_render`, so every re-export is verified. Exporting twice gives byte-identical PNGs and manifest. The figure is 397×409 px at `PX_PER_UNIT = 1.0`. Part textures are imported with `mipmaps/generate=true`; the export tool rewrites only the PNGs, so the `.import` settings survive a re-export.

### D3. Rig: `Skeleton2D` with rigid parts on `Bone2D`s
`godot/characters/monster/monster.tscn` uses this hierarchy:

```
Monster (Node2D, monster.gd)
└ Skeleton2D
  └ root (Bone2D, between the feet)
    ├ leg_l, leg_r           → Sprite2D leg_l / leg_r
    └ body (Bone2D, hips)    → Sprite2D body, spots
      ├ ear_l, ear_r
      ├ arm_l, arm_r
      ├ eye (Bone2D)         → eye_white, pupil (child of a "look" Node2D), eyelid, brows
      └ mouth (Bone2D)       → mouth_* (one visible), fangs
```

Every part is a `Sprite2D`, placed at its own pivot from the manifest and with an `offset` so that the pivot is the joint. Draw order (back to front) is: legs, arms, ears, body, spots, eye white, pupil, eyelid, brows, mouth, fangs. It follows the **tree order** shown above: the limb bones come before the body sprite among the body bone's children. *(Changed during implementation: `z_index` was dropped, because z-sorting is global, so the parts of two overlapping monsters would interleave.)* Every `Bone2D` in the scene file has an identity `rest`, because the default zero rest made Godot invert a singular transform when the node entered the tree.

`monster.gd` applies textures, offsets and bone rest positions from `manifest.json` in `_ready()`. A re-exported SVG therefore updates the rig without editing the scene. Bone rest poses are set from the manifest pivots. Clips animate bone `rotation`, `position` and `scale` relative to rest, so redrawn art keeps working as long as the pivots stay at the same joints.

Squash and stretch scale the `body` bone. Children inherit the scale, so the face and arms stay attached (spec "Squash and stretch").

- *Alternatives:* a skinned `Polygon2D` with bone weights gives smooth bends, but needs weight painting and suits the flat, jointed style less well. A plain `Node2D` hierarchy would work too, but `Skeleton2D` and `Bone2D` give rest poses and editor gizmos, and they are what `config.yaml` specifies. Both rejected.

### D4. Animation clips generated in code
`godot/tools/build_monster_clips.gd` (headless) builds two `AnimationLibrary` resources: `clips/body_clips.tres` (`RESET` plus the nine body clips) for `BodyPlayer`, and `clips/face_clips.tres` (`blink`) for `FacePlayer`. *(Changed during implementation from one library: an `AnimationMixer` caches every track of every animation in its libraries. A shared library would let `BodyPlayer` reset the eyelid that `FacePlayer` animates. Every body clip keys every body track, rest values included, so no clip inherits a pose from the previous one.)* Each clip is a short table of keyframes per bone track (rotation, position, scale) and per sprite property (`visible` for mouth variants, `scale` for the eyelid). It is written as data in the builder script, so timing changes are reviewable diffs. Loop modes follow the spec: the looping clips use `LOOP_LINEAR` with identical first and last keys, and the one-shots use `LOOP_NONE`.

Two `AnimationPlayer`s keep the face independent from the body:
- `BodyPlayer` plays the body clips with `playback_default_blend_time = 0.15` s.
- `FacePlayer` plays `blink` (eyelid only), so blinking overlays idle and walk.

`Monster.play(clip)` routes `blink` to `FacePlayer` and everything else to `BodyPlayer`. It returns one-shots (`wave`, `happy`, `error`) to `idle` on `animation_finished`, and on an unknown name it logs a warning and changes nothing. While `idle` plays, a timer with a random 2–6 s interval triggers `blink`. `sleep` keeps the eyelid closed and disables auto-blink. The eyelid is set by `Monster.play()`, not by a body clip, for the reason above.

- *Alternatives:* keying the clips by hand in the editor through the MCP's animation tools is hard to review and to tune consistently. An `AnimationTree` would be overkill for one layer plus a blink overlay. Both rejected.
- Hand-tuning in the editor stays possible, but the builder overwrites `monster_clips.tres`. The README documents that changes go into the builder.

### D5. Eye look-at
`Monster.look_at_point(global_pos)` and `Monster.clear_look_target()` set a target. Every frame, the `look` node (pupil plus highlight) eases towards `dir.limit_length(1) × max_offset`. `max_offset` is the eye-white radius minus the pupil radius, both from the manifest. The offset is computed in the eye's local space, so it stays correct when the monster is mirrored or squashed. Clamping is a pure function, `LookMath.pupil_offset(local_target, max_offset)`, and is unit tested.

### D6. Per-instance colour: hue-rotation shader on the skin parts only
`monster_skin.gdshader` (a `canvas_item` shader) converts each texel to HSV, adds `hue_shift` and converts back, but only for texels with a saturation above about 0.15 (smoothstep 0.10–0.20). Alpha is left untouched. *(Changed during implementation:)* the material sits on `Skeleton2D` and every part uses its parent's material. White (`#FAF9EF`, saturation 0.04), the pupil and greys fall below the threshold and keep their colours exactly. The pink cheeks are saturated, so they are a separate part (`cheeks`) that does not use the shared material and stays pink on every colour. Dark-green details that sit inside non-skin parts, like the eye ring and the mouth lines, shift along with the skin, which a skin-only material would have missed. Note: in Godot 4 the fragment's incoming `COLOR` already is texture × modulate, so the shader works on `COLOR` and does not sample `TEXTURE` again. The first version did, and squared every colour.

Each `Monster` duplicates the material once, so instances do not share the uniform. `Monster.hue` takes a target hue in degrees, and the shift is `hue - BASE_SKIN_HUE` (the hue of `#6DB045`, ≈ 97°). Leaving `hue` unset gives a shift of 0, which is the original art.

- *Alternatives:* `modulate` multiplies colours, so it cannot turn green into purple and it also tints the whites. A palette swap would need fixed palettes per colour. `instance uniform` for CanvasItem shaders is not reliable in the Compatibility renderer. All rejected.

### D7. Size and sharpness
The default display height is `DISPLAY_HEIGHT_PT = 110`. `Monster` sets its scale to `points_to_px(110) / figure_px_height` and recomputes it on `Overlay.layout_changed`, which covers a change of display scale. Part textures are imported with `mipmaps/generate = true`, and the sprites use `TEXTURE_FILTER_LINEAR_WITH_MIPMAPS`. That way the 2× exported art downsamples cleanly to Retina (×0.5) and to 1× displays (×0.25).

- **Spike S2:** check edge quality on the transparent overlay, on Retina and on the external 1× display. Look for dark or light halos where straight-alpha textures are filtered against a transparent background.
- **Fallback:** export premultiplied alpha. Use `CanvasItemMaterial.blend_mode = BLEND_MODE_PREMULT_ALPHA` on the plain sprites and `render_mode blend_premul_alpha` in the skin shader. If needed, turn off `process/fix_alpha_border` on import.
- **Result S2 (task 5.2, 2026-11-23, macOS 27):** passed without the fallback against a dark desktop. Close-ups of the monster on the Retina overlay (6× zoom) show sharp edges with no dark or light fringe. A second monster at half scale, the physical size a 1× display gets (about 0.27 of the export size), is softer but also free of halos, thanks to the mipmaps. The overlay only ever shows on the main display, so the 1× case was simulated by scale on the Retina display. Against a light background (a light window behind the strip, and the user's manual check in task 5.4), the edges are clean as well.
- **CPU (task 5.3, standalone `Godot --path godot`, `top` average over 10 s, M5 Pro, 30 fps):** one walking monster **4.5%**, against 3.7% for the old debug blob. The ten-monster preview is **5.7%**. That is about +0.2 percentage points per extra monster, so the target of about 5 monsters lands around 5%. This is accepted for now. Mitigations (pausing the look-at easing when the target is still, a lower frame rate while every monster sleeps) belong to `session-avatars`, which decides when monsters idle.

### D8. Preview and overlay integration
- **Preview:** `godot/characters/monster/monster_preview.tscn` is run with `project_run(mode="custom")`. It uses the normal overlay window, so it appears in the strip on the real desktop. It shows ten monsters side by side, one per clip, each with a label underneath. Their hues are spread around the colour wheel, and every pupil follows the cursor. It needs no interaction: the MCP can call `play()` through `game_eval` and take game screenshots, and the user judges it on the desktop.
- **DebugBlob:** it now owns one `Monster` instead of drawing a circle. It plays `walk` while moving and faces its walking direction. A left click plays `happy` and rotates the hue by 60° (taking over from the old colour change). Its region becomes the monster's bounding box plus the existing 4 pt margin. Right-click still opens the debug text field.

### D9. Tests
These run headless, in the existing runner (`res://tests/run_tests.gd`):
- Manifest consistency: every part has a PNG and a pivot inside its texture bounds.
- `Monster` scene: it loads, all ten clips exist with the right loop mode, every one-shot ends in `idle` after `AnimationPlayer.advance()`, and an unknown clip leaves the current clip unchanged.
- `LookMath`: pupil clamping.
- Facing: mirroring keeps the position.
- The default hue gives a shift of 0.

Visual quality (appearance, clip readability, sharpness) is checked by hand, through the checks in tasks.md.

### Godot and macOS assumptions
- Godot 4.7: `Image.load_svg_from_string()` (ThorVG), `Skeleton2D`/`Bone2D` rest poses, `AnimationLibrary`, and the import option `mipmaps/generate` for 2D textures in the Compatibility renderer.
- No new macOS APIs. Retina handling uses `DisplayServer.screen_get_scale()`, as `overlay-window` does.

## Risks / Trade-offs

- [Rigid parts show seams or gaps at joints when they rotate far] → Draw overlap into each limb (D1) and keep rotations within about ±35° in the clips.
- [Hue shift makes some colours murky (for example yellow, where the dark green spots lose contrast)] → The preview shows the hue range. If needed, `Monster.hue` takes values from a curated list of good hues in `session-avatars`.
- [Ten clips at 110 pt can be hard to tell apart] → Exaggerate poses (bigger arm and eye motion, mouth variants) and judge them in the preview at real size (task group 4).
- [Animation and per-frame look-at raise CPU above the overlay budget] → Measure with the monster walking (task 5). Up to about 5 monsters is the target. If the cost rises noticeably, pause the look-at easing when the target is still.
- [The builder overwrites manual tweaks to `monster_clips.tres`] → Document it in the README. Timing lives in the builder data.

## Open Questions

- Exact clip timing and poses are tuned in the preview (task group 4). This changes neither the specs nor the task breakdown.
