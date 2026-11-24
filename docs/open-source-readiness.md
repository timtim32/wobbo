# Open source readiness

Date: 2026-11-24. Scope: the publication candidate in `~/Projects/wobbo` (fresh history, 2 local
commits, nothing pushed), plus the private `claude-buddy` history as background. This is an audit
only: no code, configuration, scene or history was changed.

**How it was checked.** I read the code, docs, OpenSpec changes and both git histories, and ran
the project from a fresh clone of the candidate in a scratch folder, following
`docs/DEVELOPMENT.md`. Three independent read-only reviews (the Godot app; bridge, native and
tools; security, licensing and git) were cross-checked, and every finding marked *verified* below
was confirmed in the code or by running it. What could not be checked is listed at the end.

## Executive summary

**Status: Ready after minor improvements.**

The code is the strongest part of this repository. It has a clear one-way architecture, pure
logic kept apart from Godot nodes, near-complete static typing, comments that explain *why*, a
documented local protocol, 348 automated tests and a design decision behind every feature. An
experienced developer will read it as deliberate work, not a weekend hack.

What holds it back is not code quality but release hygiene. Nothing blocks publication; the
remaining items are small and fixable in a few focused pull requests. The most important ones:
- a developer MCP addon and a debug menu are shipped to end users;
- the test runner can report a passing test after a script error;
- a fresh clone needs one undocumented step before the tests pass.

## Readiness scorecard

| Category | Status | Explanation |
|---|---|---|
| Code quality | Strong | Typed, small pure helpers, consistent conventions, no TODOs, no dead code found. A few small drifts (below). |
| Human readability | Strong | Names and responsibilities are clear; comments explain platform quirks. The dense `(change Dn)` references need the OpenSpec archive to follow. |
| Architecture | Strong | One-way flow: bridge → registry → planner → avatars. Sized to the problem; no frameworks or managers for their own sake. |
| Maintainability | Good | `OverlayController` is still 768 lines (split deferred on purpose). Requests are untyped dictionaries while sessions are a class. |
| Godot best practices | Good | Idle cost measured and reduced, `.uid` files committed, generated clips. A dev addon ships in the export, and the balloon fits itself every frame. |
| Documentation | Good | README is clear and visual. `DEVELOPMENT.md` is thorough but long (495 lines), and mixes a behaviour reference with setup. |
| New developer experience | Needs work | Builds work from a clean clone, but the first test run fails until the project is imported, and nothing says so. |
| Build and setup | Good | Native extension, bridge and plugin built from a fresh clone without surprises (verified). macOS only, Godot 4.7.2 required. |
| Testing | Good, one flaw | 294 Godot + 54 bridge tests pass (verified). The Godot runner counts a test as passed when its body hits a script error (verified). No CI. |
| Security and privacy | Good | No secrets anywhere in either history. Local-only socket, 0600 token, careful config edits. One UX risk in permission balloons. |
| Licensing and assets | Needs work | Code MIT, artwork and name reserved, third-party licences compatible. No third-party notices in the app, and `ARTWORK.md` leaves the animation data ambiguous. |
| Git hygiene | Good | Clean fresh history with the right identity, good `.gitignore`. Would benefit from a few defensive ignore patterns. |
| Contribution readiness | Partly ready | `CONTRIBUTING.md` and licences exist. No CI, no issue templates, and the release script defaults to your repository. |
| Professional presentation | Good | Trailer, icon, clear README, consistent naming. The public repo still holds an older history, and a 610-line internal audit sits in `docs/`. |

## What is already good

- **Logic you can test without Godot running.** About 25 small `RefCounted` helpers in
  `godot/scripts/core/` make the decisions (who gets a slot, which mood, how a picked-up Wobbo
  swings, how the Dock is read). They take time as an argument, so they are tested headless.
  Nodes only carry out side effects. This is the single best signal in the codebase.
- **Data flows one way.** A bridge frame goes into `BridgeServer._handle`, then into the pure
  `SessionRegistry`, which emits signals. `AvatarManager` replans through the pure
  `AvatarCast.plan`, and each avatar asks the pure `AvatarMood` what to play. A contributor
  adding a feature typically extends one helper, adds its test, and wires it into one node.
