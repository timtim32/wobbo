# Codebase audit

> **Historical snapshot.** This audit was written on 2026-11-23, before the
> project's history was restarted for its public release, so the commits it names
> (such as `3f03baf`) are not in this repository. Its findings were worked off in
> the archived OpenSpec change
> [`codebase-cleanup`](../openspec/changes/archive/2026-11-23-codebase-cleanup/proposal.md).
> The current review is [open-source-readiness.md](open-source-readiness.md).

Date: 2026-11-23. Scope: everything first-party in the repository at commit `3f03baf`, after
`dock-dodge`, `edges-first-slots`, `always-go-to-session` and `buddy-drag` were merged. Out of
scope: the vendored Godot addon `godot/addons/godot_ai/` and the `native/godot-cpp` submodule.

A first version of this audit was written at `11eb562`; it was re-checked against `3f03baf` and
updated (line numbers, sizes, the `OverlayController` recommendation and the sequencing).

No code was changed for this audit. The cleanup it proposes was planned in the OpenSpec change
`codebase-cleanup` (archived as `openspec/changes/archive/2026-11-23-codebase-cleanup/`).

## Status: cleanup done (2026-11-23)

The cleanup was merged in PR #13 (merge commit `ecb3d04`), one commit per task group. Line
numbers in the findings below refer to `3f03baf`, before the cleanup.

| Finding | Status | Commit |
|---|---|---|
| F01 `OverlayController` responsibilities | Done as planned: Dock tracking moved to `scripts/overlay/dock_tracker.gd` (831 → 752 lines); the rest stays together | `218bde3` |
| F02 session states as literals | Done | `1110c8c` |
| F03 normal height `110` in five places | Done | `1110c8c` |
| F04 ambiguous and stale design references | Done (GDScript, bridge, native, shader) | `94ff943` |
| F05 weak typing at boundaries | Done; `Walkway` has a `class_name`; values that may be freed stay untyped on purpose | `576ed98` |
| F06 dead code | Done, including three native spike methods; `find_app_of` kept | `2ee18c7` |
| F07 screen rects built several times | Done | `218bde3` |
| F08 anonymous tuple and open dictionaries | Done (`Connection` class, `_hover_strip` / `_hover_target`) | `12bf259`, `218bde3` |
| F09 `_session_info()` side effects | Done (`_resolve_session()`, `_attribute_mcp_connection()`) | `12bf259` |
| F10 two ways to read settings | Done (typed `Settings` properties) | `576ed98` |
| F11 bridge repetitions | Done, plus a version-match test | `9e337bc`, `94ff943` |
| F12 shadowing `Node.name` | Done (`run_tests.gd` was a false positive) | `12bf259` |
| F13 magic numbers | Done | `1110c8c` |
| F14 redundant reset in the view hand-over | Done | `12bf259` |
| F15 clip names in several lists | Done as a test, no shared registry | `b0e2ec4` |
| F16 three ways to reach sibling nodes | Left alone, as recommended | — |
| F17 tests write into the app data folder | Not a problem (corrected below) | `b0e2ec4` |
| F18 `_carry` with two meanings | Done (`_leftover_sec`) | `12bf259` |

After the cleanup: Godot headless tests 195 in 21 files, bridge `bun test` 31, all passing. The
eight manual checks of the change (tasks 1.5, 2.4, 3.4, 4.6, 5.4, 6.4, 7.4, 8.3) were not ticked
at archive time; the app was started on the cleanup branch and ran without errors.

Still open on purpose: splitting the rest of `OverlayController` (decide when a new feature adds a
responsibility to it), and F16.

Baseline at `3f03baf`:

- Godot headless tests: 192 tests in 21 files, 0 failed.
- Bridge: `bun test` 30 tests, 0 failed; `tsc --noEmit` clean. (The bridge did not change since
  the first version.)

## A. Executive summary

**Overall health: good.** The project is small (about 4,240 lines of app GDScript, 480 for the
character, 510 for asset tools, 710 lines of TypeScript, 520 lines of Objective-C++) and was
built feature by feature through OpenSpec, with a design and tests for every change. Files are
short, names are mostly clear, and comments explain *why* (macOS quirks, Godot workarounds)
rather than *what*. The four changes merged since the first version followed the same pattern:
new behaviour went into pure, tested helpers (`dock_watch.gd`, `dock_hop.gd`, `grab_gesture.gd`,
`swing_physics.gd`).

**Architecture: sound and right-sized.** Three autoloads (`Settings`, `Overlay`, `Bridge`), one
main scene, and a layer of pure, headless-tested helpers in `scripts/core/` that take plain data
and return decisions. Nodes do the side effects; helpers do the thinking. This is the best part
of the codebase and should be kept.

**Biggest maintainability issues:**

1. `OverlayController` (the `Overlay` autoload) grew from 659 to 831 lines. It now owns strip
   windows, coordinates, displays, the home display, Dock tracking (preferences, a `defaults read`
   parser, Accessibility permission, frame polling), headroom while a buddy is carried, regions and
   pass-through, mouse routing, keyboard focus and the native extension: eleven responsibilities in
   one file.
