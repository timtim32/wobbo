# Design: balloons-and-speech

## Context

- **What reaches the app today:**
  - `BridgeServer` turns `say` into `registry.set_message()` plus the `message_received(session_id, text)` signal.
  - A `request` (question or permission) becomes a pending request in `SessionRegistry` plus `request_added(request)`.
  - Answers go back through `answer_request(id, choice, text)` and `dismiss_request(id)`. In the bridge, `dismissed` makes `ask_user` tell the agent to ask in the conversation, and makes the permission hook return no decision, so Claude Code shows its own prompt.
  - Only `debug/session_panel.gd` listens to these signals.
- **Requests:**
  - A request is `{id, session_id, kind, text, choices, allow_text, owner}`. The `timeout_s` the bridge sends is not kept.
  - Permission prompts wait `CLAUDE_BUDDY_PERMISSION_WAIT_S`, 20 s by default.
  - A local request from the demo has owner `-1`, and `_send` ignores unknown owners.
- **State changes:** `apply_event()` reports whether something changed, but not which event happened. The bridge only emits `session_changed(id)`.
- **Overlay building blocks:**
  - `Overlay.set_region()` / `remove_region()` make a rect interactive, in walkway points.
  - `Overlay.request_keyboard_focus(control)` / `release_all_keyboard_focus(control)` take focus and give it back to the previously frontmost app.
  - `Overlay.strip_ui(i)` is a CanvasLayer per display.
  - `local_rect_to_walkway()` and `walkway_to_local()` convert between window px and walkway points.
  - The debug panel already uses all of these for buttons and a text field. Clicks on regions do not activate the app (`restore_frontmost_on_click`).
- **Avatars:**
  - `SessionAvatar` places a `NameLabel` per strip view above `bounds_pt().position.y`, and registers `avatar:<id>`.
  - The label hides while the buddy is carried or the names are off.
  - `AvatarManager.avatars()` lists the avatars on screen.
  - `Main` disables `Content` (and with it the avatars) while the buddies are hidden. `QuietFps` lives outside `Content` for that reason.
- **Room in the strip:** 360 pt high, the buddy 80–170 pt plus an 8 pt gap. Above the head that leaves about 242 pt at Normal and 182 pt at Extra large.
- **Settings and menu:**
  - `SettingsStore.DEFAULTS` plus typed properties on the `Settings` autoload.
  - The menu bar builds radio submenus from pure helpers (`ScreenMenu`, `BuddySize.items`).
- **Platform:**
  - Godot 4.7, macOS only.
  - `DisplayServer.tts_*` needs the project setting `audio/general/text_to_speech`, which is off now.

## Goals / Non-Goals

**Goals:**
- Every decision about what to show, speak, keep or hand back is pure logic in `scripts/core/`, unit tested headless. The nodes only render and play.
- No change to the native extension. The bridge and the protocol change only additively (D11).
- `OverlayController` does not grow: the change uses only its existing region, focus and strip APIs.

**Non-Goals:**
- A general notification framework or plugin points for other kinds of notices.
- Balloons that span two displays.

## Decisions

### D1. A `Messages` node outside `Content` owns what each buddy says
A new node `Main/Messages` (`scripts/avatars/messages.gd`) is the only listener for message-related Bridge signals. It holds one `BalloonQueue` per session (D3), asks `MessagePolicy` (D2) what to do, drives `Speech` (D7), and hands each avatar its current balloon content.

- **Why outside `Content`:** it must keep handing requests back while the buddies are hidden (spec "Hidden buddies"), and `Content` is disabled then.
- *Alternative:* put the logic in `AvatarManager`. Rejected: it then stops while hidden, and it already handles casting, grabbing and the menu.
- *Alternative:* an autoload. Rejected: the speech and balloon parts need the scene, and an autoload would make tests start TTS.

### D2. `MessagePolicy`: pure rules for what happens
`scripts/core/message_policy.gd`, static functions:

- **`output_flags(mode)`** → `{balloon, speech}`:
  - `balloons` → `{true, false}`
  - `speech` → `{false, true}`
  - `both` → `{true, true}`
  - `off` → `{false, false}`
