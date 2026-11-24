# Proposal: buddy-size

## Why

The buddies are about 110 points tall. On a large external display they can look small, and on a busy laptop screen the user may want them smaller. The user wants to choose the size, from the menu bar like the other settings.

## What Changes

- **"Size" submenu** in the menu bar with four radio items: **Small** (80 pt), **Normal** (110 pt, default), **Large** (140 pt) and **Extra large** (170 pt). Exactly one is checked.
- **Everything follows:** choosing a size changes all buddies at once, including ones that walk in later and the demo's pretend buddies. Their click regions, name labels, spots on the strip and walking speed follow the new size. Walking speed scales with the size, so the legs do not slide.
- **Saved:** the choice persists with the other settings. A missing or unknown value falls back to Normal.

### Out of scope

- A free size slider or sizes outside the four steps.
- A different size per buddy.
- Scaling the name label's text (it stays readable at 12 pt) or the strip's height (360 pt already fits Extra large plus a label and a future balloon).
- The monster previews in `monster_preview` (developer tools stay at Normal).

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `menu-bar-control`:
  - a new requirement, "Buddy size", for the submenu;
  - "Persisted settings" adds the size, with Normal as the default.
- `avatar-character`: "On-screen size and sharpness" allows the chosen heights of 80, 110, 140 and 170 points, staying sharp at each.

## Impact

- **`Monster`:** the fixed `DISPLAY_HEIGHT_PT` becomes a `height_pt` property (default 110) that rescales the rig.
- **`WalkwayBody` / `SessionAvatar`:** pass the height to every view, and scale the walking speeds.
- **`Settings`:** a new key `buddy_size` (default `"normal"`).
- **Pure helper:** `BuddySize` (the steps and the menu items), with tests.
- **Menu bar script:** the "Size" submenu.
- **`README.md`:** the new menu item.
