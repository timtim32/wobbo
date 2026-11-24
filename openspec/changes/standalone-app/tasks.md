# Tasks

## 1. Prerequisites (need the user)

- [x] 1.1 Ask the user to install the Godot 4.7.2 export templates: Godot editor → Editor → Manage Export Templates → Download and Install, about 1 GB. Do not download them without approval. Verify: `~/Library/Application Support/Godot/export_templates/4.7.2.stable/macos.zip` exists.
- [x] 1.2 Write `tools/make_signing_cert.sh` (design D2). It creates a self-signed code-signing certificate "Wobbo" in the login keychain and exports a `.p12` backup to a path given as an argument. Ask the user before running it, because it creates an identity in their keychain. Verify: `security find-identity -p codesigning` lists "Wobbo" (it may show as not trusted, which codesign accepts), and `codesign --sign Wobbo` signs a scratch binary.
- [x] 1.3 Ask the user where releases go: make the repository public, or create a public releases repository (design D12). Write the choice in `design.md`. Verify: the decision is recorded.
- [ ] 1.4 Manual check: the user sees the templates installed in Godot and the "Wobbo" certificate in Keychain Access, and has a safe copy of the `.p12`.

## 2. Rename and data folder

- [x] 2.1 In `project.godot`, set `config/name="Wobbo"` and `custom_user_dir_name="Wobbo"`. `menu_bar.gd` reads the Quit label from `application/config/name` (design D5). Verify: `game_eval` reads "Quit Wobbo", and `OS.get_user_data_dir()` ends in `/Wobbo`.
- [x] 2.2 Before loading, copy `settings.cfg` from `../ClaudeBuddy` when the new folder has none, and record whether this was a true first start (design D5). Put the paths and the decision in a pure helper. Verify: a headless test with temporary folders covers four cases:
  - only the old file (copied, not first start);
  - both files (no copy);
  - neither (first start);
  - an unreadable old file (defaults, no crash).
- [x] 2.3 Replace "Claude Buddy" with "Wobbo" in user-facing texts and the README, and update the main specs' Purpose lines. Verify: `grep -rn "Claude Buddy"` in `godot/scripts`, `bridge/src`, `bridge/plugin` and `README.md` finds only the deliberate mentions of the old folder.
- [ ] 2.4 Manual check: the user starts the project from the editor, keeps their old size and screen choice, and sees "Quit Wobbo" in the menu.

## 3. One running instance

- [x] 3.1 Add the `Instance` autoload as the first autoload (design D6). Put the decision (no file, own pid, dead pid, live pid with closed port, live pid with open port) in a pure function. Verify: headless tests for each case.
- [x] 3.2 Make Overlay, Bridge, the menu bar and the welcome return early when `Instance.duplicate` is true. Verify:
  1. with an editor run active, start `Godot --path godot` from the shell;
  2. it exits within a second with a log line;
  3. `bridge.json` and the running buddies are unchanged.
- [ ] 3.3 Manual check: the user kills Wobbo with `kill -9`, opens it again, and it starts normally.

## 4. Bridge rename and universal binary

- [x] 4.1 Look up `bridge.json` in `Wobbo`, then in `ClaudeBuddy`. `WOBBO_INFO` and `CLAUDE_BUDDY_INFO` override (design D8). Verify: `bun test` covers four cases:
  - only the new file;
  - only the old file;
  - the new file stale with the old one alive;
  - the overrides.
- [x] 4.2 Rename to Wobbo (design D8):
  - MCP server name `wobbo`;
  - tool titles, descriptions and result texts;
  - `print-config` entry `wobbo`;
  - binary `wobbo-bridge` (`package.json`, `main.ts` usage, `.gitignore`);
  - plugin `wobbo` (`plugin.json`, `hooks.json`, `.mcp.json`);
  - repository marketplace `wobbo-dev`.

  `build:plugin` removes a leftover `claude-buddy-bridge`. Verify: `bun test`, `bunx tsc --noEmit` and `bun run build:plugin` pass, and `bridge/plugin/bin/` holds only `wobbo-bridge`.
