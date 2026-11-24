# Proposal

## Why

The buddy only runs from the Godot editor, and connecting it to Claude Code takes terminal commands. Nobody but the developer can use it. It should become a product called **Wobbo** that anyone with Claude Code can use without a single command:
1. download it;
2. open it;
3. click "Connect".

macOS should also show it under its own name, for example in the Accessibility list, which dodging the Dock needs.

## What Changes

- **Wobbo.app as a download.** The maintainer runs one release script, which builds a universal (Apple silicon and Intel) `Wobbo.app`, signs it, packs it in `Wobbo.dmg` and can publish it as a GitHub Release.
- **Installing for the user.** The user downloads the DMG and drags Wobbo to Applications. If Wobbo is started from somewhere else, such as the disk image or Downloads, it offers to move itself to Applications.
- **Not notarized (for now).** The first open needs a one-time "Open Anyway" in System Settings → Privacy & Security. The release page and README explain this in plain steps.
- **Stable signing identity.** The release is signed with Wobbo's own self-signed certificate. macOS then keeps the Accessibility permission across updates.
- **Welcome and Connect to Claude Code.**
  - On first start a buddy named Wobbo walks in and offers "Connect to Claude Code".
  - Wobbo carries the Claude Code plugin inside the app and installs it with one click: Wobbo finds Claude Code itself.
  - The menu shows whether it is connected, and can connect or disconnect.
  - After a Wobbo update, Wobbo updates the plugin itself and tells the user to restart their sessions.
- **BREAKING: rename to Wobbo** wherever the user sees it:
  - the app and bundle name;
  - the menu ("Quit Wobbo");
  - the data folder `~/Library/Application Support/Wobbo/` (settings are copied once from the old `ClaudeBuddy` folder);
  - the bridge's texts;
  - the README.
- **BREAKING: the plugin is renamed** from `buddy-bridge` to `wobbo`, with marketplace `wobbo` and binary `wobbo-bridge`. The tool names Claude sees become `mcp__plugin_wobbo_wobbo__say` and `mcp__plugin_wobbo_wobbo__ask_user`. Connect replaces an existing `buddy-bridge` install, so sessions are not reported twice.
- **Open at Login.** A menu item registers Wobbo as a macOS login item.
- **One Wobbo at a time.** A second start quits at once. This includes an editor run while the app runs.
- **One version number.** The app and the plugin share one version: 0.2.0.

### Out of scope

- **Gatekeeper and updates:**
  - notarization and a Developer ID certificate (no paid Apple Developer account yet);
  - automatic app updates or an in-app update check.
- **Distribution:** an App Store or Homebrew build.
- **Claude Desktop:** setting up Claude Desktop (chat) automatically. Its MCP entry stays a documented manual step.
- **Renames:** the GitHub repository and the local project folder.
- **The overlay:** behaviour inside the overlay (buddies, balloons, moods), apart from the welcome buddy. The buddies keep their menu wording ("Show Buddies").
- **Accessibility:** a new flow for asking for it. Wobbo keeps asking only when the Dock hides automatically.

## Capabilities

### New Capabilities
- `app-distribution`: covers how Wobbo is built, signed and published, and how a user gets it running:
  - the DMG and the first open;
  - moving itself to Applications;
  - its name and stable identity towards macOS;
  - the data folder and the move from the old one;
  - one running instance.
- `claude-code-setup`: covers connecting Wobbo to Claude Code from the app:
  - the welcome on first start;
  - finding Claude Code;
  - installing the bundled plugin and replacing old installs;
  - keeping it up to date;
  - disconnecting;
  - the connection state in the menu.

### Modified Capabilities
- `menu-bar-control`: the menu names the app Wobbo ("Quit Wobbo") and lists the new items; adds "Open at Login".
- `overlay-window`: "Accessory app presence" names Wobbo and covers the exported app from its first moment.
- `agent-bridge`: "Installation" now happens from Wobbo instead of with commands. The bridge finds the app in the new data folder, with the old one as fallback, and its texts say Wobbo.

## Impact

- **Godot project:**
  - `project.godot`: name, data folder, icon, and a new first autoload for the single-instance check;
  - `menu_bar.gd`: Quit label, Open at Login, Claude Code item;
  - `settings.gd`: moving the settings file;
  - a welcome flow that reuses local sessions and balloon requests;
  - a Claude Code setup module that runs the `claude` CLI;
  - `export_presets.cfg` and an app icon.
- **Native extension:**
  - a universal release build;
  - new functions for the login item (`SMAppService`) and for moving the app bundle.
- **Bridge:**
  - the rename to plugin, marketplace and binary `wobbo`;
  - a universal binary;
  - the data folder with fallback;
  - the texts.

  The repository marketplace becomes `wobbo-dev`, for development.
- **New maintainer tooling:**
  - `tools/release.sh` (build, install locally, DMG, publish);
  - creating the self-signed "Wobbo" certificate once.
- **Prerequisites:**
  - the Godot 4.7.2 export templates (about 1 GB, installed once from the editor);
  - a **public** place for downloads, because the repository `timtim32/claude-buddy` is private. Either make it public or create a public releases repository. This is the user's choice before the first publish.
- **Existing users (the developer):** after installing Wobbo, the user clicks Connect, which replaces `buddy-bridge`, and grants Accessibility once to Wobbo instead of Godot.
