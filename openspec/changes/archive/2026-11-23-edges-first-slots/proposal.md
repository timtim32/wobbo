# Proposal: edges-first-slots

## Why

Today the first buddy stands in the middle of the home display, and later buddies spread outward. The middle of the screen is where the user works (and where the Dock sits), so a lone buddy is in the way. The user wants it the other way round: the first buddies stand near the screen edges, and only when there are more buddies do they come further inward.

## What Changes

- **Fill order from the edges inward:** a new buddy takes the free spot nearest to an edge, starting on the left: 1st buddy on the left edge, 2nd on the right edge, then alternating inward from left and right. With 5 spots the order is 0, 4, 1, 3, 2 (left to right numbering), so the middle spot fills last.
- **Spots themselves stay as they are:** the home display is still split into equal spots (up to 5), each buddy standing at the centre of its own. On a 1512 pt wide laptop display with 5 spots, the outermost spot is about 151 pt from the edge, and its buddy can stroll to about 8 pt from the edge.
- **Unchanged rules:** buddies never overlap, a buddy keeps its spot while others come and go, and on a display too narrow for 5 spots only as many spots as fit are used.

### Out of scope

- Moving the outer spots closer to the edge or changing the spacing between spots (the user chose to keep the equal spots).
- Re-spreading buddies when one leaves (a buddy keeps its spot, so a gap can stay until a new buddy fills it).
- Which buddies get a spot when there are more than 5 sessions (ranking and eviction stay as they are).
- Spots on displays other than the home display.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `session-avatars`: "Sharing the strip" states that buddies take spots from the edges inward, with scenarios for 1, 2 and 5 buddies.

## Impact

- **`AvatarCast`** (`godot/scripts/core/avatar_cast.gd`): `slot_order` returns edges-first indices; `plan` already hands out free slots in that order. `slot_center`, `stroll_range` and `slot_count` stay unchanged.
- **Tests:** `godot/tests/test_avatar_cast.gd` covers the order and the slots taken for 1 to 5 buddies; tests that expected the centre slot first are updated.
- **`SessionAvatar` / `AvatarManager`:** no code change. A buddy already enters from the walkway end nearest to its spot, which is now the near screen edge.
