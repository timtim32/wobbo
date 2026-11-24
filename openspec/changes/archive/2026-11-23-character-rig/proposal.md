# Proposal: character-rig

## Why

The overlay from `overlay-window` works, but so far only a debug blob lives on it. Every later change (`session-avatars`, `balloons-and-speech`, `avatar-interactions`) needs the actual buddy: a one-eyed green monster that can walk, react and show Claude's state. The art and rig are the slowest and most visual part to get right, and they can be built and checked on their own before any Claude integration exists.

## What Changes

- Draw the monster as an original, layered vector illustration in `art/monster/monster.svg`. It has a pill-shaped body that is also the head, one large eye under a single raised brow, pointy ears, two small fangs, a few large spots, a light belly patch, short arms with three-fingered hands and stubby legs, in flat greens. Each movable part is its own named layer.
- Add a small export step that turns the layered SVG into one texture per part plus a manifest with each part's position and pivot, so the art can be redrawn without touching the rig by hand.
- Add a reusable `Monster` scene in Godot: a `Skeleton2D` with bones for body, eye, ears, arms and legs, the part textures attached to their bones, and an `AnimationPlayer`.
- Provide the full set of animation clips the buddy needs: idle (breathing), blink, walk, wave, sleep, thinking, working, happy, error and waiting. Looping clips loop seamlessly; one-shot clips return to idle.
- Let the eye look towards a point (for example the cursor or a balloon).
- Let each monster get its own colour by shifting the hue of the green skin, while the eye white, pupil and fangs keep their colours.
- Size the monster for the overlay strip (about 110 pt tall), so it stays sharp on Retina and non-Retina displays.
- Add a preview scene to browse clips and colours. In debug mode the overlay's debug placeholder shows the walking monster instead of a circle, so the art can be judged on the real desktop.

### Out of scope

- Mapping Claude's session state to clips, walking behaviour, spawning per session, and the name label (`session-avatars`).
- Speech balloons and TTS (`balloons-and-speech`).
- Click-to-focus, drag & drop and the right-click menu (`avatar-interactions`). The debug placeholder keeps its existing region and click handling.
- Sound effects, particle effects and extra outfits or accessories.
- Spine, DragonBones or any other external animation runtime. The rig uses only Godot's built-in nodes.

## Capabilities

### New Capabilities

- `avatar-character`: the buddy character itself. Covers its appearance, the parts it is made of, the animation clips it can play, eye direction, per-instance colour and its on-screen size.

### Modified Capabilities

None. The overlay's region API and debug view are used as they are. The debug placeholder is not specified in `overlay-window`, so showing the monster there changes no requirement.

## Impact

- **New files:** `art/monster/` (layered SVG source and the export script), `godot/assets/monster/` (exported part textures and the manifest), `godot/characters/monster/` (the `Monster` scene, its script, the hue-shift shader and the animation library), a preview scene, and headless tests.
- **Changed code:** `godot/scripts/debug/debug_blob.gd` draws the monster instead of a circle.
- **Dependencies:** none new. SVG import and rasterising use the engine's built-in ThorVG, as the menu bar icon already does.
