# Proposal

## Why

Wobbo is about to become a public, MIT-licensed repository that other developers will clone, read and contribute to, and that represents its author's work. The open-source readiness audit (`docs/open-source-readiness.md`) found the code itself in good shape. What remains is a short list of release-hygiene, onboarding and licensing gaps that a newcomer or a careful reviewer would hit first:

- developer tooling and debug features ship to end users;
- the Godot test runner can report a broken test as passing;
- a fresh clone fails its first test run;
- permission balloons can offer Allow for text they don't fully show;
- the shipped app carries no third-party notices.

## What Changes

Findings refer to the audit (H = high-value; the audit found no blockers). Each numbered group in `tasks.md` is one small, independently reviewable pull request.

**Before publication (the fixes the audit recommends before going public):**
- **Review (no code):** the user agrees with the scope and order of this change.
- **Release hygiene (H1):** the vendored `godot_ai` addon and the monster preview scenes are left out of release exports, and the addon's runtime autoload does not run in release builds. "Debug regions" and "Type here (debug)" appear only in debug builds. The temporary debug text field is removed. The wrong "stripped on export" claim in `docs/codebase-audit.md` is corrected.
- **Trustworthy tests (H2, H3):** the Godot test runner fails a test whose body raises a script error. The docs, and the runner when the class cache is missing, tell a fresh clone to import the project once.
- **Safer permission balloons (H4):** when the description of a permission prompt had to be cut, or the tool input has more than one significant argument, the balloon does not offer Allow. The decision is left to Claude Code's own prompt.
- **Licensing paperwork (H5):**
  - `THIRD_PARTY_NOTICES.md` in the repository and in the app bundle;
  - the LGPL terms for the Bun runtime inside the compiled bridge are checked;
  - `ARTWORK.md` names the animation data explicitly;
  - a short note explains how a fork swaps the art.

**Strongly recommended, after the above:**
- **Contributor workflow (H6):** one CI workflow on a hosted macOS runner (bridge tests and typecheck; Godot import and tests). `tools/release.sh` requires an explicit release repository and no longer creates one by itself. Defensive `.gitignore` patterns are added.
- **Docs for newcomers (H7):**
  - a "first hour" path at the top of `docs/DEVELOPMENT.md`;
  - the behaviour reference in that file moves to the specs or is linked;
  - `docs/codebase-audit.md` is marked historical;
  - the README privacy section names the log folder, spoken permission details, the login item and the move-to-Applications offer;
  - one README line explains the design references.

**Optional polish (may be dropped or split off):**
- **Small drifts (H8):**
  - the app version sent in `welcome`;
  - the `&"working"` literals;
  - a `Request` class;
  - `request_removed` when a session ends;
  - UTF-8 app names in the native extension;
  - the unused `dock_pid`;
  - leftover "buddy" names.
- **Issue templates** for bugs and ideas.

Out of scope:
- Publishing, pushing, tagging, changing GitHub settings or rewriting any history. Those stay with the user, after this change.
- Any change to the Wobbo artwork.
- Splitting `OverlayController`, moving trailer mode out of production scripts, a Theme resource for the balloon, or other refactors the audit lists as preferences.
- A Code of Conduct, a pull request template or a style guide.
- Notarization, automatic updates or anything else from `standalone-app`.
- The vendored `godot/addons/godot_ai/` itself and the `native/godot-cpp` submodule. Their files are not edited.

## Capabilities

### New Capabilities
<!-- none -->

### Modified Capabilities
- `menu-bar-control`: the "Debug regions" item exists only in debug builds.
- `agent-bridge`: permission prompts whose details can't be shown in full are left to Claude Code.

## Impact

- **Godot:** `export_presets.cfg`, `project.godot` (autoload handling), `scripts/menu_bar.gd`, `scripts/avatars/avatar_manager.gd`, `scripts/debug/` (text field removed), `tests/run_tests.gd`; with H8, `scripts/bridge/bridge_server.gd`, `scripts/core/{avatar_mood,session_registry}.gd`.
- **Bridge:** `bridge/src/adapters/claude_code.ts` plus a test; with H8, renames.
- **Native (H8 only):** `native/src/mac_overlay.{h,mm}`; requires rebuilding the extension.
- **Tools:** `tools/release.sh` (notices in the bundle, explicit release repository).
- **Repository:** `THIRD_PARTY_NOTICES.md`, `ARTWORK.md`, `.gitignore`, `.github/workflows/`, optionally `.github/ISSUE_TEMPLATE/`.
- **Docs:** `README.md`, `docs/DEVELOPMENT.md`, `docs/codebase-audit.md`, `art/monster/README.md`.
- **Saved data:** none. `settings.cfg` keeps its format. A saved `debug_regions = true` is ignored in release builds.

**Overlap with other changes:**
- `standalone-app` (in progress) also changes the "Menu bar icon" requirement, `export_presets.cfg` and `tools/release.sh`. Land groups 2 and 6 after standalone-app's group 9, or rebase onto it. The "Menu bar icon" scenario that lists "Debug regions" is updated when standalone-app is archived (design D6).
- `codex-support` (planned) adds a second adapter next to `claude_code.ts`. Group 4 should land first, so Codex inherits the safer permission description.
- `codebase-cleanup` (archived) is not repeated. This change only fixes its regression in `avatar_mood.gd` and the wrong claim in its audit.
