# Design

## Context

- **Engine.** Godot 4.7.2 (`4.7.2.stable.official`), GL Compatibility, macOS only. The custom headless test runner is `godot/tests/run_tests.gd` (a `SceneTree` script).
- **Export.** One macOS preset in `godot/export_presets.cfg` with `export_filter="all_resources"` and `exclude_filter="tests/*, tools/*"`. `tools/release.sh` exports it, then signs the app and builds the DMG.
- **Vendored addon.** `godot/addons/godot_ai/` (MIT, v4.4.1) is an editor plugin that is enabled in `project.godot`. It also registers the autoload `_mcp_game_helper` (`runtime/game_helper.gd`), which adds a logger and runs `_process`. The developer uses it from the editor through the godot-ai MCP server.
- **Debug features.** "Debug regions" is a checkable item in the menu bar menu and a saved setting. It shows the region overlay, the debug session panel, and an avatar menu item that opens `scripts/debug/debug_text_field.gd` (marked temporary).
- **Permission prompts.** `describePermission()` in `bridge/src/adapters/claude_code.ts` builds a one-line description from the first known text field and cuts it at 300 characters. The app shows it in a balloon with Allow and Deny.
- **Audit.** `docs/open-source-readiness.md`, findings H1–H8.

## Goals / Non-Goals

**Goals:**
- What ships to users is only what users need.
- A newcomer's first clone, import and test run succeed, and a green test run can be trusted.
- The app never offers Allow for something it did not show in full.
- Anyone can see what licences apply, in the repository and in the app.

**Non-Goals:**
- Changing how the app looks or behaves for users, apart from the debug items and the permission fallback.
- Refactoring for its own sake (see the proposal's out-of-scope list).
- Editing vendored code.

## Decisions

### D1. Keep the addon in the repository, keep it out of releases

The addon stays committed, because the editor workflow depends on it and removing it would make a fresh clone fail to load `project.godot`. Releases leave it out:

- `addons/godot_ai/*` is added to the preset's `exclude_filter`, together with `characters/monster/*_preview.tscn`;
- the `_mcp_game_helper` autoload must not be registered in an exported build.

*Spike S1:* check whether an autoload whose script is excluded from the export is skipped without an error at start-up in a 4.7.2 release build. If it errors, choose one of two fallbacks:

- the preferred one: remove the autoload from `project.godot` and let the editor plugin add it while it is enabled (`add_autoload_singleton` in `_enable_plugin`), which is what the addon does when it is first enabled;
- a small `EditorExportPlugin` in `godot/addons/macos_overlay/` that strips the autoload line from the exported `project.binary`.

Record the outcome here.

**Result S1 (2026-11-24):** the addon already strips its own autoload at export: `addons/godot_ai/export/mcp_export_plugin.gd` removes `autoload/_mcp_game_helper` in `_export_begin`, and a baseline release export has no `_mcp_game_helper` in its settings. What did ship were the addon's files (701 path strings in the pack) and the preview scenes. With `addons/godot_ai/*` and `characters/monster/*_preview.*` in `exclude_filter`, the pack shrinks from 2.36 MB to 0.95 MB. The only `godot_ai` string left is `plugin.cfg` in the editor-plugin list, which a game run ignores. The exported app starts without autoload errors. No fallback is needed: `project.godot` stays as it is.

*Alternative rejected:* git-ignoring the addon and asking contributors to install it. It would break the editor run for everyone who doesn't, and the autoload line would point at a missing file.

### D2. Debug items only in debug builds

`OS.is_debug_build()` is true in the editor and in debug exports, and false in release exports. The menu adds "Debug regions" only when it is true. `AvatarManager` adds "Type here (debug)" only when it is true. The saved `debug_regions` setting is read as `false` in release builds, so an old setting can't turn the overlay on. The temporary text field and its item are removed outright: the balloons' own text field replaced it.

### D3. A script error fails the test

Godot 4.5+ lets a script register a `Logger` (`OS.add_logger`), which receives script errors. The runner adds a logger that counts errors. It resets the count before each test, and after the test it adds a failure "script error: <message>" when the count went up. Tests stay synchronous. A test method that returns a coroutine (it uses `await`) is reported as a failure with that reason. The runner also checks for `res://.godot/global_script_class_cache.cfg`. When the file is missing, it prints "Run once: Godot --headless --path godot --import" and exits 1 before running anything.

*Assumption:* `Logger._log_error` is called for errors raised by `call()` on a script method in a headless `SceneTree` script. This is verified by group 3's first task, with a deliberately failing test.

### D4. Permission prompts the app can't show in full go to Claude Code

`describePermission()` returns the text and whether it is complete. A description is incomplete when:

- it was cut at the 300-character limit; or
- the tool input has more than one string or object field besides a known description field. For example, an MCP call with several arguments, or an edit whose new content is not shown.

For an incomplete description the bridge sends no permission request to the app and returns no decision, so Claude Code shows its own prompt at once. The session's Wobbo still jumps for attention through the normal "waiting" state.

*Alternative rejected:* showing an "Answer in the session" balloon without Allow. That needs a new request kind in the app and protocol, which is more change for the same safety.

### D5. Third-party notices in two places

`THIRD_PARTY_NOTICES.md` at the repository root lists each bundled component, its licence and where its full text is:

- Godot engine and its third-party components (from the engine's `COPYRIGHT.txt`);
- godot-cpp;
- the godot_ai addon (repository only, after D1);
- Baloo 2;
- the Bun runtime with JavaScriptCore;
- the bridge's npm runtime dependencies.

`tools/release.sh` copies it into `Wobbo.app/Contents/Resources/`. How the LGPL terms for JavaScriptCore in a Bun single-file binary are met is checked and written down in the file. If the terms need more (for example a written offer or relinkable objects), that is reported to the user before release.

### D6. Spec deltas and standalone-app

This change modifies only the "Debug regions toggle" requirement of `menu-bar-control`. The "Menu bar icon" requirement, which lists "Debug regions" among the items, is also being modified by `standalone-app`. To avoid two conflicting deltas, this change leaves it alone. Whichever of the two changes is archived second updates that scenario, so that it no longer lists "Debug regions".

### D7. Fork-safe release script

`tools/release.sh publish` requires `WOBBO_RELEASE_REPO` to be set, or derives it from the `origin` remote. It exits with an error instead of creating a repository when the target doesn't exist. The maintainer's own command in `DEVELOPMENT.md` becomes an example with the variable set.

## Risks / Trade-offs

- [The autoload strategy (D1) changes how the editor plugin is wired] → Spike S1 first. The fallback keeps the editor workflow, and a manual check confirms the MCP server still attaches from the editor.
- [Stricter tests (D3) may expose existing hidden failures] → That is the point. Any test that now fails is fixed in the same pull request, or reported if the fix changes behaviour.
- [Fewer permission prompts in the app (D4)] → This only affects long or multi-argument prompts. Short commands and file paths keep working in the balloon.
- [CI on a hosted macOS runner needs Godot 4.7.2 and its import step] → The workflow caches the Godot download. The native extension is not built in CI, because the app and tests run without it (with a warning).
- [LGPL review (D5) might find obligations that need more work] → It is reported before the release, not guessed.

## Open Questions

- Should the trailer GIF and MP4 (7 MB) stay in `docs/images/`, or move to release assets?
- Are issue templates wanted now, or after the first outside issue?