- **`accepts_requests(mode, visible)`** → false when the mode is `off` or the buddies are hidden. `Messages` then dismisses every pending request and each new one at once (spec "Output off", "Hidden buddies").
- **`for_message(text, name, mode)`**, **`for_turn_end(name, turn_ms, notify_done, mode)`** and **`for_turn_error(name, error, notify_errors, mode)`** → `{show, speak, text, spoken, duration_s}`, or `{}` for nothing:
  - Turn finished counts only when `turn_ms >= 20_000`.
  - An error uses its first line, cut at 120 characters.
- **`for_request(request, name, mode)`:**
  - `show` is always true when requests are accepted, also with output `speech` (spec "Spoken output").
  - The spoken text is "<name> asks: <text>", or "<name> wants to <text>" for a permission.
- **`reading_time_s(text)`** → `clamp(3.0 + 0.06 * text.length(), 4.0, 12.0)`. Errors use 8 s and "Done" 4 s.

*Alternative:* decide "turn finished" by whether the session's app is frontmost. Rejected: the Claude app hosts many sessions, so a frontmost Claude app does not mean the user watches that session. The 20-second rule is simple, needs no native call, and silences the quick back-and-forth of a conversation.

### D3. `BalloonQueue`: what one buddy shows now
`scripts/core/balloon_queue.gd` is pure. Time is passed in.

- **What it holds:** an ordered list of request ids, and at most one message `{text, kind, until_msec}`.
- **`current(now)`:**
  - With pending requests, it returns the oldest one with `index` and `count` ("1 of 2").
  - Otherwise it returns the message if it has not expired.
  - Otherwise null.
- **`set_message()`** replaces the message. While a request is shown, the message still counts down underneath, so it rarely survives the request. This is accepted: it was not hidden by the request in the meantime (spec "One balloon per buddy").
- **`hold(now)` / `release(now)`** pause the countdown while the pointer is on the balloon: `until_msec` moves by the time held.
- **`close_message()`** ends the message at once.

### D4. Registry and bridge additions
- **`SessionRegistry.add_request()`** keeps `added_msec` and `timeout_s` from the frame (0 when missing), for the time-left bar. `BridgeServer` copies `timeout_s` into the request.
- **`Session.turn_started_msec`** is set on `prompt` and read on `turn_end` for the 20-second rule.
- **New signal `BridgeServer.session_event(session_id, kind, data)`** is emitted from `_apply_event()` when the event was applied, so `Messages` sees `turn_end` and `turn_error` without guessing from state changes.
- **Request withdrawals** already emit `request_removed`, and `Messages` drops the id from the queue.

*Alternative:* detect the state change to `done` or `error` in `Messages`. Rejected: a pending request keeps the state at `waiting` and stores the new state in `state_before_wait`, so the transition would be missed.

### D5. One `Balloon` control per avatar, placed by the avatar
- **What it is:** `scripts/avatars/balloon.gd`, a `PanelContainer` that `SessionAvatar` creates lazily. It lives in `Overlay.strip_ui(i)` of the strip under the avatar's centre, and is reparented when the buddy crosses to another display, as `Main._move_ui` does for the panel.
- **What the avatar does:** it calls `balloon.show_content(content)` with whatever `Messages` set on it. Each frame in `_finish_frame` it calls `balloon.place(head_top_local, strip_rect)` and registers `balloon:<session id>` through `Overlay.set_region(local_rect_to_walkway(...))`. When the balloon is hidden it removes that region.
- **Name label:** hidden while the balloon shows (`_labels_shown()` adds `not balloon_open`).
- **Carried buddy:** the balloon hides while the buddy is carried, like the label, and the queue keeps its content.

*Alternative:* one balloon layer that places all balloons. Rejected: the avatar already knows its head, its strip and its carry state every frame, and the label code shows the pattern.

### D6. Balloon look and layout
- **Look:** an opaque white rounded rectangle (radius 10 pt) with a soft shadow, dark text and a small triangular tail drawn in `_draw()`.
  - The header shows the session name in 11 pt semibold, in the buddy's colour (its hue at fixed saturation and value), and a close button "×".
  - The body is 13 pt system font, word-wrapped.
  - An opaque fill, because translucent fills look washed out on the transparent overlay (as noted for the debug panel).
