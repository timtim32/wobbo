# Proposal: balloons-and-speech

## Why

The buddies show what each session is doing, but they cannot talk yet. Claude's `say` messages, `ask_user` questions and permission prompts already reach the app. Only the debug panel shows them, and only in debug mode. Without debug mode a question sits unseen until it times out, and every permission prompt waits 20 seconds before Claude Code shows its own. This change gives the buddies a voice: a speech balloon above the buddy, answer buttons in that balloon, and optional spoken messages. The user can choose the output or turn it off.

## What Changes

- **Speech balloon:** a buddy shows a balloon above its head. It shows the agent's `say` messages, the turn-finished and error notices, and pending questions and permission prompts. The balloon is interactive. The rest of the strip stays click-through, and clicking a button does not take keyboard focus from the user's app.
- **Answering at the buddy:**
  - Questions show their choices as buttons. A free-text field appears when the question allows typing, and takes keyboard focus only when clicked. Enter sends the text.
  - Permission prompts show **Allow** and **Deny** and a bar for the time left.
  - A close button dismisses a question, or leaves a permission prompt to Claude Code's own prompt.
  - Several requests of one session are shown one at a time, oldest first.
- **Speech:** messages can be spoken with macOS's built-in voices (`DisplayServer.tts_*`), starting with the session's name.
- **Notifications by default:**
  - questions and permission prompts;
  - a turn that finished after working for a while (at least 20 seconds);
  - a turn that failed.
  The turn-finished and error notices can each be turned off.
- **"Messages" menu** in the menu bar, persisted like the other settings:
  - **Output:** Balloons (default), Speech, Balloons and Speech, or **Off**.
  - **Turn finished** and **Errors** check items.
- **Off really is off:**
  - With output Off, or while the buddies are hidden, nothing is shown or spoken.
  - Questions and permission prompts are handed back at once instead of waiting. `ask_user` tells the agent to ask in the conversation, and Claude Code shows its own permission prompt without the 20-second wait.
- **Questions asked in the agent's own window:** when Claude asks something in its own UI (Claude Code's question tool, a plan to approve, or the question in the Claude app's next-step box), the buddy shows that question in a balloon to read, with the answer options as plain text. Clicking the balloon brings the user to the session to answer there. It closes once the session goes on.
- **The buddy name moves into the balloon:** while a balloon is open, its header shows the session name and the name label above the head hides. This leaves room for the balloon at every buddy size.

### Out of scope

- Detecting failing tests in tool output. Only failed turns count as errors. Tool errors happen often in a normal turn and are not announced.
- Telling the agent that a `say` message was not shown (output Off, buddies hidden, or no buddy on screen). `say` stays fire-and-forget.
- Answering a question that was asked in the agent's own window from the balloon. There is no channel back into Claude Code or the Claude app, so the balloon only shows it and leads to the session.
- A history of past messages, or scrolling inside a balloon. Text that does not fit is cut with "…".
- Choosing a voice, speed or volume. The system voice for the user's language is used.
- New buddy animations for talking. The buddy keeps doing what its state says, and a waiting buddy still jumps.
- Sound effects, and macOS Notification Center notifications.
- Removing the debug panel. It stays in debug mode as a session list that can also answer.
- Splitting `OverlayController` further. This change only uses its existing region, focus and strip APIs.

## Capabilities

### New Capabilities

- `buddy-messages`: what the buddies tell the user and how the user answers them. It covers:
  - the speech balloon (content, placement, how long it stays);
  - answering questions and permission prompts in the balloon;
  - spoken output;
  - which events notify by default;
  - what happens when output is off or the buddies are hidden.

### Modified Capabilities

- `agent-bridge`: a new requirement, "Question text from the agent's own window": the status report of a question asked in Claude Code's or the Claude app's own UI carries the question and its options.
- `menu-bar-control`:
  - a new requirement, "Messages", for the submenu with the output choice and the two notification toggles;
  - "Persisted settings" adds these, with Balloons, Turn finished on and Errors on as defaults.

## Impact

- **Godot app:**
  - new balloon, message and speech scripts under `godot/scripts/avatars/` and pure logic under `godot/scripts/core/`, with headless tests;
  - changes to `session_registry.gd` (a request's time-out and arrival time, when a turn started) and `bridge_server.gd` (a signal for session events);
  - `session_avatar.gd` hides the label while a balloon is open;
  - `quiet_mode.gd` keeps full frame rate while a balloon is open;
  - `settings.gd` and `settings_store.gd` get the new settings;
  - `menu_bar.gd` gets the "Messages" submenu;
  - `project.godot` enables text-to-speech.
- **Bridge:** the Claude Code hook adds the question text and options to the events of Claude's question tool, plan approval and the Claude app's next-step box (an additive protocol change: new optional `data` fields). The existing `answer` statuses cover everything else. The plugin binary is rebuilt and its version raised.
- **Native extension:** no changes.
- **Docs:** the README describes the balloon, speech and the "Messages" menu.