2. The same facts are written down in several places: session states as string literals next to
   `Protocol.STATE_*`, the "normal" buddy height `110` in five files, settings defaults repeated
   as call-site fallbacks, the bridge version in three files.
3. Comments that point to design decisions ("design D5") do not say which change's design they
   mean, and a few comments are out of date (a moved design path, the wrong units for regions).
4. Typing is weak where modules meet: the project uses `preload` constants instead of
   `class_name`, but rarely uses those constants as types, so sessions, segments, avatars and
   monster views travel as untyped variables.

**Biggest sources of unnecessary complexity:** small, not structural. An untyped two-element array
used as a tuple (`_hover`), connection dictionaries that gain keys at run time, a helper whose
name hides its side effects (`_session_info`), one field name used for two different things
(`_carry`), and a handful of unused functions left over from spikes.

**No P0 bugs were found.** Nothing in this audit changes behaviour.

**Verdict: targeted cleanup, not a major refactor.** About a dozen small, independent pull requests
remove most of the friction. The one structural item is moving Dock tracking out of
`OverlayController` into its own script; everything else in that file stays.

## B. Architecture overview

### Parts of the repository

| Part | What it is | Talks to |
|---|---|---|
| `godot/` | The app: a Godot 4.7 project (GDScript, GL Compatibility) | the bridge over a local WebSocket; macOS through `MacOverlay` |
| `native/` | `MacOverlay` GDExtension (Objective-C++): Spaces, window level, accessory app, focus, displays, Dock preferences and frame (Accessibility API), activating an agent's app | called only by `OverlayController`, `MenuBar` and `AvatarManager` |
| `bridge/` | `claude-buddy-bridge` (Bun + TypeScript): Claude Code hooks and an MCP server (`say`, `ask_user`) | the app, through `bridge.json` (port + token) and WebSocket |
| `bridge/plugin/` | The Claude Code plugin that runs the bridge | Claude Code |
| `art/` | SVG sources of the monster | exported by `godot/tools/export_monster.gd` |
| `openspec/` | Product context, specs, active and archived changes | — |

### The Godot app

```
Autoloads (project.godot)
  Settings  scripts/autoload/settings.gd            persisted settings, `changed` signal
  Overlay   scripts/autoload/overlay_controller.gd  strip windows, coordinates, regions, focus,
                                                    Dock tracking, headroom
  Bridge    scripts/autoload/bridge.gd → scripts/bridge/bridge_server.gd   WebSocket + SessionRegistry
  (_mcp_game_helper from the godot_ai addon: editor tooling; the addon's export plugin strips the autoload, and `exclude_filter` keeps its files out of the export)

scenes/main.tscn (Main, scripts/main.gd)
  Content/Avatars   AvatarManager   one SessionAvatar per shown session; clicks, grabs, drops
  UI/DebugTextField, UI/SessionPanel  debug-only UI, moved to the home display's window
  DebugLayer        outlines strips and regions in debug mode
  Demo              DemoPlayer: scripted pretend sessions
  QuietFps          10 fps when nothing moves, 60 fps while a buddy is carried
  MenuBar (+ Menu)  StatusIndicator with the app menu
```

**Coordinates.** Everything that moves works in *walkway points*: x runs along the bottom strips
of all displays, left to right; y is measured from the top of a strip. `Overlay` converts between
walkway points and each strip window's pixels (`walkway_to_local`, `local_to_walkway`). While a
buddy is carried, every strip window grows up to the top of its display ("headroom"); walkway y
then goes negative above the strip, and content keeps its place on screen.

**Content as model plus views.** `WalkwayBody` (`scripts/walkway/walkway_body.gd`) is one buddy in
walkway points, with a `tilt` around its feet. It instantiates a `Monster` view in every strip
window it overlaps; the view under its feet plays, the others mirror it. `SessionAvatar` extends
`WalkwayBody` and adds behaviour, movement, the Dock hop, carrying and name labels.

**Pure helpers (`scripts/core/`).** Each is a `RefCounted` with static functions or a little state,
no nodes, time passed in:

| Helper | Decides |
|---|---|
| `walkway.gd` | segment layout, x ↔ segment, remapping after a display change |
| `displays.gd` | matching macOS displays to Godot screens |
| `home_display.gd` | which display is home (setting or pointer dwell) |
| `region_registry.gd` | interactive regions, hit-testing, drag capture |
| `focus_tracker.gd` | reference-counted keyboard-focus requests |
| `session_registry.gd` | sessions, states, pending requests, MCP attribution |
| `avatar_cast.gd` | who is on screen, slot (edges first), colour, who leaves, the slot after a drop |
| `avatar_mood.gd` | which clip and motion an avatar plays |
| `dock_watch.gd`, `dock_hop.gd` | whether the Dock is shown (from its frame or the pointer); the hop |
| `grab_gesture.gd`, `swing_physics.gd` | click or grab; the swing, throw, fall and landing |
| `click_action.gd`, `focus_link.gd`, `quiet_mode.gd`, `buddy_size.gd`, `screen_menu.gd` | small rules |

