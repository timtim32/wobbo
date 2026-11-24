# Design: session-avatars

## Context

What exists after `multi-display` (Godot 4.7.2, macOS, GL Compatibility, `max_fps` 30):

- **`Bridge` autoload:**
  - Owns a `SessionRegistry` with `Session` objects (`id`, `agent`, `name`, `state`, `updated_msec`, `pending`).
  - Emits `session_added`, `session_changed` and `session_removed`.
  - Ended sessions stay 5 s (`ENDED_LINGER_MS`), and silent sessions are removed after 30 min.
  - States are `idle`, `thinking`, `working`, `waiting`, `done`, `error` and `ended`.
- **`WalkwayBody`** (`scripts/walkway/walkway_body.gd`): a model in walkway points (feet `position`, `facing`, `hue`, `look_target`, clip) with a `Monster` view in every strip window it overlaps. Secondary views mirror the primary one.
- **`Overlay` API:**
  - `walkway` (segments, `direction_to`, `fully_on`, `index_at`) and `home_index()`;
  - `strip_stage(i)` / `strip_ui(i)`, `walkway_to_local`;
  - `set_region` / `remove_region` in walkway points;
  - `region_input(id, event, point)`, `layout_changed`, `home_changed`, `content_visibility_changed`.
- **`DebugBlob`** extends `WalkwayBody`: it strolls on the home display, travels at 180 pt/s when the home display changes, follows the most recent session's state, looks at the pointer, and reacts to clicks. It is the prototype for the avatar and gets removed here.
- **`Monster`:**
  - Looping clips: `idle`, `walk`, `sleep`, `thinking`, `working`, `waiting`.
  - One-shot clips: `wave`, `happy`, `error`, which return to `idle` and emit `clip_finished`.
  - It is about 110 pt tall. `hue` shifts the skin, and facing flips the skeleton.
- **CPU (from `character-rig`):** about 4.5% for one walking monster and about +0.2 points for each extra one. The idle overlay with nothing moving still renders at 30 fps.

## Goals / Non-Goals

**Goals:**
- All decisions about which sessions get an avatar, where they stand, which colour they get and what they do live in pure, headless-tested code. Nodes only apply the decisions.
- An avatar is a `WalkwayBody`, so crossing displays, mirroring views and regions keep working unchanged.
- Fake sessions for manual checks come from a script, not from real agents.

**Non-Goals:**
- Balloons, speech and answering requests at the avatar (`balloons-and-speech`).
- Window focus, drag and the right-click menu (`avatar-interactions`).
- Avoiding overlap while avatars travel between displays or walk in and out. Only standing and strolling avatars keep apart.

## Decisions

### D1. Avatar manager and a pure cast
An `Avatars` node (`scripts/avatars/avatar_manager.gd`) under `Content` replaces `DebugBlob`. It listens to the `Bridge` signals and also re-evaluates every 0.5 s, because sleep timers and ranking depend on time.

The pure `AvatarCast` (`scripts/core/avatar_cast.gd`) answers one question: given the sessions (`id`, `name`, `state`, `updated_msec`) and the avatars on screen (`id`, `slot`, `hue`, `leaving`), what should change? It returns a list of actions:
- `enter(id, slot, hue)`;
- `leave(id, wave: bool)`.

It chooses as follows:
- **On screen:** sessions that are not `ended`, ranked by `updated_msec`, top 5 (`MAX_AVATARS`).
- **Ended sessions:** an ended session with an avatar gets `leave(wave=true)`. A removed session with an avatar gets `leave(wave=false)`.
- **Swapping:** a session pushed out of the top 5 gets `leave(wave=false)`. Its slot is free only after that avatar has walked off. Until then the new avatar waits, which is at most a few seconds.
- **Hysteresis:** a session only displaces another when its `updated_msec` is at least 2 s newer than the one it pushes out. Two sessions that alternate quickly then do not swap avatars back and forth.

*Alternative:* let each avatar node decide for itself. Rejected, because eviction and slots need a view of all avatars at once.