- **Typing.** All 554 functions declare a return type. The six untyped variables are commented as
  deliberate.
- **Comments record real knowledge.** Examples: a polygon that draws black in an exported 4.7.2
  build (`balloon.gd:264`), Godot dropping a frame that arrives with the close frame
  (`bridge_server.gd:248`), why the Claude Desktop config is edited in TypeScript and not in Godot
  (Godot turns `1` into `1.0`).
- **The bridge can't hurt Claude Code.** Every hook exits 0, status hooks are async, connect and
  send are bounded by 200 and 300 ms, and a missing app is a normal state rather than an error
  path (`bridge/src/main.ts:27`, `app_client.ts:24`).
- **A real protocol document.** `bridge/PROTOCOL.md` has a version field, rules for additive
  changes, and ordering by timestamp for out-of-order hook processes.
- **Careful edits to another app's config.** `claude_desktop.ts` is a pure function over the file
  text, writes atomically, keeps the file mode and other entries, refuses invalid JSON, and has 13
  tests.
- **Security basics are right.** The bridge listens only on `127.0.0.1`, uses a 32-byte token, and
  `bridge.json` is set to 0600 before the token is written. These have tests.
- **Idle cost was measured.** The app drops to 10 frames per second when nothing moves, and hides
  empty display strips.
- **Animation is code.** Clips are generated by `tools/build_monster_clips.gd`, so a pose change
  is a reviewable diff, and a test checks clip names against the monster's clip lists.
- **The design trail.** Fifteen completed OpenSpec changes, each with a proposal, design decisions
  and tasks, explain why the code is the way it is.
- **Disciplined tooling.** `release.sh` uses strict mode, an error trap and precondition checks.
  `record-trailer.sh` was designed so nothing personal can end up in the video.
- **Commit messages** in the original history are specific, in the imperative mood and have
  context in the body.

## Critical blockers

None. The Wobbo character, its artwork and the code are the author's own work.

Everything in this report is an improvement, not a blocker. Two of them (H1, H2) I would still
fix before publishing, because they are what an experienced reviewer will notice first.

## High-value improvements

### H1. Developer tooling and debug features ship to users (verified)

- `godot/addons/godot_ai/` is excluded neither from the export (`export_presets.cfg:11` excludes
  only `tests/*, tools/*`) nor from autoloads (`project.godot:34`). The 1,447-line helper runs
  `_process` every frame and calls `OS.add_logger` (`game_helper.gd:131,157`) in every user's app.
  It says it stays idle without a debugger, so this is hygiene, not a privacy leak.
- `docs/codebase-audit.md:115,585` claims the addon is "stripped on export". That is wrong.
- The end-user menu has "Debug regions" (`menu_bar.gd:50`). It turns on a debug panel and a
  "Type here (debug)" avatar item, which opens a field still marked
  "Temporary debug text field (task 4.4)" that prints whatever is typed
  (`debug_text_field.gd:2,17`).
- The preview scenes in `godot/characters/monster/*_preview.tscn` are exported too.

**Fix:** exclude the addon and preview scenes from the export, and keep its autoload out of
release builds (for example, register it from the editor plugin only). Show the debug items only
when `OS.is_debug_build()`, and remove the temporary text field.

### H2. The Godot test runner can report a false pass (verified)

`godot/tests/run_tests.gd:35-41` calls the test method and only looks at recorded `failures`. A
runtime error aborts the test body, and the runner still prints `ok`. Verified on a fresh clone:
`SCRIPT ERROR: Invalid call…` followed by `ok test_walkway_body.gd::test_rect_of_an_upright_body`.
An `await` inside a test is also never waited for.

**Fix:** count script errors during each test with a Godot `Logger` (available since 4.5) and fail
the test when one occurs. Document that tests must be synchronous.

### H3. A fresh clone fails its first test run (verified)