**Communication.** Signals flow from the autoloads to content: `Bridge.session_*` and
`request_*`, `Overlay.layout_changed`, `home_changed`, `content_visibility_changed`,
`region_input`, `region_released`, `dock_changed`, `Settings.changed`. Content calls the autoloads
directly (`Overlay.set_region`, `Overlay.begin_headroom`, `Bridge.registry.get_session`). There is
no event bus and no dependency injection, and none is needed. Dependencies point one way:
content → autoloads → pure helpers. There are no circular script dependencies.

**Polling.** Several things poll on purpose: display layout once a second (macOS gives Godot no
display-change event), the pointer every frame (pass-through, home display, grabs), the Dock frame
every frame near a bottom edge and every 0.25 s otherwise, the cast every 0.5 s (time-based moods
such as "asleep 15 minutes"). Each is cheap and documented.

**Persistence.** `user://settings.cfg` (via `SettingsStore`) and `user://bridge.json`
(port, token, pid; mode 0600). Nothing else is saved; no save format to migrate.

**Character.** `characters/monster/monster.tscn` is a `Skeleton2D` rig whose parts and pivots come
from `assets/monster/manifest.json`. Clips are generated by `tools/build_monster_clips.gd` into
`clips/*.tres`. `Monster` is the only script with a `class_name`.

**Tests.** `godot/tests/run_tests.gd` runs every `test_*` method of `tests/test_*.gd` on a fresh
`base_test.gd` instance. Window and macOS behaviour is verified by hand, guided by each change's
tasks. The bridge uses `bun test` with a fake app.

## C. Findings

Severity: **High** = a real, recurring cost or risk; **Medium** = clear benefit to fix;
**Low** = small or local. Each finding is marked **Objective** (a factual defect: drift, dead
code, a misleading comment), **Recommended** (a judgement with a clear benefit) or
**Stylistic** (taste; fine to skip).

### F01 · High · Architecture · Recommended — `OverlayController` accumulates responsibilities

- **Where:** `godot/scripts/autoload/overlay_controller.gd` (831 lines).
- **What:** one autoload does eleven things: strip window lifecycle (`_sync_strips`,
  `_place_window`, `_update_strip_visibility`), coordinate conversion, display enumeration
  (`_displays`), home display (`_update_home`), Dock tracking (lines 231–332 plus nine state
  variables at 96–104: preferences, a `defaults read` parser, the Accessibility prompt, frame
  polling, the pointer fallback), headroom (519–621), regions and pass-through
  (`_update_passthrough`), mouse routing and focus restore after a click, keyboard focus, and the
  native setup. The header's hand-kept "Public API" list (lines 12–24) is already incomplete.
- **Why it matters:** to change one behaviour you read a file that does ten others. The Dock part
  is the clearest case: it is self-contained (it needs the display list, the walkway, the strip
  rects and `native`), yet a reader of window or click code has to skip past it, and its nine
  state variables sit between the window and focus state.
- **Recommendation:**
  1. Move Dock tracking into its own script, `scripts/overlay/dock_tracker.gd`: a plain
     `RefCounted` owned by the controller, holding the Dock state variables, `_read_dock_prefs`,
     `_update_dock`, `_pointer_near_bottom` and the lift computation. Its `update()` returns the
     strip the Dock is shown on, or -1, from what the controller passes in (displays, walkway,
     strip rects, delta); it does not reach back into the controller. The controller keeps the
     public API unchanged (`dock_lift_pt`, `dock_prefs`, `debug_force_dock`, signal
     `dock_changed`) as one-line delegations.
  2. Move the parsing half of `read_dock_prefs_cli()` into the pure `DockWatch` as
     `parse_defaults_output(text)` with a test; only `OS.execute` stays outside.
  3. Add one `_screen_rect_px(screen)` helper (see F07).
  4. Replace the "Public API" header with a short responsibility summary.
  Do **not** split the rest (windows, headroom, pass-through, mouse, focus). They all act on the
  same strip windows in a fixed frame order (`process_priority = 1000`), and splitting them would
  add indirection without making any of them easier to change.
- **Risk:** medium. The Dock code polls the native extension on a timer and depends on the
  display cache being fresh; the move must keep the order of calls in `_process`. Needs the manual
  Dock checks (autohide on and off, with and without Accessibility access, two displays).
- **Worth fixing:** yes. About 110 lines leave the controller, which goes to roughly 720 lines.

### F02 · Medium · Consistency · Objective — session states written as literals next to `Protocol.STATE_*`

- **Where:** `scripts/bridge/protocol.gd` defines `STATE_IDLE` … `STATE_ENDED`. Yet
  `scripts/core/avatar_cast.gd:16-19` re-declares `STATE_WAITING`, `STATE_ENDED` and `IN_USE` as
  literals; `scripts/core/click_action.gd:10`, `scripts/avatars/avatar_manager.gd:114` and
  `scripts/avatars/demo_player.gd:90` compare with `&"ended"`; `scripts/debug/session_panel.gd:153-161`
  maps literals to colours.