### D2. Fixed slots on the home display
The home display's segment is divided into 5 equal slots. Avatars fill them from the centre outwards, in the order slot 2, 1, 3, 0, 4.
- An avatar keeps its slot index while others come and go (spec "Sharing the strip"), and also when the home display changes: it takes the same index on the new display.
- **Strolling:** an avatar strolls within its slot, `slot_center ± (slot_width/2 − half_width − 8 pt)`, so neighbours never overlap.
- **Narrow displays:** on a display narrower than 5 × (body width + 16 pt), only as many slots as fit are used. That is the "unless the spots no longer fit" case. The cast is given the slot count, so the limit drops on narrow displays.
- **Entering and leaving:** an avatar enters from the end of the walkway nearest to its slot, and leaves at the end nearest to where it stands. An end of the walkway is an outer edge with no display beyond it. It starts with its body just beyond that end, and walks across any display in between, so it never appears or vanishes in the middle of a screen. Changed after the user's check 2.6: entering and leaving at the home segment's own edge made avatars pop up and vanish halfway onto the neighbouring display.

*Alternative:* re-spread all spots whenever the count changes, so one avatar stands in the middle and two stand at thirds. That looks nicer with few avatars, but every arrival makes everyone shuffle. Rejected for stable spots.

### D3. Behaviour as a pure mood machine
`AvatarMood` (`scripts/core/avatar_mood.gd`) is a small state machine per avatar. Times are passed in explicitly, as in `HomeDisplay`.

**Inputs:**
- the session state and the time it last changed;
- the time of the last activity (`updated_msec`);
- the phase: `entering`, `at_home`, `travelling` or `leaving`;
- "one-shot finished";
- clicks.

**Output:** `{clip, motion}`, where `motion` is `stand`, `stroll`, `walk_to(x)` or `walk_off`.

| Session state | At home | Notes |
|---|---|---|
| `thinking` / `working` / `waiting` | that clip, stand | never sleeps |
| `done` | `happy` once, then `walk`/`idle` stroll | sleeps after 120 s without activity |
| `error` | `error` once, then stroll | sleeps after 120 s |
| `idle` | stroll (`walk`, with short `idle` pauses like `DebugBlob`) | sleeps after 120 s |
| (asleep) | `sleep`, stand | wakes on any new activity |
| `ended` | `wave` once, then `walk_off` | |

**Other rules:**
- **While moving:** during `entering`, `travelling` and `leaving` the clip is `walk` and the state is not applied. On arrival the mood takes on the current state; a `done` or `error` reaction is still played once if it happened during the walk.
- **Clicks:** a click plays `happy` once and then returns to the state behaviour. It does not play while asleep; it wakes the avatar instead (`happy`, then the state).
- **Stroll pause:** a strolling avatar stops for `idle` now and then (2–6 s every 8–15 s, randomised per avatar), so five avatars do not move in lockstep.

### D4. `SessionAvatar` node
`scripts/avatars/session_avatar.gd` extends `WalkwayBody`. It owns:
- an `AvatarMood`;
- its slot;
- its session id;
- a region id `avatar:<session_id>`, the same as `DebugBlob`'s (`rect_pt().grow(4)`).

**Each frame:**
- It asks the mood for `{clip, motion}`, moves `position.x` (60 pt/s stroll, 90 pt/s walking in and out, 180 pt/s travel as in `DebugBlob`), and plays the clip.
- It sets `look_target` to the mouse pointer.
- When the home display changes, `direction_to(home)` decides travel, as in `DebugBlob`, and afterwards the avatar walks to its slot on the new display.
- **Leaving:** when it has walked fully off the segment, it emits `gone` and the manager frees it.

### D5. Name label per view
The label is drawn per strip window, like the monster.
- `WalkwayBody` gets a small hook: `_view_created(i, view)` and `_view_freed(i)`. `SessionAvatar` uses it to add a label to the same strip stage. The label is a sibling, not a child, because the facing flip would mirror a child's text. It is placed every frame from the view's position.
- **Label style:**
  - a `Label` with the system font at 12 pt, white text on a rounded, semi-transparent dark pill (a `StyleBoxFlat`), so it is readable on light and dark wallpapers;
  - at most 140 pt wide, ending in "…" when longer;
  - centred 6 pt above the monster's head.