On a fresh clone, the documented test command gives `265 tests, 6 failed` plus 915 lines of
errors, because the class cache in `.godot/` does not exist yet. After
`Godot --headless --path godot --import` it gives `294 tests, 0 failed`. The import step only
appears in the "Character art" section of `DEVELOPMENT.md`.

**Fix:** add a short "first time" step (import once) to the test instructions, or let the test
runner check for the class cache and say what to do.

### H4. Permission balloons can hide part of what is approved (verified)

`describePermission` (`bridge/src/adapters/claude_code.ts:156-174`) shows the first matching field
of the tool input and cuts the text at 300 characters. A long shell command can put its dangerous
tail past the cut, and an MCP call shows only one argument, while the balloon still offers
**Allow**.

**Fix:** when the description is cut, or the tool has several significant arguments, don't offer
Allow in the balloon. Leave the prompt to Claude Code, or offer only "Answer in the session". Add
a test.

### H5. Licensing paperwork for the shipped app

The DMG bundles the Godot runtime (MIT plus third-party notices), the godot-cpp code compiled into
the extension, and the compiled bridge. The bridge contains the Bun runtime, which links
JavaScriptCore (LGPL). None of these notices ship with the app.

`ARTWORK.md` also leaves the animation data unnamed (`godot/characters/monster/clips/*.tres`,
`monster.tscn`, `godot/assets/monster/manifest.json`), so it is unclear whether those are MIT or
reserved.

A fork cannot easily follow "replace the artwork first", because there are no placeholder parts.

**Fix:**
- Add a `THIRD_PARTY_NOTICES` file to the repo and the app bundle.
- Check the LGPL terms for the Bun binary.
- Name the animation data explicitly in `ARTWORK.md`.
- Add a short note on how to swap the art.

### H6. New-contributor workflow

There is no CI, so a pull request has no automatic check. The bridge tests and the Godot headless
tests could both run on a hosted macOS runner.

`release.sh:22` defaults to your release repository and silently creates a public repository when
it is missing (`release.sh:142-145`). `DEVELOPMENT.md:448,453` hard-codes your account. A fork
running `publish` would target your repo.

**Fix:**
- Add one CI workflow (bridge tests and typecheck; Godot import and tests).
- Make the release target explicit, and drop the automatic repo creation.

### H7. Documentation that serves a newcomer

- `DEVELOPMENT.md` (495 lines) mixes setup with a 100-line description of how every Wobbo behaves.
  That behaviour reference also lives in `openspec/specs/`. A short "first hour" path at the top
  (prerequisites, clone with submodules, import, test, run) would serve newcomers better, with the
  behaviour reference moved or linked.
- `docs/codebase-audit.md` (610 lines) is an internal snapshot. It references commits that won't
  exist in the public history (`3f03baf`) and contains a claim that is now wrong (H1). Mark it as
  historical, or move it into the archived `codebase-cleanup` change it belongs to.
- The README "Privacy" section is accurate but incomplete. It should also mention:
  - logs in `~/Library/Application Support/Wobbo/logs/` contain session and project names;
  - permission details are shown in balloons and may be spoken aloud;
  - the login item;
  - the offer to move the app to Applications.

### H8. Small code drifts worth fixing in passing

All verified:

| Location | What drifts | Fix |
|---|---|---|
| `bridge_server.gd:22` | `APP_VERSION := "0.1.0"` is sent to every client, while the app is 0.2.4 | Read the version from project settings |
| `avatar_mood.gd:87,133,141` | Compares against the literal `&"working"`, a small regression of the earlier "one source for each fact" cleanup | Use `Protocol.STATE_WORKING` |
| `session_registry.gd:37`, `bridge_server.gd:189,227` | Requests are dictionaries described in a comment and built twice, while sessions are a class | A small `Request` class |
| `session_registry.gd:265`, `bridge_server.gd:105` | Requests of an ended session are dropped without a `request_removed` signal; `messages.gd:65` works around it | Emit the signal |
| `mac_overlay.mm:347,348,378` | App names with non-ASCII letters come out garbled (`String(const char*)` instead of `String::utf8`) | Use `String::utf8` |
| `mac_overlay.h:101` | `dock_pid` is never read | Remove it |
| `isBuddyTool`, `mac_overlay.mm:31`, `PROTOCOL.md:66` | Old "buddy" names. The `ClaudeBuddy` fallbacks are intentional migration code and can stay | Rename, and date the migration fallbacks |

