# Proposal

## Why

Each project folder gets a fixed Wobbo colour from a hash of its name. That is good, but the user cannot change it. Some colours come up much more often than others, and blue, indigo and teal look alike. The user's two main projects (wobbo and iris-mobile) both come out blue-ish. The user wants to keep a fixed colour per folder and be able to choose that colour.

## What Changes

- The context menu of a Wobbo (right click) gets a "Colour" submenu. It lists the 8 Wobbo colours by name, with a check mark on the current one, plus "Automatic".
- Choosing a colour gives every Wobbo of that project folder that colour, at once and from then on. Wobbo remembers the choice per folder, also after a restart.
- "Automatic" forgets the choice. The folder goes back to the colour Wobbo picks by itself (the hash, as today).
- A Wobbo of another folder that already wears the chosen colour (picked automatically) gets the colour the chosen one had. The two swap.
- Wobbos picked automatically avoid colours the user chose for folders that are on screen.
- Wobbo's own buddy (the welcome) has no "Colour" submenu. It stays green.

### Out of scope

- A shared colour for a project and its worktrees. A worktree folder has its own name, so it has its own colour and its own choice.
- New colours or a free colour picker. The choice is one of the 8 existing colours.
- A list of chosen colours in the menu bar menu, or a way to reset all choices at once.
- Changing how the automatic colour is picked (the hash, and blue taking over from green).

## Capabilities

### New Capabilities
<!-- none -->

### Modified Capabilities
- `session-avatars`: "Recognisable per session" gets colours chosen per folder. "Looking and click reaction" gets the "Colour" submenu in the context menu.

## Impact

- `godot/scripts/core/avatar_cast.gd`: colour choice with chosen colours per folder, and the swap.
- `godot/scripts/core/settings_store.gd` and `godot/scripts/autoload/settings.gd`: a `[colours]` section, folder name → hue.
- `godot/scripts/avatars/avatar_manager.gd`: the "Colour" submenu, applying a choice to visible Wobbos.
- `godot/scripts/avatars/session_avatar.gd` and `balloon.gd`: changing the colour of a Wobbo that is already on screen.
- Tests: `godot/tests/test_avatar_cast.gd`, settings store tests.