- **Why it matters:** `StringName` comparisons never fail loudly. A typo (`&"endd"`) silently
  turns a feature off. A reader also has to check that two `STATE_WAITING` constants agree.
- **Recommendation:** use `Protocol.STATE_*` everywhere a *session state* is meant; build
  `AvatarCast.IN_USE` from them. Leave `AvatarMood.STATE_CLIPS` alone where the values are clip
  names.
- **Risk:** low; the existing cast, mood and click tests cover it.
- **Worth fixing:** yes.

### F03 · Medium · Duplication · Objective — the normal buddy height `110` lives in five places

- **Where:** `scripts/core/buddy_size.gd:8` (`"normal": ["Normal", 110.0]`),
  `characters/monster/monster.gd:19` (`DISPLAY_HEIGHT_PT := 110.0`),
  `scripts/walkway/walkway_body.gd:20` (`height_pt := 110.0`),
  `scripts/avatars/session_avatar.gd:149` (`return height_pt / 110.0`) and
  `scripts/core/swing_physics.gd:37` (`_height := 110.0`, a placeholder until `grab()` sets it).
- **Why it matters:** `_speed_scale()` makes walking speed match the stride. If someone changes
  the Normal size in `BuddySize`, buddies silently walk at the wrong pace.
- **Recommendation:** `_speed_scale()` divides by `BuddySize.height_of(BuddySize.DEFAULT)`;
  `WalkwayBody.height_pt` defaults to `Monster.DISPLAY_HEIGHT_PT` (the character keeps its own
  constant, because it must work without the app, e.g. in previews and tests); `SwingPhysics`
  starts `_height` at `0.0` with a comment that `grab()` sets it.
- **Risk:** low.
- **Worth fixing:** yes.

### F04 · Medium · Documentation accuracy · Objective — ambiguous and stale design references

- **Where:** about 40 comments cite "design Dn" without naming the change, for example
  `focus_tracker.gd:2` (means overlay-window D5), `session_registry.gd:2` (claude-bridge D3),
  `region_registry.gd:2`, `bridge_server.gd:2`, `walkway.gd:94`, `monster.gd:169/268/280`.
  Every change numbers its decisions from D1, so "(design D5)" can mean any of thirteen designs.
  The comments added since the first version do name their change ("(buddy-drag D6)",
  "(dock-dodge D3)"), which shows the fix is already the habit. Stale examples:
  - `overlay_controller.gd:5` points to `openspec/changes/multi-display/design.md`, which was
    archived to `openspec/changes/archive/2026-11-23-multi-display/`.
  - `overlay_controller.gd:452` says "(design D10)" in a file whose header points at the
    overlay-window design; D10 is a multi-display decision.
  - `region_registry.gd:3` says "Rects are in overlay (window-local) pixels"; since
    multi-display they are walkway points (`Overlay.set_region` takes points).
  - `overlay_controller.gd:12-24` lists a "Public API" that misses `home_index`, `strip_ui`,
    `display_under_pointer`, `displays` and others.
- **Why it matters:** these references are how a newcomer finds the reasoning behind odd code.
  A wrong or ambiguous pointer costs more than no pointer.
- **Recommendation:** qualify every reference as `(<change> Dn)`, fix the stale path and units,
  and replace the hand-kept API list with a responsibility summary. A short README note says
  where archived designs live.
- **Risk:** none (comments only).
- **Worth fixing:** yes, and first: it is cheap and makes every later phase easier to review.

### F05 · Medium · Typing · Recommended — weak typing where modules meet

- **Where:** the project's convention is `const X := preload(...)` instead of `class_name` (only
  `Monster` has one). The constants are rarely used as types, so there are about 30 untyped
  `var x = …` declarations and several untyped parameters and returns, for example in
  `avatar_manager.gd` (`var a = _avatars.get(...)`, `var s = Bridge.registry.get_session(...)`,
  `var seg = ...`; `_press(a: Node, ...)`), `session_avatar.gd` (`setup(session, ...)`,
  `_home_segment()`, `_slot_x(seg)`), `walkway_body.gd` (the monster views),
  `bridge_server.gd:234-252`, `overlay_controller.gd:79` (`var walkway = Walkway.build(...)`), and
  `Walkway.build()`, which creates itself through `load("res://scripts/core/walkway.gd").new()`
  and returns an untyped value.
- **Why it matters:** no autocompletion and no compile-time check at exactly the places where a
  rename or a wrong field breaks things at run time.
- **Recommendation:** where a preload constant already exists, use it as a type:
  `var a: SessionAvatar`, `seg: Walkway.Segment`, `session: SessionRegistry.Session`,
  `m: Monster`. Do it file by file; no mass change. Whether to adopt `class_name` for
  `Walkway` (so `build()` can return a typed value) is a decision for you (section H).
- **Risk:** low per file; watch for cyclic preloads (none exist today).
- **Worth fixing:** yes (P2).

### F06 · Medium · Dead code · Objective — unused functions and spike leftovers

Verified at `3f03baf` with a repository-wide search (source, tests, scenes, OpenSpec, README):