- **Size:**
  - Width fits the content between 120 and 300 pt.
  - The height limit is `room = head_top_y - 6 pt` (the space above the head in the strip).
  - The body gets the lines that fit after the header, buttons and field. The last line ends in "…" (`Label.max_lines_visible` plus `OVERRUN_TRIM_ELLIPSIS`).
- **Placement, pure in `scripts/core/balloon_layout.gd`:**
  - Centred over the head, then clamped to `[segment.start + 8, segment.end - 8]`.
  - The tail's x is clamped inside the balloon's rounded corners, so it points at the buddy as closely as possible.
  - Tested headless with numbers.
- **Buttons:**
  - One per choice, in a flow container that wraps when they do not fit.
  - Permission prompts get "Allow" (filled with the accent colour) and "Deny".
  - A `ProgressBar`-like thin bar under the buttons shrinks from `timeout_s` to 0, based on `added_msec`.
  - Requests without a `timeout_s` show no bar.
- **"1 of 2"** appears in the header when there is more than one pending request.

*Alternative:* grow the strip with `Overlay.begin_headroom()` when a balloon needs more room. Rejected for now: questions are at most 500 characters and fit in about 9 lines at 300 pt, so cutting is rare, and the headroom machinery is tuned for dragging. It can be revisited without spec changes.

### D7. `Speech`: a thin wrapper over `DisplayServer.tts_*`
- **The node:** `scripts/avatars/speech.gd` (child of `Messages`) picks a voice once: the first of `tts_get_voices_for_language(OS.get_locale_language())`, else the first of `tts_get_voices()`, else none.
- **Speaking:** `speak(text)` calls `tts_speak(text, voice, 50, 1.0, 1.0, id, false)` and queues behind what is playing.
- **Stopping:** `stop()` calls `tts_stop()` when the output turns off or the buddies are hidden.
- **No voice:** `available()` drives the disabled menu items.
- **Pure parts:** the voice choice is a pure function (`scripts/core/speech_voice.gd`) on the voice list, tested with fake lists.
- **Project setting:** `audio/general/text_to_speech=true` in `project.godot` (Godot 4.x requires it at startup).

**Spike S1:** does TTS speak from this accessory app (no Dock icon, `LSUIElement`), with and without the editor, and in the exported app? *Fallback:* run `/usr/bin/say` through `OS.create_process` with the same queue in GDScript. Same API on the `Speech` node, so nothing else changes.

*Result (Godot 4.7.2, editor run):* `DisplayServer.tts_*` works from the accessory app. It lists 180 voices (41 for `en`), and `tts_speak` with `com.apple.voice.compact.en-US.Samantha` speaks (`tts_is_speaking()` is true), even before the project setting was enabled. The setting is enabled anyway, as Godot documents it. The exported app is not checked yet: there is no export preset. No fallback is needed.

### D8. Settings and the "Messages" menu
- **New keys in `SettingsStore.DEFAULTS`:**
  - `messages: "balloons"` (`balloons`, `speech`, `both`, `off`, where an unknown value counts as `balloons`);
  - `notify_done: true`;
  - `notify_errors: true`.
- **Properties:** typed properties on `Settings`, as for the others.
- **Menu items:** `MessagePolicy.menu_items(mode, speech_available)` returns the radio items with labels, the checked one and disabled flags, and is tested headless.
- **Menu:** `menu_bar.gd` adds the submenu after "Size", with the two check items after a separator.
- **Reacting to changes:** `Messages` listens to `Settings.changed`. Switching to `off` dismisses all pending requests, clears the messages and stops speech. Switching between the other outputs only affects what comes next.

### D9. Handing requests back
`Messages` dismisses a request at once when `accepts_requests()` is false: on `request_added`, on a switch to Off, and on `content_visibility_changed(false)`.

- **What the bridge does with it:** `dismiss_request()` already does the right thing for both kinds. `ask_user` returns "dismissed, ask in the conversation", and the permission hook returns no decision, so Claude Code prompts at once.
- **Demo requests:** they have no owner and are just removed.

