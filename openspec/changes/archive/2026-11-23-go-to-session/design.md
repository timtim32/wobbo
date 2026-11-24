# Design: go-to-session

## Context

- **Agent processes:** every session in `SessionRegistry` carries `ppid`.
  - Hook clients send their parent process. Because the plugin runs the bridge with `exec`, that is the agent process itself (for example `claude`).
  - MCP clients send theirs too (the agent or its host).
  - Claude Code sessions in the Claude app's Code tab run their `claude` process under the Claude app.
  - Other agents (Codex, others) connect through the same hello, with `pid` and `ppid`.
- **`MacOverlay`:**
  - It already remembers and restores the frontmost app (`remember_frontmost_app` / `restore_frontmost_app`). On macOS 14+ it uses `[NSApp yieldActivationToApplication:]` and `activateWithOptions:`.
  - The overlay is an accessory app that never activates itself on a click (`overlay-window` "No focus stealing").
- **Clicks:** the avatar manager gets clicks through `Overlay.region_input`.
  - A left click calls `SessionAvatar.click()`, which plays `happy` and wakes a sleeping avatar.
  - A right click opens the context menu (`send-home` D4).

## Goals / Non-Goals

**Goals:**
- One agent-neutral way to find "the app of this session": from a process to its owning GUI app.
- A left click means "take me there" only while the session waits for the user.

**Non-Goals:**
- Selecting a tab, pane or conversation inside the host app.
- Bringing the app forward for sessions that do not wait.

## Decisions

### D1. From a process to its app
A new `MacOverlay.activate_app_of(pid) -> String` returns the app's name, or "" when none was found.
- **Walk up the parents:**
  - Starting at `pid`, look at each process until one is a regular app: `[NSRunningApplication runningApplicationWithProcessIdentifier:]` with `activationPolicy == NSApplicationActivationPolicyRegular`.
  - The next parent comes from `sysctl(KERN_PROC_PID)` (`kp_eproc.e_ppid`).
  - It stops after 32 steps, at pid 1, or when a process does not exist.
- **Examples:**
  - `claude` → `zsh` → `login` → Terminal (Terminal.app);
  - `claude` → Claude helper → Claude (the Claude app);
  - `codex` → `node` → Code Helper → Code (VS Code).
- **Helpers are skipped:** a helper process such as "Code Helper" is not a regular app, so the walk goes on to the parent app.

A small pure GDScript part decides what a click does: `ClickAction.for_left_click(state, ppid) -> {action: "go"|"none", reason}`, with tests. The native part is checked in the app.

*Alternative:* let each adapter report its host app (for example `TERM_PROGRAM` or a bundle id) in the hello. Rejected for now: the process walk works for every agent without protocol changes. A host hint can be added later for precise tab focus.

### D2. Activation from the overlay
Activation runs in this order:
1. `[NSApp yieldActivationToApplication:app]`, then `[app activateWithOptions:NSApplicationActivateAllWindows]`, as `restore_frontmost_app` already does.
2. If the app is not frontmost after 0.3 s (checked on the next poll), fall back to `[[NSWorkspace sharedWorkspace] openApplicationAtURL:app.bundleURL configuration:(activates = YES) …]`. LaunchServices brings a running app to the front.

The overlay itself does not become active; the click stays a pass-through for focus.

**Spike S1 (see the result below and D4):** check from an overlay click on macOS 27:
- that the Claude app, Terminal and VS Code come to the front with step 1 alone;
- whether the fallback is needed;
- that no Dock or Cmd-Tab entry appears for the overlay.

**Fallback:** if neither step brings the app forward, run `open -b <bundle id>` through `OS.execute`, with the bundle id from `NSRunningApplication`.
- **Result S1 (task 1.2, 2026-11-23, by hand with this Claude Code session in the Claude app):**
  - Clicks reach the app and activation is requested, but with a minimised Claude window nothing seemed to happen. `activateWithOptions:` made the app active without bringing a minimised window back.
  - `activate_app_of` now works like a click on the Dock icon: `unhide`, activate, and always `openApplicationAtURL` with `activates = YES`, which also restores a minimised or closed main window. With that, the Claude app came back.
  - It still stayed on another session, which led to D4.

### D3. Clicks on avatars
- **Left click:** the manager checks the session state.
  - `waiting`: call `Overlay.native.activate_app_of(session.ppid)`, log the app name or the reason, and leave the avatar as it is. It keeps jumping until the session moves on.
  - Any other state: nothing.
- **Happy reaction:** `SessionAvatar.click()` and `AvatarMood.click()` are removed, together with their tests, because the happy reaction on click is gone (spec). `happy` stays for `done`.
- **Right click:** unchanged.

### D4. Focus links
Spike S1 showed that bringing the Claude app to the front leaves it on whatever session was open. The Claude app has deep links for Code sessions (found in its URL handler):
- `claude://code/needs-input?session=…` opens a *new* session in that folder, so it is not usable;
- `claude://code/continue?session=<id>` opens exactly that session (tried by hand: it switched from another session to this one).

The id is the Claude app's own session id (`local_…`), not Claude Code's. Claude Code gets it from the Claude app in the environment variable `CLAUDE_CODE_HOST_SESSION_ID`, which the hooks inherit.

**The pieces:**
- **Protocol:** `SessionRef` gets an optional `focus_url` (additive, `v: 1`, documented in `PROTOCOL.md`).
- **Claude Code adapter:** when `CLAUDE_CODE_HOST_SESSION_ID` is set, `sessionOf` adds `focus_url = claude://code/continue?session=<id>`. Other adapters can add their own later.
- **Registry:** `Session.focus_url` keeps the latest allowed link. The pure `FocusLink.allowed(url)` accepts only schemes in `ALLOWED_SCHEMES = ["claude"]`, so a local client cannot make the app open `file:`, `http(s):` or anything else.
- **Click:** activate the app by process (D1, D2), then `OS.shell_open(focus_url)` when there is one. The click counts as done when either worked.

### Godot and macOS assumptions
- macOS 14+: `yieldActivationToApplication:` only takes effect when the yielding app is active. The overlay is not, so step 1 may be ignored. That is why spike S1 exists, and why there is a LaunchServices fallback.
- `sysctl` `KERN_PROC_PID` and `NSRunningApplication runningApplicationWithProcessIdentifier:` need no special entitlement for the user's own processes.

## Risks / Trade-offs

- [A session's `ppid` is 0 or stale (an MCP-only client without a parent, or an agent that was restarted)] → Nothing happens and the reason is logged (spec). The next event from the agent refreshes `ppid`.
- [Some hosts run agents under a background service, for example tmux started outside the terminal] → The walk reaches `launchd` without finding an app. Nothing happens, and the reason is logged. Accepted for now.
- [The user may expect the exact tab] → Out of scope; mentioned in the README as a known limit.
