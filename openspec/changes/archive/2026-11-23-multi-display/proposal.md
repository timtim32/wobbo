# Proposal: multi-display

## Why

The overlay always lives on the main display, which `overlay-window` chose on purpose to keep v1 small. With more than one display, the user wants the buddies on the screen they are actually using. And instead of jumping there, the buddies should walk: leave one screen at its edge and walk in on the next. That makes the overlay feel like it belongs to the whole desk. `session-avatars` will put several walking monsters on the overlay, so this foundation should be in place first.

## What Changes

- **Strips on every display:** the overlay gets a transparent, click-through strip at the bottom of **every connected display**, not only the main one. Each strip keeps all the guarantees from `overlay-window`: transparent, click-through outside regions, all Spaces, above fullscreen, no focus stealing.
- **One walkway:** the strips form a single **walkway** in points, ordered by the displays' left-to-right arrangement. Content lives on the walkway, not in one window. A buddy that crosses from one display to the next is drawn on both screens during the crossing, so it really walks over.
- **Home display:** buddies have a home display, which is where they gather. When the home display changes, they walk there along the walkway, faster than their normal stroll. When two displays are not side by side, the buddy walks off one display's edge and in at the facing edge of the other.
- **Screen choice in the menu:** a new **"Screen"** submenu in the menu bar offers "Automatic (follow the mouse)" and each connected display by name. The choice is saved. In automatic mode the home display follows the display under the mouse pointer, after the pointer has stayed there for a moment, so the buddies do not run back and forth.
- **Disconnected displays:** a display that is disconnected is removed from the walkway. Buddies on it reappear at the nearest remaining display. A chosen display that is missing falls back to the main display until it returns.
- **Demo and debug tools:** the debug monster, the debug outlines and the debug session panel follow the new model. The monster walks to the home display, the outlines show every strip, and the panel sits on the home display.

### Out of scope

- Several buddies per session and moods (`session-avatars`). This change only moves the existing debug monster.
- Strips anywhere but the bottom edge of a display, or a walkway that follows vertical display arrangements. The order is left to right; for displays stacked vertically, the buddy walks off at one edge and in at the other.
- A per-buddy display choice. All buddies share one home display.
- Mirrored displays (they count as one display).

## Capabilities

### New Capabilities

- `multi-display`: buddies across several displays. Covers the walkway made of all display strips, the home display (chosen or automatic), walking between displays instead of jumping, and what happens when displays are connected or disconnected.

### Modified Capabilities

- `overlay-window`: "Bottom strip placement" changes from the main display only to a strip on every connected display. "Debug region view" outlines every strip.
- `menu-bar-control`: the app menu gains the "Screen" submenu, and the screen choice joins the persisted settings.

## Impact

- **Changed code:**
  - `OverlayController` (one window per display, a walkway coordinate space, regions and pass-through per window, layout per display);
  - `Settings` (a `screen` key);
  - the menu bar script (the "Screen" submenu);
  - the debug monster, debug layer and session panel (walkway coordinates).
- **Native code:** `MacOverlay` gains display names and stable display IDs (`NSScreen.localizedName`, `NSScreenNumber`), and `configure_window` is called for every strip window.
- **Performance:** a transparent window per display costs rendering time. Strips with nothing on them stop rendering (measured in a spike).
- **Later changes:** `session-avatars` places avatars on the walkway instead of in the main window.