- [x] 4.3 Build a universal binary with `bun build --compile` for `bun-darwin-arm64` and `bun-darwin-x64`, then `lipo -create` (spike S4). Verify: `lipo -archs` shows both, and `wobbo-bridge --version` works natively and under `arch -x86_64`. If not, use the wrapper fallback and record it in `design.md`.
- [x] 4.4 Set the version to 0.2.0 in `src/protocol.ts`, `package.json` and `plugin.json`. The release script will overwrite it per release. Verify: `wobbo-bridge --version` prints 0.2.0.
- [ ] 4.5 Manual check: the user installs `wobbo@wobbo-dev` from the repository, starts a session with the editor-run Wobbo, sees a buddy, and `say` reports "Shown to the user in Wobbo."

## 5. Native additions

- [x] 5.1 Add `login_item_status()`, `set_login_item()` and `open_login_items_settings()` with `SMAppService`, linking `ServiceManagement` (design D7). Verify: `login_item_status()` from `game_eval` returns a known value.
- [x] 5.2 Add `bundle_location()` and `move_to_applications()` (design D7). Verify: from `game_eval` in an editor run, `bundle_location()` returns `elsewhere`. `move_to_applications()` is tested on a real bundle in group 9.
- [x] 5.3 Build universal debug and release frameworks with `arch=universal`. Verify: `lipo -archs` on both frameworks shows `x86_64 arm64`, and the headless tests and an editor run still work.
- [ ] 5.4 Manual check: the user runs the editor project, and the buddies and Dock dodging behave as before.

## 6. Claude Code setup

- [x] 6.1 Add the pure module `scripts/core/claude_setup_plan.gd` (design D9). It holds:
  - the CLI candidate order;
  - the argument lists for list, uninstall, marketplace add or update, install, update and remove;
  - parsing of `plugin list --json` into installed plugins and versions;
  - the decision of what to uninstall;
  - the first error line.

  Verify: headless tests with recorded `--json` output from `claude plugin list --json` (connected, not connected, `buddy-bridge` present, an older `wobbo`, a disabled `wobbo`) and a failing command.
- [x] 6.2 Add the `ClaudeSetup` node (design D9). It:
  - finds the CLI;
  - copies the payload to `user://claude-plugin/`;
  - runs connect, disconnect and update on a worker thread through an injected runner;
  - emits `state_changed`, `busy` and `finished(ok, message)`.

  Verify: headless tests with a fake runner check the order of commands for connect (with and without `buddy-bridge`), for disconnect and for update. A failure stops the sequence.
- [x] 6.3 Add the menu item "Connect to Claude Code…" / "Disconnect from Claude Code". Its state is read when the menu opens, with a 10 s cache. With output Off, results show in `OS.alert` (design D10). Verify: `game_eval` with a fake runner shows both labels and the alert path.
- [x] 6.4 Update on start: when connected and the installed version is older than the payload's, update and announce once (design D9). Verify: a fake-runner test from "older installed" to update commands to one announcement; nothing happens when the versions are equal.
- [ ] 6.5 Manual check (spike S5 included): the user, from the editor run, chooses Connect with the real CLI. `buddy-bridge` disappears and `wobbo@wobbo` appears in `claude plugin list`. A new Claude Code session (terminal and Claude app Code tab) appears once as a buddy. Disconnect removes it.

## 7. Welcome and moving

- [x] 7.1 Add the welcome flow (design D10): the local "Wobbo" session walks in on a true first start, offers Connect / Not now, shows progress and the result (or "Try again"), and walks off. Verify: `game_eval` after deleting `settings.cfg` in a scratch user folder shows the buddy and the balloon. A fake-runner connect ends with the buddy leaving; a second start shows no welcome.
- [x] 7.2 Add the "Claude Code not found" path: a balloon with the install link and "Try again". No files change. Verify: a fake runner with no CLI shows the balloon, and the payload folder is not created.
- [x] 7.3 Add the move offer: when `bundle_location()` is not `applications` in an exported run, the welcome buddy offers "Move to Applications" first, then relaunches or explains dragging (design D10). Verify: the pure decision is tested for the four locations; the real move is checked in group 9.
- [ ] 7.4 Manual check: the user deletes their Wobbo settings in a test account or scratch folder, starts Wobbo, and reads the welcome. "Not now" leaves the menu item on "Connect…".

## 8. Open at Login

