# Tasks

## 1. Remembering colours

- [x] 1.1 `SettingsStore`: `[colours]` section (name → hue) with `get_colour`, `colours`, `set_colour` (a negative hue forgets the choice); load drops values that are not a float in `AvatarCast.HUES`; save writes the section (D2). Verify: new cases in `godot/tests/test_settings_store.gd` (round trip, bad value dropped, missing section) pass.
- [x] 1.2 `Settings` autoload: wrappers that save and emit `changed(&"colours", name)`. Verify: the test suite passes (`godot/tests/run_tests.gd`).
- [x] 1.3 Manual check: set a colour through the debugger or a test hook, quit Wobbo, open the settings file, and see the `[colours]` entry.

## 2. Hue rule

- [x] 2.1 `AvatarCast`: `HUE_NAMES` in `HUES` order; `plan()` takes `chosen` and uses it for newcomers; automatic picks avoid chosen hues of live sessions (D3). Verify: `test_avatar_cast.gd` cases "chosen colour wins even when taken", "automatic avoids a chosen colour", "own buddy stays green".
- [x] 2.2 `AvatarCast.recolour()`: all avatars of the folder, the swap, "Automatic", leaving avatars skipped (D3). Verify: `test_avatar_cast.gd` cases for each of these.
- [x] 2.3 Manual check: run the test suite headless and see all tests pass.

## 3. Recolouring on screen

- [x] 3.1 `SessionAvatar.set_hue()` and `Balloon.set_hue()`: body and balloon name colour change at once (D4). Verify: `test_balloon.gd` case for the accent after `set_hue`.
- [x] 3.2 `AvatarManager`: pass `Settings` choices to `plan()`; `set_colour(session_id, hue)` saves or clears and applies `recolour()` (D4). Verify: with two debug sessions, calling `set_colour` from the debugger recolours them as in the spec.
- [x] 3.3 Manual check: with a balloon open on a Wobbo, change its colour; the body and the name in the balloon change together.

## 4. Context menu

- [x] 4.1 Spike S1: a coloured dot icon on a `NativeMenu` popup submenu item on macOS. Keep it if it shows, otherwise names only (D5).
- [x] 4.2 `build_menu()`: "Colour" submenu with the 8 names and "Automatic", check mark on the current choice, not on the own buddy; free the submenu on close (D5). Verify: right-click a Wobbo and see the submenu with the check on "Automatic".
- [x] 4.3 Manual check, in the app: choose Red on a Wobbo (turns red at once); choose Red where another Wobbo is red (they swap); quit and restart (a new session of that folder comes in red); choose Automatic (check mark back on "Automatic"); right-click the own green buddy (no "Colour"); press Escape in the menu (nothing changes, focus stays in the terminal).

## 5. Docs

- [x] 5.1 README: one line in the user section on changing a Wobbo's colour with a right click. Verify: the line is in `README.md`.
