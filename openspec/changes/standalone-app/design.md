# Design

## Context

- **Engine and machine.** Godot 4.7.2 (`4.7.2.stable.official`), GL Compatibility. The development Mac runs macOS 27 on arm64.
- **No export setup yet.** There is no `export_presets.cfg`, and no export templates are installed.
- **Native extension.** `addons/macos_overlay` is a GDExtension in Objective-C++. Only its arm64 `template_debug` framework is built; `macos_overlay.gdextension` already names a `template_release` framework.
  - It sets the accessory activation policy at runtime.
  - It reads the Dock frame through Accessibility. It asks for that only when the Dock hides automatically.
  - It activates other apps with `NSRunningApplication` (no Apple Events).
- **Data folder.** `project.godot` sets `config/name="Claude Buddy"` and `custom_user_dir_name="ClaudeBuddy"`. `Settings` reads `user://settings.cfg`. `Bridge` writes `bridge.json` (port, token, pid).
- **Autoloads.** The order is Settings, Overlay, Bridge, `_mcp_game_helper`. The last one comes from the godot-ai addon and does nothing without a debugger connection.
- **Local sessions.** `BridgeServer.local_event()` and `local_request()` let the app create sessions and requests without a bridge connection. The demo uses them, and the welcome buddy will reuse them.
- **Bridge (Bun).**
  - It is a single compiled binary. It reads `~/Library/Application Support/ClaudeBuddy/bridge.json`, and `CLAUDE_BUDDY_INFO` overrides the path.
  - The plugin `buddy-bridge` (MCP server `buddy`) is offered by the repository marketplace `buddy-local`. The binary in `bridge/plugin/bin/` is built locally and not committed.
- **Claude Code CLI.**
  - On this Mac it lives at `~/.local/bin/claude`. The Claude desktop app also keeps one under `~/Library/Application Support/Claude/claude-code/<version>/`.
  - `claude plugin marketplace add <path>`, `claude plugin install`, `claude plugin list` and related commands support `--json`.
- **Signing.** There is no Developer ID; only an Apple Development identity is present. That identity is meant for development on the developer's own devices and is not used for releases.
- **Repository.** `timtim32/claude-buddy` is private.

## Goals / Non-Goals

**Goals:**
- A user goes from download to buddies by clicking only. The maintainer has one script for everything else.
- Editor runs keep working for development and share the data folder with the app.
- Each release carries its own plugin, so the app and the plugin versions can never drift apart.

**Non-Goals:**
- Building in CI. Releases are built on the maintainer's Mac, which holds the signing identity.
- Fixing Gatekeeper without notarization. The design only makes the first open as clear as possible.

## Decisions

### D1. `tools/release.sh`: one maintainer script
Subcommands:
- **`build <version>`** does, in order:
  1. checks for the templates;
  2. writes the version into the app and the plugin;
  3. builds the universal extension (`scons -C native target=template_release arch=universal`);
  4. builds the universal bridge (D8);
  5. exports;
  6. copies the plugin payload into the bundle (D4);
  7. signs (D2);
  8. makes the DMG in `build/`.
- **`install`** copies `build/Wobbo.app` to `/Applications` when Wobbo is not running, and otherwise stops with "Quit Wobbo first". This is for the maintainer's own testing.
- **`publish <version>`** runs `gh release create v<version> build/Wobbo.dmg --notes-file …`. It is never part of `build`; it only runs when the maintainer asks.
- **`--debug`** makes a debug export with stdout logging, for troubleshooting.

Godot exports headless: `Godot --headless --path godot --export-release "macOS" build/Wobbo.app`.

The DMG is made with `hdiutil create` from a folder that holds `Wobbo.app` and a symlink to `/Applications`. It has no custom background, which keeps it simple.

*Alternative:* GitHub Actions on a macOS runner. That would put the signing certificate's private key in CI secrets, and add a ~1 GB template download to every run. It is not worth it for occasional releases.

### D2. Signing with a self-signed "Wobbo" certificate
A one-time helper, `tools/make_signing_cert.sh`, creates a self-signed code-signing certificate named "Wobbo" in the maintainer's login keychain. It exports a `.p12` backup to a location the maintainer chooses, outside the repository.

`release.sh` signs in this order:
1. the extension frameworks;
2. the `wobbo-bridge` binary in the plugin payload;
3. the app.

It uses `codesign --force --sign "Wobbo" --timestamp=none`, without `--deep`. The hardened runtime and entitlements are off, because nothing is notarized.

The designated requirement is then the bundle id plus the certificate. TCC keeps Accessibility across releases signed with the same certificate (spike S2). When the identity is missing, the script signs ad hoc and warns (spec "Name and identity towards macOS").