## Code portfolio review

**Strong decisions.**
- *Separation.* Splitting pure decision logic from Godot nodes is a mature choice that most game
  and tool projects never make. It is the reason 294 Godot tests run headless in seconds.
- *Restraint.* The architecture is sized to the problem: four autoloads, signals in one direction,
  no event bus, no dependency-injection framework, no base-class hierarchy.
- *Failure as a normal state.* "The app isn't running" and "the user didn't answer" are designed
  paths with timeouts, not exceptions.
- *Platform knowledge in the open.* The quirks of Godot's WebSocket, macOS activation, Dock
  geometry and exported-build rendering are written down where they matter.
- *Traceable decisions.* The OpenSpec trail shows how you think: what was considered, what was
  rejected and why.

**Weaker decisions.**
- *Release hygiene.* A developer addon and a debug menu reach end users, and a test runner can
  pass a broken test. Each is small, but they are the kind of thing a careful reviewer notices
  first, because they suggest the release path gets less attention than the code.
- *Uneven typing at the edges.* Sessions are typed, requests are dictionaries, and some node
  references (`_avatars: Node`, `messages: Node`) rely on duck typing although a typed alternative
  is already used elsewhere.
- *Trailer mode woven into production code.* `TrailerMode.active()` checks sit in five production
  scripts. That is understandable, but a separate scene loaded only for `--trailer` would keep the
  main path cleaner.
- *`OverlayController` at 768 lines.* It is coherent and well sectioned, and the split was
  deferred deliberately and documented. It is fine now, but it is the first file to split if it
  grows.

**The overall impression.** An experienced developer browsing this repository will find a
thoughtfully designed, well-tested codebase that is clearly above the typical Godot hobby project.
It reads like the work of someone who weighs trade-offs and writes them down. The dense design
references and the volume of OpenSpec material may look heavy at first glance. A one-paragraph
explanation in the README turns that into a strength rather than noise. Nothing in the code needs
rewriting.

## Open-source preparation checklist

**Must fix before publication**
- [ ] Decide what happens to the existing public history of `timtim32/wobbo`, which differs from
      the candidate. Replacing it needs an explicit go-ahead to force-push.

**Strongly recommended**
- [ ] Keep the godot_ai addon and preview scenes out of release exports; show debug items only in
      debug builds; remove the temporary text field (H1).
- [ ] Correct the "stripped on export" claim, and mark `docs/codebase-audit.md` as historical (H1, H7).
- [ ] Make the Godot test runner fail on script errors (H2).
- [ ] Document the one-time import for a fresh clone (H3).
- [ ] Don't offer Allow for truncated or multi-argument permission prompts (H4).
- [ ] Add `THIRD_PARTY_NOTICES`, check Bun's LGPL terms, and clarify the scope of `ARTWORK.md` (H5).
- [ ] Add one CI workflow, and make the release target fork-safe (H6).
- [ ] Add defensive `.gitignore` patterns (`*.p12`, `*.pem`, `.env`, `*.log`, `.vscode/`, `.idea/`).

**Optional polish**
- [ ] A "first hour" section at the top of `DEVELOPMENT.md`, with the behaviour reference moved (H7).
- [ ] Complete the README privacy section (H7).
- [ ] The small code drifts in H8.
- [ ] Issue templates for bugs and ideas. A pull request template is not needed yet.
- [ ] A short "Roadmap" or "Status" list in the README, linking the open OpenSpec changes.
- [ ] A line in the README on how design references and `openspec/` work.

A Code of Conduct and a separate style guide would be overhead at this size. `CONTRIBUTING.md`
plus consistent existing code is enough.

## Publication roadmap

Each phase is one or more small pull requests. Phases 1 and 2 can run in parallel.

