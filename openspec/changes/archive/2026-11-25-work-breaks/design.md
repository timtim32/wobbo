# Design: work-breaks

## Context

`AvatarMood` (`godot/scripts/core/avatar_mood.gd`) is pure: it gets the state and the clock and returns `{clip, motion}`. While `working`, `_work()` picks a way of working (`_pick_work`), plays `_in`, the loop for 8 to 15 s, `_out`, and picks the next one. `motion` is `stand` throughout. The avatar already knows the `stroll` motion: walking to and fro within its slot's stroll range.

Godot 4.7, macOS; no platform APIs are involved.

## Goals / Non-Goals

**Goals:** a short break that reads as part of working, with the existing clips and motions; fully unit tested in `test_avatar_mood.gd`.

**Non-Goals:** breaks in other states; tuning by the user.

## Decisions

### D1. A break between stints, counted in stints
`_pick_work()` counts stints. When the next way of working would start and the count has reached `_break_after` (2 to 4, drawn again after each break), the mood starts a break instead: `{clip: &"walk", motion: &"stroll"}` until `_break_until` (`BREAK_MS = 3000`, randomised ±500 ms). Then it picks the next way of working and resets the count. The very first stint after the state becomes `working` never starts with a break.
- *Alternative:* a break after a fixed time (every 40 s). Counting stints puts the break exactly where a prop has just been put away, so no prop is ever visible during the walk.

### D2. Leaving the break
Any state other than `working` drops the break at once (like `_drop_work`), as does walking in, travelling or leaving. A break never starts while a prop is out: it only starts where `_pick_work` would run.

## Risks / Trade-offs

- [The stroll may leave the Wobbo off-centre in its slot when work resumes] → The stroll stays within its own slot's range, as when idle; working there looks the same.
- [Existing tests assume back-to-back switches] → They run fewer than 2 stints or are updated to expect the break.
