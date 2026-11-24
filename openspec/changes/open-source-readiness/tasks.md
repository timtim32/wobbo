# Tasks

Findings (H1–H8) are in `docs/open-source-readiness.md`. Each numbered group is one pull request. Groups 1 to 5 come before publication. Groups 6 and 7 are strongly recommended, and group 8 is optional. Mind the order relative to `standalone-app` (proposal, Impact).

Commands used below:
- **Godot suite:** `/Applications/Godot.app/Contents/MacOS/Godot --headless --path godot --script res://tests/run_tests.gd` (must end with `0 failed`).
- **Bridge checks:** `cd bridge && bun test && bunx tsc --noEmit`.
- **Fresh clone:** `git clone <repo> /tmp/wobbo-check && cd /tmp/wobbo-check && git submodule update --init --recursive`.

## 1. Review (needs the user)

- [x] 1.1 Manual check: the user reads `docs/open-source-readiness.md` and this change, and agrees with the scope and order.

## 2. Release hygiene (H1)

- [x] 2.1 Spike S1 (design D1): export a release build with `addons/godot_ai/*` excluded. Check whether the app starts without errors about `_mcp_game_helper`. Record the outcome and the chosen autoload approach in `design.md`. Verify: the log of the exported app, run with `--verbose`.
- [x] 2.2 Add `addons/godot_ai/*` and `characters/monster/*_preview.tscn` to `exclude_filter`, and apply the autoload approach from 2.1. Verify: an exported build's `.pck` contains no `addons/godot_ai` or `_preview` files (list it with `--headless --pck-list` or by unpacking); the Godot suite passes.
- [x] 2.3 Show "Debug regions" in the menu and "Type here (debug)" on avatars only when `OS.is_debug_build()`, and read `debug_regions` as false in release builds (design D2). Verify: a test for the settings fallback; in an editor run both items are present.
- [x] 2.4 Remove `scripts/debug/debug_text_field.gd` and its menu item and region. Verify: `git grep -n "debug_text_field\|Type here (debug)"` finds nothing; the Godot suite passes.
- [x] 2.5 Correct the "stripped on export" lines in `docs/codebase-audit.md` (lines 115 and 585) to describe what 2.2 does. Verify: the diff touches only those lines.
- [ ] 2.6 Manual check: the user builds with `tools/release.sh build`, installs it and opens the menu: there is no "Debug regions", and right-clicking a Wobbo shows no debug item. In the editor, the godot-ai MCP server still attaches.

## 3. Trustworthy tests (H2, H3)

- [x] 3.1 Add a temporary test that calls a missing method. Confirm that the current runner prints `ok` for it. Verify: the output shows the false pass.
- [x] 3.2 Add an error-counting `Logger` to `run_tests.gd`, and fail a test whose count went up or that returns a coroutine (design D3). Remove the temporary test. Verify: with the temporary test the run fails with "script error"; without it the Godot suite passes.
- [x] 3.3 Make the runner exit 1 with the import hint when `res://.godot/global_script_class_cache.cfg` is missing. Verify: on a fresh clone without import, the run prints the hint and exits 1, and after `--import` it passes.
- [x] 3.4 Document in `docs/DEVELOPMENT.md` ("Tests") that a fresh clone is imported once, and that tests are synchronous. Verify: following the section on a fresh clone gives `0 failed`.
- [ ] 3.5 Manual check: the user breaks a test on purpose and sees it fail, then restores it.

## 4. Safer permission balloons (H4)

- [x] 4.1 Make `describePermission()` also report whether the description is complete (design D4). Add tests for a long Bash command, an MCP call with several arguments, an Edit with content, and a short command. Verify: bridge checks pass.
- [x] 4.2 In the `PermissionRequest` hook, send nothing to the app for an incomplete description and leave the decision to Claude Code, while the session still shows "waiting". Verify: a test with the fake app receives no request for a long command, and one for a short command.
- [x] 4.3 Update `bridge/PROTOCOL.md` or `DEVELOPMENT.md` where the permission behaviour is described. Verify: the text matches 4.2.
- [ ] 4.4 Manual check: in a Claude Code session, ask for a command longer than 300 characters. Claude Code shows its own prompt and the Wobbo jumps. A short command still shows Allow and Deny in the balloon.

## 5. Licensing paperwork (H5)