- **Unused everywhere:** `Overlay.has_keyboard_focus_request()` (`overlay_controller.gd:776`),
  `Overlay.home_id()` (`:343`), `RegionRegistry.captured_id()` (`region_registry.gd:75`),
  `AvatarManager.avatar_for()` (`avatar_manager.gd:41`), `AvatarManager.is_away()` (`:102`),
  `SessionRegistry.Session.to_dict()` (`session_registry.gd:35`), and in the bridge
  `AppConnection.finish()` (`bridge/src/app_client.ts:217`).
- **Native methods unused from GDScript** (spike tools): `set_window_level`, `get_window_level`,
  `set_ignores_mouse_events` (spike S1 fallback), `find_app_of` (`native/src/mac_overlay.*`).
- **Used only by tests:** `Walkway.to_walkway()`, `Walkway.side_by_side()`,
  `SessionRegistry.most_recent()`, `RegionRegistry.has_region()`, `Monster.face_left()` /
  `face_right()`, `AvatarMood.work_clip()`, `GrabGesture.is_grabbed()`. The multi-display design
  says `side_by_side` "decides between a walk-over and an edge-to-edge hop", but no code calls it:
  the walk-off / walk-in at non-adjacent displays emerges from drawing a view per strip.
- **Debug knobs never changed in code:** `Overlay.restore_frontmost_on_click`,
  `QuietFps.check_pointer`, `Overlay.debug_force_dock()`. They are meant for `game_eval` during
  manual checks.
- **Recommendation:** remove the "unused everywhere" list. Keep test-only helpers that state
  intent in tests. Ask before removing `side_by_side`/`to_walkway` and the native spike methods
  (section H). Keep the debug knobs and say in their comment that they exist for `game_eval`.
- **Risk:** low. Removing native methods needs a rebuild of the extension.
- **Worth fixing:** yes.

### F07 · Low · Duplication · Objective — screen rectangles built in several places

- **Where:** `overlay_controller.gd:220`, `:311`, `:328` build
  `Rect2i(DisplayServer.screen_get_position(s), DisplayServer.screen_get_size(s))`; `dock_lift_pt`
  (around `:243`) and `_displays` (`:364`) build the same rectangle from its parts.
- **Recommendation:** one private `_screen_rect_px(screen) -> Rect2i`. Part of F01; after the Dock
  move, the tracker receives the rectangles from the controller.
- **Risk:** none. **Worth fixing:** yes, with F01.

### F08 · Medium · Readability · Recommended — anonymous tuples and open-ended dictionaries as state

- **Where:** `overlay_controller.gd:91` `var _hover := [-1, &""] # strip index and target`, read
  as `_hover[0]` (`:654`) and reset at `:395`. `bridge_server.gd:25` keeps each connection as a
  dictionary `{ws, ready, deadline, client, session}`, and `_reject` (`:130-131`) adds `close_at`
  and `rejected` later; `poll()` tests them with `c.has("rejected")`.
- **Why it matters:** the reader has to reconstruct the shape from scattered uses. The project
  already solves this well elsewhere with small inner classes (`Strip`, `Walkway.Segment`,
  `SessionRegistry.Session`).
- **Recommendation:** two named fields `_hover_strip` and `_hover_target`; an inner class
  `Connection` in `bridge_server.gd` with every field declared up front.
- **Risk:** low; `test_bridge_server.gd` covers the connection flow.
- **Worth fixing:** yes.

### F09 · Medium · Naming · Recommended — `_session_info()` hides its side effects

- **Where:** `bridge_server.gd:224-246`. The name reads like a lookup, but it creates sessions,
  moves MCP connection counts between sessions, prints, and emits `session_added`.
- **Recommendation:** rename to `_resolve_session()` and split the MCP part into
  `_attribute_mcp_connection(c, now_msec) -> Session`, with a doc comment that names the side
  effects.
- **Risk:** low. **Worth fixing:** yes.

### F10 · Low · Consistency · Recommended — two ways to read settings

- **Where:** `Settings` has typed properties for `overlay_visible` and `debug_regions`; the other
  four keys are read as `Settings.get_value(&"key", fallback)` with fallbacks that repeat
  `SettingsStore.DEFAULTS`: `&"show_names", true` three times (`menu_bar.gd:63,123`,
  `session_avatar.gd:297`), `&"screen", "auto"` twice (`menu_bar.gd:89`,
  `overlay_controller.gd:352`), `&"buddy_size", BuddySize.DEFAULT` twice (`menu_bar.gd:73`,
  `session_avatar.gd:61`), `&"screen_name", ""` once (`menu_bar.gd:90`).
- **Why it matters:** a default changed in `DEFAULTS` is not the default the call sites use when
  the key is missing, and string keys are easy to mistype.
- **Recommendation:** add typed properties for `screen`, `screen_name`, `show_names` and
  `buddy_size`, like the two that exist, and use them at the call sites. Keep `get_value` /
  `set_value` and the `changed(key, value)` signal unchanged; the file format stays the same.
- **Risk:** low; `test_settings_store.gd` covers storage.
- **Worth fixing:** yes (P2).