*Alternatives:*
- **Ad hoc for releases.** The designated requirement then changes with every build, so users would re-grant Accessibility after each update.
- **Apple Development.** That certificate is not meant for distribution, and Gatekeeper treats it the same as self-signed.

### D3. Bundle settings
- **Bundle id:** `io.github.timtim32.wobbo`. It must never change, because TCC and login items are tied to it.
- **Name:** `CFBundleName` and the display name are Wobbo.
- **Version:** `CFBundleShortVersionString` is the release version.
- **Architecture:** universal.
- **Plist additions:**
  - `LSUIElement` true, so there is no Dock icon from launch (spec "Accessory app presence"). The runtime call stays for editor runs.
  - `LSMinimumSystemVersion` 13.0, for `SMAppService`.
- **Signing in Godot:** off (D2).

### D4. What the bundle contains
- **Exclusions:** the export filter excludes `tests/*` and `tools/*`.
- **godot-ai helper:** stays, because it is an autoload. It does nothing without a debugger, and editor plugins are never loaded in an export.
- **Plugin payload:** after the export, `release.sh` copies the built plugin (`bridge/plugin`: manifest, hooks, `.mcp.json`, `bin/wobbo-bridge`) into `Wobbo.app/Contents/Resources/wobbo-plugin/`, with the same version as the app. The app builds the one-plugin marketplace around it when it copies the plugin out (D9). In an editor run, `bridge/plugin` itself is the source, after `bun run build:plugin`.

### D5. Data folder and migration
- `config/name` and `custom_user_dir_name` become "Wobbo".
- `Settings` copies `../ClaudeBuddy/settings.cfg` before loading when `user://settings.cfg` is missing, and logs it. It records whether this was a true first start, with neither file present, for the welcome (D10).
- The menu reads the app name from `application/config/name`.

### D6. Single instance
A new first autoload, `Instance`, reads `user://bridge.json`. It treats another instance as alive only when both hold:
1. the pid is not this process and is running;
2. `127.0.0.1:<port>` accepts a TCP connection within 200 ms. This covers a reused pid.

If another instance is alive, it sets `duplicate`, logs the reason and calls `get_tree().quit()`. Overlay, Bridge, the menu bar and the welcome check `Instance.duplicate` first and do nothing, so no window, icon or file write happens before the quit.

*Alternative:* `OS.kill` on itself. An editor run would show it as a crash.

### D7. Native additions
- **Login item.** `login_item_status()`, `set_login_item(bool)` and `open_login_items_settings()` wrap `SMAppService.mainAppService` and `openSystemSettingsLoginItems`. The extension links `ServiceManagement`.
- **App location.** `bundle_location()` returns one of four values:
  - `applications`: inside `/Applications` or `~/Applications`;
  - `translocated`: the path holds `/AppTranslocation/`;
  - `disk_image`: on a read-only volume under `/Volumes`;
  - `elsewhere`.
- **Moving the app.** `move_to_applications()` copies the bundle to `/Applications/Wobbo.app` with `NSFileManager`. It replaces an older copy only when no Wobbo runs from there, opens the new copy with `NSWorkspace`, and returns success so the caller can quit.
- **Menu item states.**
  - "Open at Login" is enabled only when `OS.has_feature("template")` and `bundle_location()` is `applications`. Its check mark is refreshed from `login_item_status()` when the menu opens. On `requires_approval` the menu opens Login Items.
  - The enabled and checked logic sits in pure helpers.

### D8. Bridge rename and universal binary
- **Names.**
  - plugin `wobbo`;
  - MCP server `wobbo`, so the tools are `mcp__plugin_wobbo_wobbo__say` and `mcp__plugin_wobbo_wobbo__ask_user`;
  - marketplace `wobbo` in the app payload, `wobbo-dev` in the repository;
  - binary `wobbo-bridge`.
- **Tool descriptions and texts** say Wobbo. The Claude Desktop entry printed by `print-config` is named `wobbo`.
- **Finding the app.** `infoPaths()` returns `Wobbo/bridge.json`, then `ClaudeBuddy/bridge.json`. `WOBBO_INFO` overrides both, and `CLAUDE_BUDDY_INFO` is still honoured. The first file that is valid and alive wins.
- **Universal binary.** `bun build --compile` runs for `bun-darwin-arm64` and `bun-darwin-x64`, and `lipo -create` joins them (spike S4).
- **Version.** It is shared with the app: 0.2.0. The protocol does not change.

### D9. Claude Code setup (`ClaudeSetup` node, Godot)
- **Finding the CLI.** The first executable found wins:
  1. `~/.local/bin/claude`;
  2. `~/.claude/local/claude`;
  3. `/opt/homebrew/bin/claude`;
  4. `/usr/local/bin/claude`;
  5. the result of `/bin/zsh -lc 'command -v claude'`, the user's login PATH;
  6. the newest `~/Library/Application Support/Claude/claude-code/*/claude`, the desktop app's copy (spike S5).
