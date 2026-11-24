# Design: edges-first-slots

## Context

`AvatarCast` (`godot/scripts/core/avatar_cast.gd`, session-avatars design D2) splits the home display's segment into `slot_count` equal slots (at most 5) and places a buddy at `slot_center`, strolling within `stroll_range` of it. `plan` gives each newcomer the first free slot in `slot_order(count)`, which today runs from the centre outwards (5 -> 2, 1, 3, 0, 4). `SessionAvatar._slot_x` only reads the slot index it was given; `AvatarManager` passes the slot count and the plan's actions through. See proposal.md for why the order changes.

No macOS-specific API is involved; this is pure GDScript in Godot 4.7.

## Goals / Non-Goals

**Goals:**
- New buddies fill slots from the edges inward, left edge first.
- Keep everything that makes slots stable: fixed slot indices, no re-spreading, no overlap.

**Non-Goals:**
- Any change to slot geometry (`slot_center`, `stroll_range`, `slot_count`) or to ranking and eviction.

## Decisions

### D1. Change only `slot_order`
`slot_order(count)` returns the slot indices alternating from the outside in, starting left: `0, count-1, 1, count-2, ...`. For 5: `[0, 4, 1, 3, 2]`; 4: `[0, 3, 1, 2]`; 3: `[0, 2, 1]`; 2: `[0, 1]`; 1: `[0]`.

`plan` already builds its free list in `slot_order` order, so a newcomer takes the free slot nearest an edge, and a gap left by a departing buddy is refilled first if it is the outermost free one. Nothing else changes.

*Alternative:* move the outer spots closer to the edge (a fixed inset, spots spread evenly between the two outer ones). The user chose to keep the equal spots, so the outer spot stays half a slot (about 151 pt on a 1512 pt display) from the edge; strolling still reaches to about 8 pt from it.

*Alternative:* re-spread all spots by the number of buddies (1 buddy at the left edge, 2 at both edges, 3 at edges plus middle, ...). Rejected for the same reason as in session-avatars D2: every arrival would make everyone shuffle.

### D2. Entering and leaving stay as they are
A buddy enters from the walkway end nearest to its slot and leaves at the end nearest to where it stands (session-avatars D2). With edge slots filled first, the first buddy walks in from the left, the second from the right, which matches the new layout without code changes.

## Risks / Trade-offs

- [Narrow displays: when the slot count drops (e.g. 5 -> 2), buddies whose slot index no longer exists walk off, as today. With edges-first, the right-edge buddy (slot 4) is one of them, while slot 1 becomes the new right edge.] → Accepted: that is the existing "unless the spots no longer fit" case and it is rare (a display narrower than 5 × (body width + 16 pt)). The walked-off buddy comes back into the next free slot by the new order.
- [Uneven look with gaps: after buddies leave, the remaining ones may sit lopsided (e.g. only slot 1 and 4 taken).] → Accepted: stable spots matter more (spec "Sharing the strip"); the next newcomer fills the outermost gap.
- [Dock interplay with `dock-dodge`: the Dock usually sits mid-screen.] → Edges-first keeps few buddies off the Dock, so it only reduces how often they hop up.
