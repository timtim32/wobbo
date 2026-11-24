# Monster art

`monster.svg` is the single source of truth for the buddy character. It is an
original drawing.

## Artboard and style

- viewBox `0 0 400 440`. The figure is about 412 units tall, with the feet at
  y ≈ 425.
- The style is flat with no strokes or outlines. Only plain filled paths and
  circles are used, which ThorVG renders reliably.
- Colours:

  | Colour | Hex | Used for |
  | --- | --- | --- |
  | skin | `#6DB045` | body, limbs, eyelid |
  | light | `#A9D87A` | inner ears |
  | belly | `#84C15A` | belly patch (subtle) |
  | dark | `#2E5A27` | spots, brow, eyelid fold, mouth, shading |
  | white | `#FAF9EF` | eye white, highlight, fangs |
  | pupil | `#262626` | pupil |
| props | wood `#B07A43`/`#8C5E30`, metal `#9AA3AD`/`#C4CBD2`/`#6C757F`, laptop `#3A3F47`/`#2C3036`, glow `#9FD3FF`, paper `#F4F1E6`/`#E3DFCF`/`#C9C3AE` | hammer, wrench, laptop, papers (not hue-shifted) |

  The greens are hue-shifted per character at runtime. The white, pupil and
  blush (`cheeks`) are not.

## Parts

Every rig part is a top-level `<g id="part-<name>">`, listed here in drawing
order, back to front. Each group contains one `<circle class="pivot" r="0">`
that marks the joint the part rotates around.

| Part | Contents | Pivot |
| --- | --- | --- |
| `leg_l`, `leg_r` | leg with rounded foot | hip |
| `arm_l`, `arm_r` | arm with a round three-fingered hand and inner shading | shoulder (behind the body) |
| `ear_l`, `ear_r` | ear with light inner ear | where the ear meets the body |
| `body` | the pill-shaped body/head with the light belly patch | hips (centre bottom) |
| `spots` | a few large dark spots on the body | same as body |
| `cheeks` | pink blush (not hue-shifted at runtime) | same as body |
| `eye_white` | eyelid fold and eye white | eye centre |
| `pupil` | pupil with two highlights | eye centre |
| `eyelid` | closed lid with lash line (hidden in the neutral pose) | top of the lid |
| `brows` | the single raised brow | above the eye |
| `mouth_neutral` | gentle smile (the default face) | mouth centre |
| `mouth_smile` | broad smile (hidden) | mouth centre |
| `mouth_open` | open mouth (hidden) | mouth centre |
| `mouth_laugh` | wide laughing mouth (hidden, used by `happy`) | mouth centre |
| `fangs` | two small fangs hanging down from the smile | mouth centre |
| `arm_r_think` | right arm bent in front of the body, hand at the chin, with a thin dark outline (hidden, used by `thinking`) | shoulder |
| `arm_front_l`, `arm_front_r` | both arms bent in front of the body, hands low in the middle, same style as `arm_r_think` (hidden, used by `work_laptop` and `work_papers`, drawn behind the prop) | shoulder |
| `prop_hammer` | hammer in the right hand: wooden handle, grey head, with the fingers drawn over the handle (hidden, `work_hammer`) | shoulder (hangs on the right arm) |
| `prop_wrench` | open-end wrench in the right hand, fingers over the handle (hidden, `work_wrench`) | shoulder (hangs on the right arm) |
| `prop_laptop` | back of an open laptop in front of the belly, glowing top edge and dot (hidden, `work_laptop`) | centre of the base |
| `prop_papers` | a stack of light paper sheets with text lines (hidden, `work_papers`) | centre of the stack |
| `prop_page` | the right page of the stack, flipped over with a horizontal scale (hidden, `work_papers`) | the spine |

Groups with `style="display:none"` are alternative states. The export renders
every part regardless of visibility and records the default visibility in the
manifest.

Limbs and ears extend behind the body, so they leave no gaps when they rotate.
Keep that overlap when redrawing.

## After editing

Re-export the parts with the command in the main `README.md` ("Character
art"). The rig reads positions and pivots from the exported manifest, so no
scene edits are needed as long as each part keeps its joint.
