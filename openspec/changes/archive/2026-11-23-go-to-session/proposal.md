# Proposal: go-to-session

## Why

A buddy that jumps for attention says "this session needs you", but the user then has to find that session among their terminals and windows. Clicking the jumping buddy should take the user straight there. At the same time, clicking a buddy that does not need anything should not do anything that looks like it matters: the happy reaction on every click blurs what a click means. This has to work for any coding agent, not only Claude Code.

## What Changes

- **Go to the session:** a left click on a buddy whose session waits for the user (the jumping buddy) brings the app that runs that session to the front. That app can be the Claude app, a terminal, an editor, or whatever hosts the agent. The app is found from the agent's process (known for every hook and MCP connection) by walking up the process tree to its owning macOS app. So it works for every agent without agent-specific code.
- **Left click only when it matters:** a left click on a buddy that does not wait for the user does nothing. The happy reaction on click is removed. The buddy still catches the click (it is an interactive region for the right-click menu), so the click does not reach the window behind it.
- **Straight to the session where possible:** an agent adapter may send a *focus link* with its session, a URL that opens that exact session in its host app. The Claude Code adapter sends `claude://code/continue?session=<id>` for sessions in the Claude app, using the app's own session id from `CLAUDE_CODE_HOST_SESSION_ID`. The click then opens that link as well. For safety the app only opens links whose scheme it knows (for now `claude`).
- **Right click unchanged:** the context menu with "Send home" (and "Type here (debug)") keeps working on every buddy.
- **No session app:** when the session's process is gone, or no owning app can be found, the click does nothing and the reason is logged.

### Out of scope

- Selecting the exact tab or pane in terminals and editors. Only the app comes to the front there. More focus links can follow per host later; the Claude app's Code sessions are covered by the focus link.
- Drag and drop, and more context-menu items.
- Going to sessions that do not wait (for example after `done`).

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `agent-bridge`: a new requirement, "Focus link": the Claude Code adapter sends a link to the session in the Claude app.
- `session-tracking`: a new requirement, "Session focus link": the app keeps a session's focus link.
- `session-avatars`:
  - "Looking and click reaction" changes the left click: it goes to the session while the session waits, and does nothing otherwise. The happy click reaction is removed.
  - A new requirement, "Go to the session", covers finding and activating the app that hosts the session.

## Impact

- **Native (`MacOverlay`):** a new method that finds the owning app of a process (walking parent processes with `sysctl` / `proc_pidinfo` until a process is a regular `NSRunningApplication`) and activates it. Cooperative activation on macOS 14+ is checked in a spike.
- **Godot:**
  - the avatar manager (left click → go to the session when waiting);
  - `AvatarMood` (the click reaction is removed);
  - `Session.ppid` is used as the agent's process.
- **Bridge:** `SessionRef` gets an optional `focus_url` (additive, `v: 1`). The Claude Code adapter fills it from `CLAUDE_CODE_HOST_SESSION_ID`. The plugin goes to 0.1.4.
- **Godot:** `Session.focus_url`, and opening it with `OS.shell_open` for allowed schemes.
