# Proposal

## Why

A Wobbo whose session works for a long time stands on its spot and only switches from one work clip to the next. It looks stiff. A short walk now and then, like stretching its legs, makes it feel more alive while it is clearly still at work.

## What Changes

- While its session stays `working`, a Wobbo takes a short walk of about 3 seconds after every 2 to 4 ways of working (each 8 to 15 seconds, as now), and then picks up the next way of working.
- The walk starts only after the current prop has been put away, and it stays around the Wobbo's own spot, like its stroll when idle.
- When the session's state changes during the walk, the walk ends at once and the new state shows as usual.

### Out of scope

- Walks during `thinking` or `waiting`.
- A setting to turn the walks off or change how often they happen.
- New clips: the walk uses the existing `walk` clip.

## Capabilities

### New Capabilities
<!-- none -->

### Modified Capabilities
- `session-avatars`: "Behaviour follows session state" adds the short walks between ways of working.

## Impact

- `godot/scripts/core/avatar_mood.gd`: a walk break between work stints.
- `godot/tests/test_avatar_mood.gd`: tests for the break and its timing.