### F11 · Low · Duplication · Objective — small repetitions in the bridge

- **Where:**
  - The `hello` frame is built twice (`app_client.ts:83-84` and `:138-143`).
  - `Omit<ClientInfo, "bridge_version">` is spelled out five times.
  - Time-outs: `CONNECT_TIMEOUT_MS = 200`, but `sendOnce` defaults to `300`, `finish` to `300`
    and `mcp_server.ts:29` passes a literal `300`.
  - `claude_code.ts:52`: the doc comment "Maps a hook event to a protocol event" sits above
    `WAITS_FOR_USER`, not above `toEvent` (line 58).
  - The version `0.1.4` is in `bridge/package.json`, `bridge/src/protocol.ts:4` and
    `bridge/plugin/.claude-plugin/plugin.json`; the README asks to bump one of them.
- **Recommendation:** a `helloFrame(info, client)` helper; a `ClientIdentity` type alias; named
  time-out constants; move the comment; and a test that the three versions agree (section H).
- **Risk:** low; 30 bun tests cover the client. **Worth fixing:** yes.

### F12 · Low · Godot conventions · Objective — local variables shadow `Node.name`

- **Where:** `menu_bar.gd:109` (`var name := ""`), `demo_player.gd:50,54` (parameter `name`)
  and `:106` (`var name`). (`run_tests.gd:31` was listed here at first, but it extends
  `SceneTree`, which has no `name`.) Godot warns about this by default
  (`SHADOWED_VARIABLE_BASE_CLASS`). Also `quiet_fps.gd` declares `quiet_fps` after the `@onready`
  block, away from the other variables.
- **Recommendation:** rename to `display_name` / `session_name`; move the declaration up.
- **Risk:** none. **Worth fixing:** yes, trivial.

### F13 · Low · Magic numbers · Recommended — unexplained values in movement and UI

- **Where:** `session_avatar.gd:84` (`60.0 * _speed_scale()`, start offset off-screen), `:217`
  (`-half - 4.0`, exit margin), `debug_text_field.gd:70` (`points_to_px(160)`, height above the
  feet), `overlay_controller.gd:49` (`_OUTSIDE`, a tiny polygon outside the window that means
  "let every click through").
- **Recommendation:** named constants with a one-line comment each.
- **Risk:** none. **Worth fixing:** yes, when touching those files.

### F14 · Low · Readability · Objective — redundant reset in the view hand-over

- **Where:** `walkway_body.gd:145-148` sets `new.mirroring = false` before and again after
  `new.mirror(old)`; only the second is needed in that branch, and the first only matters for the
  `else` branch.
- **Recommendation:** set it once after the `if/else`.
- **Risk:** low (multi-display crossing; check by hand). **Worth fixing:** yes.

### F15 · Low · Duplication · Stylistic — clip names listed in several files

- **Where:** `monster.gd:28-33` (`LOOPING_CLIPS`, `ONE_SHOT_CLIPS`, now with `dangle`,
  `dock_hop`, `land`), `avatar_mood.gd:22` (`WORK_CLIPS`), `session_avatar.gd:25-29`
  (`HOP_CLIP`, `DANGLE_CLIP`, `LAND_CLIP`), `tools/build_monster_clips.gd`, `monster_preview.gd`,
  `tests/test_monster_clips.gd`.
- **Why it matters:** adding a clip means editing several lists.
- **Recommendation:** no shared registry (more indirection than it saves). Add one test that every
  clip name `AvatarMood` and `SessionAvatar` play is in `Monster.LOOPING_CLIPS` or
  `ONE_SHOT_CLIPS`, and that each prop clip has `_in`/`_out`.
- **Risk:** none. **Worth fixing:** optional (P3).

### F16 · Low · Consistency · Stylistic — three ways to reach sibling nodes in the main scene

- **Where:** `main.gd` uses `@onready $Path`; `quiet_fps.gd` uses `@export NodePath`;
  `menu_bar.gd:10` uses `get_node_or_null("../Demo")`.
- **Recommendation:** leave it. Each works and the scene is tiny.
- **Worth fixing:** no (P3).

### F17 · Low · Tests · Recommended — tests write into the real app data folder

- **Where:** `project.godot` sets a custom user dir, so `tests/test_settings_store.gd`
  (`user://test_settings.cfg`) and `tests/test_bridge_server.gd` (`user://test_bridge.json`)
  write into `~/Library/Application Support/ClaudeBuddy/`, next to the real settings.
- **Recommendation:** delete the files in `after_each`.
- **Risk:** none. **Worth fixing:** optional (P3).
- **Correction (task 8.2):** not a problem after all. `test_settings_store.gd` already deletes its
  file in `before_each` and `after_each`, and `test_bridge_server.gd` calls `server.stop()` in
  `after_each`, which deletes the info file. After many full runs the folder holds no `test_*`
  files. No change was made.

### F18 · Low · Naming · Objective — `_carry` means two different things