### D10. Quiet frame rate and the debug panel
- **Quiet frame rate:** `QuietMode.is_quiet()` gets a `balloon_open` argument. While any balloon shows, the frame rate stays normal: the time-left bar and hover states move. `QuietFps` asks `Messages.any_balloon_open()`.
- **Debug panel:** unchanged, apart from its header comment ("Temporary: replaced by real balloons…" becomes "debug view next to the balloons"). Answering in either place removes the request from both.

### D11. Questions asked in the agent's own window
Claude often asks in its own UI, not through `ask_user`:
- Claude Code's `AskUserQuestion` tool, and `ExitPlanMode` (plan approval). Both are reported as `input_wait` today.
- The Claude app's next-step box. It is the `mcp__ccd_turn__wrap_up` tool with an `ask` field and `actions` (button labels), called right before the turn ends.

A check showed that `PreToolUse`/`PostToolUse` hooks fire for the Claude app's own `mcp__ccd_*` tools, with their `tool_input`.

- **Bridge (`toEvent`):** the `PreToolUse` event of these tools carries `data.question` (the text) and `data.choices` (labels).
  - `AskUserQuestion` sends its first question and its option labels, with "(+N more)" when it asks several.
  - `ExitPlanMode` sends "Plan ready for your approval".
  - `wrap_up` with a non-empty `ask` sends the ask and the action labels. It stays a `tool_start` (the session is not waiting: the turn ends right after), with `data.question_until: "prompt"`.
  - The `input_wait` events get `question_until: "answer"`.
- **Protocol:** these are new optional `data` fields, so `v` stays 1.
- **App:**
  - `Messages` puts such a question in a separate "asked" slot of the `BalloonQueue`. It sits between requests and messages, so a "Done" notice does not hide it.
  - It is spoken like a request when speech is on.
  - `"answer"` closes on `tool_end`/`tool_error` of the same tool. `"prompt"` closes on the next `prompt`. Both close on `session_end`.
  - Its balloon shows the question, the choices as a muted line ("yes · no"), and the hint "Answer in the session".
  - A click on it calls `AvatarManager.go_to_session()`; the × only closes it.
- **The same rules as other messages:** Off and hidden buddies show nothing. Questions are not kept for a buddy that is not on screen, though a waiting session brings its buddy in.

*Alternative:* answer buttons that type the choice into the session. Rejected: there is no channel back into Claude Code or the Claude app. Faking keystrokes into another app is fragile and steals focus.

## Risks / Trade-offs

- **[The next-step box is internal to the Claude app]** (`mcp__ccd_turn__wrap_up`, its `ask` and `actions` fields) → It may change without notice. The bridge reads it defensively: an unknown shape sends a plain `tool_start` as today.

- **[TTS does not work from the accessory app or the exported bundle]** → Spike S1 first, with the `/usr/bin/say` fallback behind the same API.
- **[Balloons of neighbouring buddies overlap on a narrow display]** (5 slots on a 1280 pt screen is about 256 pt per slot, and balloons are up to 300 pt) → The balloon that was opened last is drawn on top, and request balloons above message balloons. The region registered last wins hit-testing, so clicks match what is on top. This is acceptable because two balloons at once are rare.
- **[A balloon and an avatar region overlap]** → The balloon sits above the head's top with a 6 pt gap, so the regions do not touch. The tail is drawn but not part of the region.
- **[`say` reports "shown" while output is Off or no buddy is on screen]** → Accepted and listed as out of scope. Changing it needs a protocol ack.
- **[Cut-off questions]** → Rare at 500 characters. The full text is also in the agent's conversation. Headroom is the follow-up if it bothers.
- **[Spoken text in English labels ("asks", "is done") with a non-English system voice]** → The app's UI is English throughout. A localized voice reading English words is acceptable for now.
- **[Permission prompts still wait 20 s when the user ignores the balloon]** → Unchanged from today, but now visible with a time-left bar, and the close button hands back at once.

## Migration Plan

There is no data migration. The new settings get their defaults on first launch. Rolling back means removing the `Messages` node and the menu items. Old settings files with the new keys are ignored by older builds.
