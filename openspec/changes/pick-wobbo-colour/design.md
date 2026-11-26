# Design

## Context

- `AvatarCast.plan()` (`godot/scripts/core/avatar_cast.gd`) is pure. For each newcomer it picks a hue with `pick_hue(name, taken)`, where `name` is the session's display name (the project folder's base name, `SessionRegistry.display_name`). Wobbo's own buddy (`wobbo:` id) always gets `OWN_HUE`.
- The avatar's colour lives in `hue` on the body (a Monster with a hue-shift shader). The `hue` setter already re-applies the shader, so a visible Wobbo can change colour at runtime.
- The balloon reads the hue once in `Balloon.setup()` and turns it into `_accent` (the name colour).
- The right-click menu is a `NativeMenu` popup built in `AvatarManager.build_menu()`. Today it holds only "Send home".
- Settings are a `ConfigFile` with one section `[settings]` and fixed, typed keys (`SettingsStore.DEFAULTS`).

## Goals / Non-Goals

**Goals:**
- A pure, unit-tested rule for "which hue does this session get", with chosen colours.
- Recolouring a visible Wobbo without it leaving and walking in again.

**Non-Goals:**
- Animating the colour change (a fade). The colour changes at once.
- Changing `HUES` or `pick_hue` for folders without a choice.

## Decisions

### D1. Key: the display name (folder base name)
The choice is stored under the session's display name, the same string `pick_hue` hashes. Worktrees therefore have their own choice (out of scope in the proposal). Alternative: the full `project_dir` path. Rejected: the hash uses the name, two checkouts of one repo would differ, and moving a folder would lose the choice.

### D2. Storage: a `[colours]` section in the settings file
`SettingsStore` gets a second section, `colours`, a free map of name → hue (float). It is read in `load_file()` and written in `save_file()`. On load, a value that is not a float or not in `AvatarCast.HUES` is dropped. Accessors: `get_colour(name) -> float` (-1 when none), `set_colour(name, hue)`, `clear_colour(name)`. The `Settings` autoload wraps them, saves, and emits `changed(&"colours", name)`. Alternative: one `settings` key holding a Dictionary. Rejected: `DEFAULTS` types every key and a dictionary of user data does not fit that list. A separate section also keeps the file readable.

### D3. Hue rule in `AvatarCast`
- `plan(sessions, avatars, slots, chosen := {})` with `chosen`: name → hue. For a newcomer: own buddy → `OWN_HUE`; name in `chosen` → that hue (even when taken); otherwise `pick_hue(name, taken + chosen hues of live sessions)`.
- New pure function `recolour(avatars, sessions, name, hue) -> Array[{id, hue}]`. It returns every visible avatar of folder `name` with `hue` (or, for `hue < 0`, the automatic one: `pick_hue` against the other avatars' hues), plus a swap: an avatar of another folder without a choice that wears the new hue gets the old hue of the first recoloured avatar. Leaving avatars are skipped.
Alternative: let `plan()` find and fix colour differences on every tick. Rejected: `plan()` only decides enter and leave, and an avatar "keeps its colour while on screen". A recolour happens only when the user asks, so a separate call keeps the change contained.

### D4. Applying a recolour
`AvatarManager.set_colour(session_id, hue)` saves the choice for the session's name (or clears it), calls `AvatarCast.recolour` and sets `hue` on each returned avatar. `SessionAvatar.set_hue(h)` sets the body hue and, when a balloon exists, updates its accent (`Balloon.set_hue(h)`, which re-styles the name label).

### D5. The submenu
`build_menu()` adds, before "Send home" and only when the session id does not start with `OWN_PREFIX`, a `NativeMenu` submenu "Colour" with 8 radio-check items (names from a new `AvatarCast.HUE_NAMES`, in `HUES` order) and, after a separator, "Automatic". The check mark goes on the chosen hue, or on "Automatic". The submenu is created with `NativeMenu.create_menu()` and freed in the same close callback as the main menu.

**Spike S1 (unproven):** a small coloured dot as the icon of each item (`NativeMenu.set_item_icon` with a 12×12 `ImageTexture`) in a popup submenu on macOS. Fallback: names only.

**Godot / macOS:** `NativeMenu` with `FEATURE_POPUP_MENU` and submenus (`add_submenu_item`) is the macOS NSMenu path in Godot 4.7. The menu already relies on it.

## Risks / Trade-offs

- [Two folders get the same chosen colour] → Allowed: it is the user's choice. Both avatars show it.
- [A worktree does not get the colour of its main project] → Out of scope; the user can choose a colour for the worktree too. A later change can map worktrees to their project.
- [The settings file grows with every folder that ever got a choice] → Only folders the user picked a colour for are stored; that stays small.
- [Settings write while the menu is open] → The write happens after the item is chosen, when the popup is closing; it is a small file.

## Migration Plan

None. A settings file without `[colours]` means no choices. Older Wobbo versions ignore the extra section.