- **Where:** `scripts/core/swing_physics.gd:51` `var _carry := 0.0 # unused part of the last
  frame, in seconds` (the fixed-step accumulator), while `scripts/avatars/session_avatar.gd:50`
  `var _carry: StringName` is the carry phase (held, falling, landing). Both scripts are read
  together when working on dragging.
- **Recommendation:** rename the physics field to `_leftover_sec`.
- **Risk:** none. **Worth fixing:** yes, trivial.

## D. Refactoring opportunities by group

| Group | Findings | Notes |
|---|---|---|
| Comments and documentation accuracy | F04, part of F11 | No code change; do first |
| One source for each fact | F02, F03, F13 | Removes silent-drift risks |
| Removing dead code | F06 | Remove only what is verified unused |
| Naming and readability of internal state | F08 (bridge part), F09, F12, F14, F18 | Local, low risk |
| Typing at module boundaries and settings | F05, F10 | File by file |
| Bridge tidy-up | F11 | Independent of the Godot side |
| `OverlayController`: Dock tracking out, small tidy-ups | F01, F07, F08 (`_hover`) | The one structural item |
| Optional | F15, F16, F17 | Only if convenient |

## E. Prioritisation

| Priority | Items | Why |
|---|---|---|
| **P0** | none | No defects found that need immediate action |
| **P1** | F04 (references), F02 (states), F03 (height), F06 (dead code, the verified part), F01 (Dock tracking out of the controller) | Clear benefit; removes silent-drift risks, misleading pointers, and the largest readability cost |
| **P2** | F05 (typing), F08 (tuple, connection class), F09 (`_session_info`), F10 (settings properties), F11 (bridge), F12 (shadowing), F13 (magic numbers), F14, F18 | Useful; do in the cleanup or when touching the file |
| **P3** | F15 (clip-list test), F16 (node wiring), F17 (test files) | Little benefit or mostly taste |

## F. Refactoring roadmap

Every phase is one small pull request that leaves the project working. After each phase:

- Godot headless tests pass:
  `/Applications/Godot.app/Contents/MacOS/Godot --headless --path godot --script res://tests/run_tests.gd`
- Bridge phases: `cd bridge && bun test && bunx tsc --noEmit`.
- A short manual smoke check (below) when the phase touches nodes, not only pure helpers.

**Manual smoke check (5–10 minutes):** run the app; Play Demo; buddies walk in, work, jump while
waiting, sleep; click a buddy (its app comes forward); pick a buddy up, swing it, drop it into
another slot; right-click → Send home; menu bar Size, Show Names, Hide/Show Buddies, Screen;
click-through works outside buddies; with the Dock on autohide, buddies hop onto it; with two
displays (if available) buddies walk to the home display; Quit.

**Sequencing.** No other change is active now, so every phase can start. Phases are ordered so
that cheap, comment-only work comes first and the structural move comes once the surrounding code
is tidy. A new feature change that starts meanwhile simply rebases onto whatever has landed;
each phase is small enough for that.

### Phase 1 — Accurate references and comments (F04, F11 comment)

- **Goal:** every design reference names its change; no stale paths or wrong units.
- **Scope:** comments only, in `godot/scripts/**`, `godot/characters/**`, `godot/tools/**`,
  `bridge/src/**`; one README line on where design references point.
- **Risk:** none.
- **Validation:** tests pass; the diff contains only comments and the README.
- **Depends on:** nothing.

### Phase 2 — One source for each fact (F02, F03, F13)

- **Goal:** states from `Protocol`, the normal height from `BuddySize`/`Monster`, named
  constants for the magic numbers.
- **Scope:** `avatar_cast.gd`, `click_action.gd`, `avatar_manager.gd`, `demo_player.gd`,
  `session_panel.gd`, `walkway_body.gd`, `session_avatar.gd`, `swing_physics.gd`,
  `debug_text_field.gd`, `overlay_controller.gd` (`_OUTSIDE` only).
- **Risk:** low.
- **Validation:** tests pass; smoke check (walking pace at Small and Extra large unchanged).
- **Depends on:** nothing (Phase 1 makes the diffs cleaner).

### Phase 3 — Remove verified dead code (F06)

- **Goal:** delete what nothing uses.
- **Scope:** the "unused everywhere" list in F06. Native spike methods and `side_by_side` /
  `to_walkway` only if you approve (section H). Rebuild the extension if native code changes.
- **Risk:** low.
- **Validation:** tests pass; full-text search shows no remaining references; with native
  changes: `scons -C native` builds and the app logs "MacOverlay active".
- **Depends on:** nothing.

### Phase 4 — Readable internal state and names (F08 bridge part, F09, F12, F14, F18)

- **Goal:** a `Connection` class, honest names, no shadowing, one meaning per field name.
- **Scope:** `bridge_server.gd`, `menu_bar.gd`, `demo_player.gd`,
  `quiet_fps.gd`, `walkway_body.gd`, `swing_physics.gd`.
- **Risk:** low.
- **Validation:** tests pass (`test_bridge_server.gd`, `test_swing_physics.gd` in particular);
  `bun bridge/scripts/demo_client.ts` against the running app; smoke check.
- **Depends on:** nothing.

### Phase 5 — Typed boundaries and settings properties (F05, F10)