- **Overlap:** with 5 slots on the smallest built-in display, a slot is at least about 290 pt wide (1512 / 5), so 140 pt labels never overlap. Labels on narrow displays follow the reduced slot count (D2).
- **Clicks:** labels are not interactive and stay click-through.
- **Show Names:** a persisted setting `show_names` (default true), toggled by a "Show Names" check item in the menu, which the user asked for during check 3.3. Each label's visibility is `content_visible and show_names`, and every avatar updates its labels on `Settings.changed`.
- Balloons in `balloons-and-speech` will stack above the label.

### D6. Colours from a curated list
`AvatarCast` also assigns hues. `HUES` is a short curated list (about 8) chosen with the preview. The original green (97.6) comes first, and hues that turn murky (yellow-ish, `character-rig` risk) are left out.
- **Preferred hue:** derived from a stable hash of the session's display name, so a project tends to keep its colour across sessions and restarts.
- **Collisions:** if another avatar on screen has that hue, the next free hue in the list is used.
- **Stability:** a hue is fixed when the avatar enters and kept until it leaves.

**Spike S2:** choose the list in `monster_preview` (all candidates side by side at real size, on a light and a dark wallpaper) and check it with the user. **Fallback:** if fewer than 5 hues stay readable, add a lightness or saturation shift to the skin shader to get 5 distinct colours.
- **Result S2 (task 3.2, 2026-11-23):** passed without the fallback. Ten candidates were shown side by side at real size in `hue_preview.tscn`, over a dark app and a white web page. The user agreed to 8 hues, in this order:
  - 97.6 green (the original)
  - 205 blue
  - 265 purple
  - 330 pink
  - 180 turquoise
  - 355 red
  - 235 indigo
  - 25 brown-orange

  150 was left out because it is too close to the green, and 295 because it is too close to the purple. Yellow was not a candidate, because of the `character-rig` risk that the spots lose contrast there.

### D7. Clicks and the debug text field
`Avatars` listens to `Overlay.region_input` and routes `avatar:<id>` regions to the right avatar.
- **Left click:** passed to the mood (D3).
- **Right click in debug mode:** the manager emits `avatar_right_clicked(avatar)`, and `main.gd` opens the debug text field at that avatar. `open_at` already takes any walkway body.
- **Focus:** clicks never request focus, as in `overlay-window`.

### D8. Quiet frame rate
A small `QuietFps` node under `Main` decides every frame, using the pure `QuietMode.is_quiet` (`scripts/core/quiet_mode.gd`). It lives outside `Content`, because `Content` stops processing while the buddies are hidden.

The app is quiet when:
- no avatar is on screen;
- every avatar on screen is asleep; or
- the buddies are hidden.

It is never quiet when:
- the debug text field is open;
- debug mode is on, because the panel is used interactively;
- the mouse pointer is over a strip.

Correction during task 4.2: this section first said the app is "never quiet" while the buddies are hidden. That was backwards, because nothing is drawn then.

When quiet, `Engine.max_fps` drops from 30 to `QUIET_FPS`. It goes back to 30 immediately when:
- an avatar enters or wakes;
- a click arrives;
- the mouse pointer enters a strip rect, checked each frame (cheap, and latency ≤ 1/`QUIET_FPS` s).

Bridge messages are polled in `_process`, so they also arrive within 1/`QUIET_FPS` s. That is fine for the 1 s wake-up in the spec.

**Spike S1:**
- Measure CPU standalone (`top`, as in earlier spikes) for: no avatars at 30 fps, no avatars at 5 and 10 fps, and five sleeping avatars at 5 and 10 fps.
- Check that the sleep breathing still looks smooth enough at the chosen rate.
- Pick `QUIET_FPS` (expected 5 or 10).

