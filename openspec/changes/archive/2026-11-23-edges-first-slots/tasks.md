# Tasks

## 1. Fill order

- [x] 1.1 Change `AvatarCast.slot_order` to edges-first (design D1) and update its doc comment. Verify: `test_avatar_cast.gd` asserts the order for 1 to 5 slots (`[0]`, `[0, 1]`, `[0, 2, 1]`, `[0, 3, 1, 2]`, `[0, 4, 1, 3, 2]`).
- [x] 1.2 Update the `plan` tests that expected the centre slot first, and add a test that plans 1 to 5 sessions arriving one by one on 5 slots and checks the slots taken (0, 4, 1, 3, 2), plus the "gap stays until filled" scenario. Verify: the headless suite passes: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path godot --script res://tests/run_tests.gd`.
- [x] 1.3 Check in the running app: start the project from the editor, add fake sessions one by one with `game_eval`, and read each avatar's slot and x position. Verify: 1 buddy stands on the left, 2 on both edges, 5 in the order left, right, inward, without overlapping.
- [x] 1.4 Manual check: the user watches buddies arrive one by one in the running app and sees the first ones stand near the edges and later ones fill inward.

## Workflow follow-up

- After review and merge: archive with `openspec archive edges-first-slots`.
