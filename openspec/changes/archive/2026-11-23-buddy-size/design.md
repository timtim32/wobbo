# Design: buddy-size

## Context

- **`Monster.display_scale()`:** scales the rig so the figure is `DISPLAY_HEIGHT_PT` (110) points tall: `Overlay.points_to_px(110) / figure height`. `_apply_scale` runs on `_ready` and on `layout_changed`.
- **Derived from the bounds:** `get_local_bounds()` follows the scale. Everything around a buddy is derived from it through `WalkwayBody.bounds_pt()`:
  - the click region (`rect_pt().grow(4)`);
  - the name label (above `bounds_pt().position.y`);
  - the stroll range and the slot count (`AvatarCast.slot_count` uses the body width).
- **Speeds:** `SessionAvatar` walks at fixed speeds in points per second: stroll 60, walk in and out 180, travel 180.
- **Textures:** the parts are exported at 440 px for the 440-unit artboard, twice the 220 px a 110 pt buddy needs on Retina.
- **Settings and menu:** `Settings` keeps typed keys with defaults in `SettingsStore.DEFAULTS`. The menu bar script already builds a radio submenu ("Screen") from a pure helper (`ScreenMenu`).

## Goals / Non-Goals

**Goals:**
- One setting that every buddy follows at once, including new ones.
- Pure, tested mapping from the setting to heights and menu items.

**Non-Goals:**
- A size per buddy, a slider, or scaling the label text or the strip.

## Decisions

### D1. Height as a monster property
`Monster.DISPLAY_HEIGHT_PT` becomes the default of a new `@export var height_pt := 110.0`. Its setter calls `_apply_scale()`. `display_scale()` uses `height_pt`. Previews and tests that do not set it keep 110.

### D2. The setting and the steps
The pure `BuddySize` (`scripts/core/buddy_size.gd`) holds the steps:

| Key | Label | Height |
|---|---|---|
| `small` | "Small" | 80 pt |
| `normal` | "Normal" | 110 pt |
| `large` | "Large" | 140 pt |
| `xl` | "Extra large" | 170 pt |

- **`height_of(key)`:** gives the height, or 110 for an unknown key.
- **`items(key)`:** gives the menu items, with exactly one checked.
- **Setting:** `SettingsStore.DEFAULTS` gets `&"buddy_size": "normal"`.

### D3. Buddies follow the setting
- **Views:** `WalkwayBody` gets `height_pt`. Like `hue`, it copies the value to every view each frame when it differs (primary and mirrored). New views get it when they are created.
- **`SessionAvatar`:** reads `BuddySize.height_of(Settings.get_value("buddy_size"))` in `setup()`, and updates on `Settings.changed`. Bounds, region, label, stroll range and slots follow on the next frame.
- **Speeds:** the stroll, walk and travel speeds are multiplied by `height_pt / 110`, so the walk cycle matches the ground speed at every size.
- **Slots:** the manager's slot count already uses the current body width, so on a narrow display Extra large may give fewer slots. The cast then sends the avatars in the dropped slots home, as it already does for narrow displays.

### D4. Sharpness
- **Retina:** 170 pt is 340 px, which is still below the 440 px source, so the parts are only scaled down.
- **The 1× external display:** 170 px, scaled down too.
- **Small:** 80 pt is 160 px on Retina. The mipmaps (`TEXTURE_FILTER_LINEAR_WITH_MIPMAPS`) keep it clean.

So no new export is needed. A check by eye at Small and Extra large on both displays confirms it.

### D5. Menu
The menu bar script gets a "Size" submenu built from `BuddySize.items()`, with radio items placed after "Screen". It sets `buddy_size` on a click and is re-synced on `Settings.changed`, like "Screen".

## Risks / Trade-offs

- [At Extra large the buddies are wide (about 165 pt), so a balloon above a buddy in a later change has less room] → The strip is 360 pt: 170 for the buddy, about 26 for the label, and about 160 left for a balloon. Enough.
- [A size change while a buddy crosses a display edge, or walks in] → The bounds change at once; the views and regions follow on the next frame. Harmless.
- [Faster walking at Extra large makes the trip to another display quicker] → That is intended; it matches the stride.