- [x] 8.1 Add the checkable "Open at Login" item between the Claude Code item and "Debug regions" (design D7). It is enabled only in an exported bundle in Applications; its check mark comes from `login_item_status()` when the menu opens; it opens Login Items on `requires_approval`. Verify: headless tests for the pure enabled/checked helper. In an editor run the item shows disabled.
- [ ] 8.2 Spike S1, once group 9 produces an installed app: turn the item on, then check `login_item_status()` and System Settings → Login Items. If it fails for this signature, implement the LaunchAgent fallback and record it in `design.md`. Verify: Wobbo is listed under Login Items, or `launchctl print gui/$(id -u)/io.github.timtim32.wobbo` shows the agent.
- [ ] 8.3 Manual check: the user turns it on, logs out and in, and Wobbo starts. The user turns it off in System Settings, and the menu shows it unchecked.

## 9. Export and release

- [x] 9.1 Render `godot/assets/app_icon.png` (1024×1024) from `art/monster/monster.svg` with a tool script (design D11). Verify: the PNG exists and shows the monster's head.
- [x] 9.2 Add `godot/export_presets.cfg` with a "macOS" preset (design D3, D4):
  - bundle id `io.github.timtim32.wobbo`;
  - name Wobbo;
  - universal;
  - `LSUIElement`, and `LSMinimumSystemVersion` 13.0;
  - the icon;
  - codesign off;
  - `tests/*` and `tools/*` excluded.

  Verify: a headless export produces a bundle. Its `Info.plist` has the name, id and `LSUIElement`, and `lipo -archs` on the executable shows both architectures.
- [x] 9.3 Write `tools/release.sh` with `build`, `install`, `publish` and `--debug` (design D1, D2, D4), and add `/build/` to `.gitignore`. `build` writes the version, builds the frameworks and the bridge, exports, copies the payload, signs and makes the DMG. Verify:
  - `codesign --verify --strict --verbose=2 build/Wobbo.app` passes, and `codesign -dv` shows authority "Wobbo";
  - `Contents/Resources/claude-plugin/plugins/wobbo/bin/wobbo-bridge` is signed;
  - the DMG mounts and shows Wobbo next to an Applications link;
  - without templates, the script stops with the message and leaves no `build/Wobbo.app`.
- [ ] 9.4 Spike S3: run `build/Wobbo.app/Contents/MacOS/Wobbo` from the terminal with `--debug`. Check the log: the extension loads, the bridge listens in `~/Library/Application Support/Wobbo/` and the voices are listed. Then copy the DMG with a quarantine attribute (`xattr -w com.apple.quarantine …`) and test the move from the mounted image. Record the outcomes and any fallback in `design.md`. Verify: the log lines, and `bun bridge/scripts/fake_sessions.ts` shows buddies in the exported app.
- [x] 9.5 Write the user part of the README ("Install Wobbo": download, drag, first open with "Open Anyway", Connect, Accessibility, Open at Login, update, uninstall), the maintainer part ("Making a release") and a release-notes template that `publish` uses. Verify: the user part contains no terminal commands, and the maintainer commands run as written.
- [ ] 9.6 Manual check: the user installs from `build/Wobbo.dmg` the way a new user would, by dragging to Applications. The checks:
  - opening shows no Dock icon;
  - the welcome connects to Claude Code;
  - Accessibility is asked for as "Wobbo";
  - speech works.

## 10. Updates and release

- [ ] 10.1 Spike S2: with Accessibility granted, bump the version, rebuild and install over the existing app. Check that the log says "Dock from its Accessibility frame" without a new prompt, and that the plugin update balloon appears. If Accessibility is lost, record the fallback in `design.md` and the release-notes template. Verify: the log and the balloon.
- [x] 10.2 Run all checks: the Godot headless tests, `bun test`, `bunx tsc --noEmit` and `openspec validate standalone-app --strict`. Verify: all pass with no new failures.
- [ ] 10.3 Only on the user's explicit go-ahead: `tools/release.sh publish 0.2.0` to the chosen public location (task 1.3). Verify: the release page shows `Wobbo.dmg` and the install steps, and the download works when logged out of GitHub.
- [ ] 10.4 Manual check: the user downloads the DMG from the release page in a browser, as a new user would, and gets from download to a buddy for a new Claude Code session without a terminal.

## Workflow follow-up

- Archive the change once the manual checks are done.
- Later: notarization when a Developer ID account exists, and an update check.