- **Goal:** sessions, segments, avatars and views are typed; settings read through properties.
- **Scope:** `avatar_manager.gd`, `session_avatar.gd`, `walkway_body.gd`, `bridge_server.gd`,
  `walkway.gd`, `settings.gd`, `menu_bar.gd`, `overlay_controller.gd` (two lines).
- **Risk:** low to medium (a wrong type annotation fails at load time, which is the point).
- **Validation:** tests pass; the project opens in the editor without new errors or warnings;
  smoke check.
- **Depends on:** Phase 2; the decision on `class_name Walkway` (section H).

### Phase 6 — Bridge tidy-up (F11)

- **Goal:** one hello builder, one client type, named time-outs, one version check.
- **Scope:** `bridge/src/app_client.ts`, `mcp_server.ts`, `adapters/claude_code.ts`,
  `protocol.ts`, one new test.
- **Risk:** low. The time-out values must stay exactly as they are.
- **Validation:** `bun test`, `tsc --noEmit`, `bun run build:plugin`; a hook from a real Claude
  Code session still shows up in the app.
- **Depends on:** nothing.

### Phase 7 — Dock tracking out of `OverlayController` (F01, F07, F08 `_hover`)

- **Goal:** the controller handles windows, coordinates, regions, input and focus; the Dock has
  its own script; the `defaults read` parser is pure and tested.
- **Scope:** `overlay_controller.gd`, new `scripts/overlay/dock_tracker.gd`, `dock_watch.gd`,
  `tests/test_dock_watch.gd`.
- **Risk:** medium (frame ordering, native polling). Behaviour must be identical.
- **Validation:** tests pass, including a new test for the `defaults read` parser; manual:
  Dock hop with autohide on, nothing with autohide off, with and without Accessibility access,
  on the second display; click-through, focus hand-back after clicking a buddy; carrying a buddy.
- **Depends on:** Phases 1, 2 and 4 (so the moved code is already tidy); your decision on the
  extraction (section H).

### Optional — P3 items (F15, F16, F17)

Any time, each as its own tiny pull request, or not at all.

## G. Things we should not refactor

- **The pure-helper pattern** in `scripts/core/` (plain data in, decisions out, headless tests).
  It is the backbone of the codebase. Do not turn the dictionaries passed to `AvatarCast.plan` or
  `QuietMode.is_quiet` into classes; their plainness is what makes them easy to test.
- **The three autoloads.** `Settings`, `Overlay` and `Bridge` are genuinely global (one settings
  file, one set of windows, one socket). No more, no fewer.
- **Signals as they are.** They go from autoloads to content, and content calls autoloads
  directly. No event bus.
- **`SessionAvatar extends WalkwayBody`.** One level of inheritance with a clear split (rendering
  across strips vs. behaviour).
- **`AvatarMood` as a plain class with phase strings, and the carry phases in `SessionAvatar`.**
  A state-machine framework would add machinery for clear code.
- **`SwingPhysics`.** Dense, but it is physics, well commented and tested; it reads as what it is.
- **The character pipeline** (`export_monster.gd`, `manifest.json`, `build_monster_clips.gd`).
  The clip builder is long because it is data, and the README explains it.
- **The native extension**, apart from optional dead-method removal. It is small and clear.
- **`hooks.json` repetition.** The format requires one entry per hook event.
- **The vendored `addons/godot_ai/`.** Not ours; its export plugin strips the runtime autoload, and the export preset leaves its files out.
- **Public `Overlay` and `Bridge` method names.** They are used across scripts, in tests, and in
  the `game_eval` verification steps of the OpenSpec tasks. No renames.
- **Polling loops** (layout every second, pointer every frame, Dock frame near the bottom edge,
  cast every 0.5 s). They exist because macOS gives no events for these; each is cheap.
- **Splitting the rest of `OverlayController`** (windows, headroom, pass-through, input, focus).
  They act on the same windows in a fixed order; splitting adds indirection, not clarity.

## H. Decisions

All five were accepted as recommended on 2026-11-23 and are recorded in the OpenSpec change's
`design.md` (D3, D4, D6, D8).

1. **`class_name` or `preload` for core types?** Recommendation: keep `preload` (current
   convention; the vendored addon already registers 56 global `Mcp*` class names) and use the
   constants as types; adopt `class_name` only for `Walkway`, so `Walkway.build()` can return a
   typed value.
2. **`Walkway.side_by_side()` and `to_walkway()`:** remove (no caller; the spec behaviour already
   emerges), or keep? Recommendation: remove.
3. **Native spike methods** (`set_window_level`, `get_window_level`, `set_ignores_mouse_events`,
   `find_app_of`): remove, or keep as debugging tools? Recommendation: remove the first three,
   keep `find_app_of` (useful when "go to session" finds the wrong app).
4. **Bridge version:** a test that the three files agree, or import from `package.json`?
   Recommendation: a test (no build-time coupling, still catches drift).
5. **Move Dock tracking into its own script (Phase 7)?** Recommendation: yes, as described in F01,
   and nothing more from `OverlayController`.