- [x] 5.1 Write `THIRD_PARTY_NOTICES.md` (design D5) from the engine's `COPYRIGHT.txt`, godot-cpp, godot_ai, Baloo 2, Bun and the bridge's runtime dependencies in `bun.lock`. Verify: every component in the audit's licensing table is listed with its licence.
- [x] 5.2 Check the LGPL terms for JavaScriptCore in a Bun-compiled binary, and write the outcome in the notices. Report anything beyond a notice to the user. Verify: the notice states the outcome and its source.
- [x] 5.3 Copy the notices into `Wobbo.app/Contents/Resources/` in `tools/release.sh`. Verify: after `tools/release.sh build`, the file is inside the app.
- [x] 5.4 Name `godot/characters/monster/` (scenes and clips) and `godot/assets/monster/manifest.json` explicitly in `ARTWORK.md`, and add a short "Using your own art" note (what to replace, and the export script). Verify: every tracked file under `art/`, `godot/assets/`, `godot/characters/monster/` and `docs/images/` falls clearly under one of LICENSE, ARTWORK.md or a third-party licence.
- [ ] 5.5 Manual check: the user reads `ARTWORK.md` and `THIRD_PARTY_NOTICES.md`, and agrees they say what they intend.

## 6. Contributor workflow (H6)

- [ ] 6.1 Add `.github/workflows/ci.yml` on a hosted macOS runner. It runs the bridge checks, downloads Godot 4.7.2 (cached), imports the project and runs the Godot suite. Verify: the workflow passes on a branch, and fails when a test is broken on purpose.
- [ ] 6.2 Make `tools/release.sh publish` require `WOBBO_RELEASE_REPO` (or derive it from `origin`), and fail instead of creating a repository (design D7). Update the example in `DEVELOPMENT.md`. Verify: `publish` without the variable in a fork exits with a clear message and creates nothing.
- [ ] 6.3 Add `*.p12`, `*.pem`, `.env`, `*.log`, `.vscode/` and `.idea/` to `.gitignore`. Verify: `git status --ignored` lists nothing new that should be tracked.
- [ ] 6.4 Manual check: the user opens a test pull request and sees the CI check run.

## 7. Docs for newcomers (H7)

- [ ] 7.1 Add a "First hour" section at the top of `docs/DEVELOPMENT.md`: prerequisites, clone with submodules, import, tests, run. Verify: a fresh clone following only that section reaches a passing test run and a running app.
- [ ] 7.2 Move the "The Wobbos" behaviour reference out of `DEVELOPMENT.md`, keeping a link. It goes into the matching specs, or a short `docs/behaviour.md`. Verify: no behaviour detail is lost; links resolve.
- [ ] 7.3 Mark `docs/codebase-audit.md` as a historical snapshot at its top, with a link to the archived `codebase-cleanup` change. Verify: the first lines say so.
- [ ] 7.4 Complete the README "Privacy" section: the log folder and what it holds, permission details in balloons and speech, the login item, and the move-to-Applications offer. Add one line explaining design references and `openspec/`. Verify: each statement matches the code paths named in the audit.
- [ ] 7.5 Manual check: someone who has not seen the project follows the README and "First hour", and reports where they got stuck.

## 8. Small drifts and polish (H8, optional)

- [ ] 8.1 Send the real app version in `welcome` (read from project settings) instead of `APP_VERSION := "0.1.0"`. Verify: a bridge-server test checks the version.
- [ ] 8.2 Replace the `&"working"` literals in `avatar_mood.gd` with `Protocol.STATE_WORKING`. Verify: `git grep -n '&"working"' godot/scripts/core/avatar_mood.gd` finds only clip names; the Godot suite passes.
- [ ] 8.3 Add a small `Request` class next to `Session` in `session_registry.gd`, built in one place, and emit `request_removed` for the requests of an ended session. Verify: a registry test; the workaround comment in `messages.gd` is removed.
- [ ] 8.4 Use `String::utf8` for app names in `mac_overlay.mm`, and remove the unused `dock_pid`. Rebuild the extension. Verify: `scons -C native` builds; clicking a Wobbo whose session runs in an app with a non-ASCII name logs the right name.
- [ ] 8.5 Rename leftover "buddy" names (`isBuddyTool`, comments, the PROTOCOL example, test temp prefixes). Add a dated comment on the intentional `ClaudeBuddy` migration fallbacks. Verify: bridge checks and the Godot suite pass; `git grep -n -i buddy` shows only the migration paths and archived OpenSpec text.
- [ ] 8.6 Add `.github/ISSUE_TEMPLATE/` with a bug report and an idea template, if the user wants them (design, Open Questions). Verify: GitHub shows both when opening an issue.
- [ ] 8.7 Manual check: the user plays the demo and answers a question in a balloon; behaviour is unchanged.