**Fallback:** if a low `max_fps` still costs much, for example because the transparent windows are composited every frame anyway, try `OS.low_processor_usage_mode` while quiet. As a last resort, hide strip windows without avatars, as `multi-display` D10 already does for non-root windows.
- **Result S1 (task 4.3, 2026-11-23, standalone, `top` average over 8 s, M5 Pro, built-in display only because the LG was disconnected at the time):**

  | Case | CPU |
  |---|---|
  | No avatars, 30 fps (as before this change) | 5.2% |
  | No avatars, 10 fps | 2.0% |
  | No avatars, 5 fps | 1.2% |
  | 5 strolling avatars, 30 fps | 8.0% |
  | 5 sleeping avatars, 5 fps | 1.4% |
  | 5 sleeping avatars, 10 fps | 2.9% |

  - The quiet mode works without the fallback.
  - The user found the sleep breathing too choppy at 5 fps, so `QUIET_FPS` is **10**. That still saves about 45–60% against 30 fps.
  - The measurements use a separate `HOME`, so the measuring Claude Code session gets no avatar of its own. The `--quiet-fps=N` start argument makes the rate adjustable.

### D9. Removing the debug monster
- `DebugBlob` is deleted.
- `main.tscn` gets the `Avatars` node instead.
- `main.gd` removes the blob region on hide through the manager, which removes all avatar regions.
- The debug panel and debug layer stay.
- `monster_preview` stays as a developer tool.

### D10. Fake sessions for checks
`bridge/scripts/fake_sessions.ts` (Bun, no dependencies, like `demo_client.ts`) connects as `mcp` clients and drives several fake sessions from short commands, for example:
- `add website`;
- `state website working`;
- `ask website`;
- `end website`;
- `add-many 6`.

The manual checks use it, so they do not need several real Claude Code sessions. Each fake session has its own connection and project directory, so the registry sees separate sessions.

### D11. Demo from the menu
The user asked for an easy way to show the buddies. A "Play Demo" item in the menu bar starts a `DemoPlayer` node (`scripts/avatars/demo_player.gd`). It plays a fixed timeline of about 90 s with five pretend sessions (project names like "website", "api", "docs", "mobile-app", "data-pipeline"):
- they walk in;
- each shows thinking, working, and waiting (a pretend question that also shows in the debug panel);
- one gets a happy reaction and one an error;
- a sixth session pushes out the quietest;
- one waves goodbye;
- all end.

**Injection:** pretend sessions go through the same code as real ones. `BridgeServer` gets two public methods:
- `local_event(session_info, kind, data)` applies an event to the registry and emits the same signals as a received `event`;
- `local_request(session_id, id, text, choices)` adds a request whose `owner` is -1, so an answer is simply dropped (`_send` ignores unknown connections).

Pretend sessions use the agent name `demo` and ids `demo:<name>`, so they never collide with real ones.

**Timeline:** a pure array of steps `{at_sec, name, action, arg}` in the player, with a test that the steps are in time order and that every pretend session ends. "Stop Demo" (or the end of the timeline) sends `session_end` for every pretend session still active and removes their requests. The player emits `running_changed(bool)`, which the menu uses to switch between "Play Demo" and "Stop Demo".

### Godot and macOS assumptions
- Godot 4.7: `Engine.max_fps` can be changed at runtime and takes effect on the next frame, including for extra `Window` nodes (spike S1).
- Godot 4.7: `Label` with `text_overrun_behavior = OVERRUN_TRIM_ELLIPSIS` and a `StyleBoxFlat` renders sharply in each strip window at the max-scale pixel space (as found for the monster in `multi-display` S3).
- macOS: the system font through Godot's `SystemFont` (`.AppleSystemUIFont`); otherwise Godot's default font.

## Risks / Trade-offs

- [Entering and leaving at the end of the walkway can mean crossing a whole other display first, for example about 17 s across the LG at 180 pt/s] → Accepted for now, because the user prefers it to popping up at a seam. The speed can be raised for the part off the home display if it feels slow.
- [The ranking by `updated_msec` can evict a session that is waiting for the user, if five other sessions are busier] → A waiting session asks for attention, so `AvatarCast` ranks `waiting` sessions first and never evicts them. A test covers this.
- [Five avatars plus labels cost CPU] → About +0.2 points per monster (`character-rig`). Sleeping avatars drop to the quiet frame rate (S1).
- [Avatars overlap while travelling or entering] → Accepted: these are short walks, and the spec only requires separation while standing or strolling.
- [The labels use the system font through `SystemFont`, which might not resolve] → Falls back to Godot's default font, which is less pretty but readable.
- [Hysteresis (2 s) delays a swap] → Fine: avatars walk in and out over a few seconds anyway.