- **Payload in a stable place.** Before installing, the plugin payload is copied from the bundle to `user://claude-plugin/` (`~/Library/Application Support/Wobbo/claude-plugin/`). A translocated or disk-image path would vanish. Godot's own file copy does not carry quarantine attributes over.
- **Connect** runs these steps in a worker thread, each with `--json`, and checks the exit code:
  1. `plugin list` to find what is installed;
  2. uninstall `buddy-bridge@*` and any `wobbo@` from another marketplace;
  3. `marketplace add <payload>` or `marketplace update wobbo`;
  4. `plugin install wobbo@wobbo`.

  Results come back to the main thread through `call_deferred`.
- **State.** Connected means `wobbo@wobbo` is installed and enabled. It is read with `plugin list --json` when the menu opens, cached for 10 s so the menu stays quick.
- **Update on start.** When connected and the installed version is older than the bundle's, ClaudeSetup refreshes the payload and runs `marketplace update wobbo` and `plugin update wobbo@wobbo`. It then announces this once (spec "Keeping the plugin current").
- **Disconnect.** `plugin uninstall wobbo@wobbo`, then `marketplace remove wobbo`.
- **Found on the way (2026-11-24):** two traps hid every Connect step behind a fake "ok".
  - `OS.execute()` with captured output runs the command line through `/bin/sh` (popen), and Godot quotes the arguments without escaping. The run script's `"$1"` and `"$@"` were expanded by sh, so each `claude` command became an empty `exec`. ClaudeSetup now escapes `\`, `$`, backticks and `"` itself. A test runs the real `execute()`.
  - Started from inside a Claude Code session, Wobbo inherits `CLAUDECODE`, `CLAUDE_CODE_SESSION_ID` and similar variables, and the CLI then acts as part of that session. The run script unsets every `CLAUDE*` variable except `CLAUDE_CONFIG_DIR`.
- **Testing.** Command building and output parsing are pure functions (`scripts/core/claude_setup_plan.gd`), tested headless with recorded `--json` output. The process runner is injected, so tests never touch the real Claude Code configuration.

*Alternative:* editing `~/.claude/settings.json` directly (`extraKnownMarketplaces`, `enabledPlugins`). That means merging JSON into the user's own file, and it would break silently if Claude Code changes its format. The CLI is the supported way.

### D10. Welcome and setup conversations
- **The welcome buddy.** It is a local session (agent `wobbo`, name "Wobbo") created with `local_event`. Its questions are local requests with choices:
  - "Connect to Claude Code" / "Not now";
  - "Move to Applications" / "Not now";
  - "Try again".

  After the last answer it ends the session, so it walks off. Its buddy always has the original green (`AvatarCast.OWN_HUE`, hue 97.6), also when a session already wears green. The Messages module routes answers to local requests back to the welcome flow, like the demo's.
- **When it appears:**
  - Move first: when `bundle_location()` is not `applications`, it offers to move. It says "Drag Wobbo to Applications" when the move fails.
  - Connect: on a true first start (D5), and always after a menu "Connect…". In that case the buddy appears just to report progress and the result.
  - Connect offer on later starts: while not connected and the user never answered "Not now" (setting `connect_declined`), for example after an upgrade from Claude Buddy, where the copied settings mean it is no first start. Found when the first installed build showed no welcome.
- **Output Off.** When the user's Messages output is Off, balloons do not show. Setup results from the menu then use a native alert (`OS.alert`), so connecting never fails silently.

### D11. App icon
`godot/assets/app_icon.png` (1024×1024) is rendered from `art/monster/monster.svg` by a tool script, like `export_monster.gd`. The preset uses it, and Godot builds the `.icns`. The menu bar icon is unchanged.

### D12. Download location
Releases need a public download page. The repository is private, so before the first `publish` the maintainer chooses one of two:
- make `timtim32/claude-buddy` public;
- create a public `wobbo` repository for releases only.

`release.sh publish` takes the repository from `WOBBO_RELEASE_REPO`, defaulting to the current one. The approach is the same either way.

**Decided (2026-11-24):** a new public repository `timtim32/wobbo`, used only for releases and install instructions; the code stays private. It is created at the first publish, so `WOBBO_RELEASE_REPO` defaults to `timtim32/wobbo`.

**Superseded (2026-11-24):** the code became open source (MIT) in `timtim32/wobbo` itself; the private `timtim32/claude-buddy` is kept as an archive. Releases still go to `timtim32/wobbo`.

## Spikes

