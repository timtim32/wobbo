# Tasks

## 1. Sizes

- [x] 1.1 Add `BuddySize` (design D2) with `height_of` and `items`, and the `buddy_size` setting (default `"normal"`). Verify: headless tests for the four heights, an unknown key giving Normal, exactly one checked item, and the settings default plus an old file without the key.
- [x] 1.2 Make the height a `Monster` property (`height_pt`, design D1), and pass it from `WalkwayBody` to every view, including mirrored ones (design D3). Verify: a monster test that `height_pt = 170` gives bounds about 170/110 times taller; existing tests stay green.
- [x] 1.3 Let `SessionAvatar` follow the setting, and scale its speeds (design D3). Verify: `game_eval` setting `buddy_size` to `xl` makes every avatar's `bounds_pt().size.y` about 170, its region and label follow, and a new fake session's buddy enters at 170 pt.

## 2. Menu

- [x] 2.1 Add the "Size" submenu (design D5). Verify: `game_eval` of the submenu items after rebuilding; choosing an item updates the setting and the check mark.
- [x] 2.2 Manual check: the user switches between the four sizes in the real menu bar with a few buddies on screen. The buddies resize at once and stay sharp at Small and Extra large on both displays, their labels and right-click menus still work, and after a restart the size is kept.

## 3. Documentation and integration

- [x] 3.1 Update `README.md` ("The buddies") with the "Size" menu item. Verify: the README describes it.
- [x] 3.2 Walk through every scenario in this change's specs by test or by hand, and tick them off in a short checklist in the PR description.

## Workflow follow-up

- After review and merge: archive with `openspec archive buddy-size`.
