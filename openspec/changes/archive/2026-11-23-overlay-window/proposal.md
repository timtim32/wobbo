# Proposal: overlay-window

## Why

Every other part of Claude Buddy (the avatars, balloons, sessions and interactions) needs a surface to live on: a strip along the bottom of the screen that looks like part of the desktop rather than an app window. Building that surface first is the riskiest step, because it depends on macOS window behaviour that Godot does not offer out of the box. So it goes first and gets proven in isolation.

## What Changes

- Add a Godot main scene that opens one transparent, borderless, always-on-top window spanning the full width of the bottom of the main display's usable area.
- Make the window ignore the mouse everywhere except on registered interactive regions. Avatars and balloons will register their regions later; this change adds a debug placeholder that does so now.
- Keep the overlay visible on every Space and above other apps' fullscreen windows.
- Make sure the overlay never takes keyboard focus away from the user's current app, except when it explicitly asks for focus (needed later for the balloon text field).
- Run as a background accessory app: no Dock icon and no entry in the Cmd-Tab switcher.
- Add a macOS menu bar icon with a menu to show or hide the overlay, toggle a debug view of the interactive regions, and quit. The show/hide choice persists across launches.
- Add a small native macOS GDExtension (`native/`) for the window behaviour that Godot cannot set itself.
- Reposition the overlay when the display layout changes (resolution change, Dock resize, display added or removed).

### Out of scope

- The character art, rig and animations (`character-rig`).
- Anything related to Claude Code: hooks, the MCP server and the bridge (`claude-bridge`).
- Avatars per session, walking behaviour and mood (`session-avatars`).
- Speech balloons, TTS and the output-mode setting (`balloons-and-speech`).
- Click-to-focus, drag & drop and the per-avatar right-click menu (`avatar-interactions`). This change only provides the hit-testing they rely on.
- Choosing which display to use, and spanning multiple displays. v1 always uses the main display.
- A global hotkey, code signing, notarization and a distributable `.app` export.

## Capabilities

### New Capabilities

- `overlay-window`: the transparent, click-through, always-visible desktop surface along the bottom of the screen. Covers placement, mouse pass-through with interactive regions, Space and fullscreen visibility, focus behaviour and accessory-app presence.
- `menu-bar-control`: the macOS menu bar icon and its menu, for global control of the app (show/hide, debug view, quit), with persisted settings.

### Modified Capabilities

None. This is the first change in the project.

## Impact

- **New code:** `godot/` (main scene, overlay controller, menu bar, settings) and `native/` (GDExtension in Objective-C++ built with godot-cpp and SCons).
- **New build dependencies:** godot-cpp at the branch matching Godot 4.7, SCons, and Xcode command line tools.
- **macOS APIs:** NSWindow `collectionBehavior`, window level and `ignoresMouseEvents`, NSApplication activation policy, NSEvent mouse location, and NSWorkspace frontmost app.
- **Later changes** build on the interactive-region API and the settings store introduced here.
