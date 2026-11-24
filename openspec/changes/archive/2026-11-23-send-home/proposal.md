# Proposal: send-home

## Why

The user often leaves a Claude Code session open to continue it later. Such a session never ends, and its MCP connection stays open, so the app keeps it and its buddy stays on screen, asleep, for hours. The strip fills up with buddies of sessions that are done for now. The user wants these buddies to go away without closing the session, and to come back when the session is used again.

## What Changes

- **Going home by itself:** a buddy that has slept for 15 minutes wakes up, walks off at an outer edge, and its session is marked as *away*.
- **Sending a buddy home:** right-clicking a buddy opens a small context menu with **"Send home"**. Choosing it makes the buddy walk off right away, and its session is marked as away.
- **Coming back:** an away session gets its buddy back, walking in as usual, as soon as it is used again: a new prompt, a tool start, or a question or permission request. Background notifications do not count.
- **Away sessions and the strip:** away sessions do not take a place among the at most 5 buddies, so a buddy of an active session can take the freed slot.
- **The context menu replaces the direct right click:** in debug mode the menu also has **"Type here (debug)"**, which opens the debug text field at the buddy. That used to happen directly on a right click. The menu is the start that `avatar-interactions` will extend, for example with "Focus window".

### Out of scope

- Ending or closing the agent session itself. Sending a buddy home never affects the agent.
- Keeping the away state across app restarts. After a restart, an open session that sends an event gets a buddy again, which falls asleep and goes home by itself later.
- Other context-menu items such as focusing the session's window or renaming (`avatar-interactions`).
- A setting for the 15-minute timeout.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `session-avatars`:
  - "One avatar per session" gets the away exception;
  - "Looking and click reaction" replaces the direct right click with the context menu;
  - a new requirement, "Sending a buddy home", covers going home by itself, "Send home" and coming back.

## Impact

- **Changed code:**
  - `AvatarCast` (away sessions are not candidates);
  - `AvatarMood` / `SessionAvatar` (how long it has been asleep, going home);
  - the avatar manager (the away set, return on activity, the context menu);
  - `main.gd` (the debug text field opens from the menu).
- **Native menu:** the context menu uses Godot's `NativeMenu`, which shows a real macOS context menu. Whether it works from the unfocusable overlay windows without taking focus is checked in a spike, with a fallback.
- **No bridge or protocol changes:** away is app-only state.