- **S1. Login item for a self-signed, not notarized app.** Expected: `SMAppService.mainAppService register` works for an app in `/Applications`, possibly after approval in Login Items.
  - *Fallback:* a LaunchAgent plist with `RunAtLoad` that opens `/Applications/Wobbo.app`, behind the same menu item.
- **S2. Accessibility survives an update.** Expected: TCC stores the designated requirement, which for a self-signed certificate is the bundle id plus the certificate. A new release with the same id and certificate keeps the grant.
  - *Fallback:* say in the release notes that Accessibility is asked again after an update. The pointer fallback for the Dock keeps working until then.
- **S3. Extension, TTS and the move in the exported app.**
  - The signed framework must load.
  - `DisplayServer.tts_*` must find voices.
  - A copy moved out of the disk image must start without a new Gatekeeper block.

  *Fallbacks:*
  - extension: add `com.apple.security.cs.disable-library-validation`;
  - TTS: none needed, because the speech items are already disabled without voices;
  - move: if the moved copy is blocked again, drop the automatic move and only tell the user to drag it.
  - **Outcome (2026-11-24), partly done:** the exported app started from the terminal:
    - the extension loaded (`MacOverlay active`);
    - the bridge listened and wrote `~/Library/Application Support/Wobbo/bridge.json`;
    - fake sessions appeared as buddies;
    - the welcome buddy came out.

    A release build buffers its stdout (`application/run/flush_stdout_on_print` is off), so `release.sh build --debug` is the way to read the log. Still open: speech in the exported app, and moving from a quarantined disk image. Both need the user's first open through Gatekeeper.
  - **Found on the way:** the balloon's tail rendered black on the second display's strip, the LG, but white on the laptop's. It was drawn with `draw_colored_polygon`. An explicit white texture fixed the editor run but not the exported app. The tail is now drawn with `canvas_item_add_triangle_array` and a colour per corner, the way StyleBoxFlat draws the panel. Checked by capturing the LG strip window of the installed app (`screencapture -l`): the tail pixels are white.
- **S4. Universal bridge binary.** `lipo` of two `bun --compile` binaries must run on both architectures, which can be checked with `arch -x86_64`.
  - *Fallback:* ship both binaries plus a small `wobbo-bridge` shell wrapper that picks one by `uname -m`.
  - **Outcome (2026-11-24):** `lipo -create` works. `lipo -archs` shows `x86_64 arm64`, the arm64 slice runs, and both slices are byte-identical to the single-architecture builds, so `lipo` keeps Bun's embedded code intact. The x86_64 slice was not run, because the development Mac has no Rosetta; check it once on an Intel Mac or with Rosetta installed.
- **S5. The desktop app's Claude Code copy.** Can it run `plugin install`, and do Code-tab sessions in the Claude desktop app load user plugins installed this way? This Mac's own sessions suggest yes.
  - *Fallback:* without a CLI in candidates 1–5, report "Claude Code not found" with the install link.

## Risks / Trade-offs

- **[Gatekeeper's "Open Anyway" puts some users off]** → Plain steps with screenshots in the README and the release notes. Notarization can follow when a Developer ID exists; the release script then only gains a signing identity and a `notarytool` step.
- **[Claude Code changes its `plugin` CLI or JSON output]** → Connect checks exit codes and shows Claude Code's first error line with "Try again". The parsing lives in one tested module.
- **[Losing the "Wobbo" certificate]** → A new certificate makes every user re-grant Accessibility once. `make_signing_cert.sh` exports a `.p12` backup, and the README tells the maintainer to keep it safe.
- **[Editor run while the app runs]** → The editor run quits (D6) and its log says to quit Wobbo first.
- **[The plugin keeps working with an old app, or the reverse]** → The protocol is unchanged. The bridge also reads the old folder (D8).
- **[Two plugins after connecting]** → Connect uninstalls `buddy-bridge` and foreign `wobbo` installs first (spec "No double reporting").

## Migration Plan

**The maintainer, once:**
1. Install the export templates from the Godot editor.
2. Run `tools/make_signing_cert.sh` and keep the `.p12` backup safe.
3. Choose the public download location (D12).

**Per release:**
1. `tools/release.sh build <version>`.
2. Test with `install`.
3. Run `publish` when satisfied.

**The developer's own setup:**
1. Install Wobbo.
2. Open it.
3. Click Connect. This replaces `buddy-bridge`.
4. Grant Accessibility to Wobbo, and remove the old "Godot" entry if you like.
5. Restart sessions.

**Rollback:**
1. Choose "Disconnect from Claude Code" and delete Wobbo.app.
2. Check out the previous commit.
3. Reinstall `buddy-bridge` from `buddy-local`.

The old `ClaudeBuddy` folder still has the old settings.