| Phase | Objective | Scope | Outcome | Risk | Validation |
|---|---|---|---|---|---|
| 0. Decisions | Agree on scope and the public history | This report and the OpenSpec change; keep or replace the public history | A reviewed plan | None | Your sign-off |
| 1. Release hygiene | Ship only what users need | H1, plus the debug gating | The exported app has no addon, no previews and no debug menu | Low. Must not break the editor workflow with the MCP addon | Export a build and list the `.pck` contents; editor run still has the addon; Godot suite |
| 2. Trustworthy checks | Tests that can't lie, and that run for others | H2, H3, H6 (CI) | A fresh clone passes on the first run, and pull requests get a check | Low. CI on macOS runners may need tuning | A deliberately broken test fails; CI run on a fork |
| 3. Safer permissions | Never approve what isn't shown | H4 | Truncated prompts fall back to Claude Code | Low. Behaviour change for long commands | New bridge test; manual check with a long command |
| 4. Paperwork and docs | Legal and onboarding clarity | H5, H7, `.gitignore`, fork-safe release | Notices in repo and DMG, clear artwork scope, a newcomer path | None in code | Build the DMG and check the notices are inside; a newcomer dry-run of the docs |
| 5. Polish | Small drifts | H8, issue templates | Consistent code and project | Low | Godot and bridge suites; smoke check |
| 6. Publish | Go public | Replace or keep the public history, push, tag | Public repository | Irreversible once indexed | Final review of the tree; licence detected as MIT |

## Final recommendation

1. **Would I make it public today?** Not quite. The code is ready, and nothing blocks it, but I
   would first fix the release hygiene (H1) and the test runner (H2).
2. **Exact blockers:** none. H1 and H2 are what I would not publish without.
3. **First five changes:**
   1. Exclude the godot_ai addon and preview scenes from export, and gate the debug menu (H1).
   2. Make the test runner fail on script errors (H2).
   3. Document the fresh-clone import step (H3).
   4. Stop offering Allow on truncated permission prompts (H4).
   5. Add third-party notices and clarify the scope of `ARTWORK.md` (H5).
4. **What should not change:**
   - the pure-helper and node split;
   - the one-way data flow;
   - the bridge's never-block design;
   - the protocol document;
   - the generated animation clips;
   - the OpenSpec trail and its references in comments;
   - the static typing style.

   Don't split `OverlayController` just to make it shorter, and don't introduce a framework.
5. **Good enough as it is:**
   - the bridge, including its tests;
   - the native extension (apart from the UTF-8 fix);
   - the core helpers and their tests;
   - the README's user-facing part;
   - the release and trailer scripts (apart from the fork-safe defaults);
   - the commit-message style.
6. **What most improves the impression:** clean release hygiene (H1) and a contributor path that
   works the first time and is checked by CI (H2, H3, H6). Those show that you care about the
   whole lifecycle, not only the code.
7. **Ready for contributions?** For small, focused contributions, yes, once H3 is documented: the
   code is navigable and the tests are fast. Larger contributions need CI and a short roadmap, so
   that people can see what is wanted and get feedback without asking you first.

## What was and was not verified

**Verified by running, on a fresh clone of the candidate:**
- Bridge: `bun install`, `bun test` (54 pass) and `bun run build:plugin`.
- Godot: first test run before import (`265 tests, 6 failed`), `--import`, then the test run
  after import (`294 tests, 0 failed`).
- Native: submodule initialised and the native extension built with `scons` (about 16 s).
- The false pass in the test runner, seen in the output.
- `tsc --noEmit` has no errors (from the bridge review).

**Verified by reading code:**
- every finding marked *verified*;
- the export filter and the autoloads;
- the 0600 token file;
- no secrets in either history.

**Not verified:**
- running the app itself, and its window, focus or Dock behaviour;
- an export or release build, and the actual contents of the `.pck` and DMG;
- whether Claude Code shows its own permission dialog while the 20-second permission hook waits;
- the balloon's size after a display-scale change;
- behaviour on macOS 13 and on Intel;
- whether "Wobbo" collides with an existing trademark;
- the licence of every transitive npm package beyond its `package.json`.
