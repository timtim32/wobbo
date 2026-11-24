# Developing Wobbo

This is the guide for working on Wobbo itself. To use Wobbo, see the
[README](../README.md).

A macOS desktop overlay: small animated monsters walk along the bottom of the
screen and act as the face of your Claude Code sessions. Product decisions live
in `openspec/config.yaml`, changes in `openspec/changes/`. Code comments refer
to design decisions as `(<change> Dn)`, for example `(overlay-window D5)`: decision
Dn in `openspec/changes/archive/<date>-<change>/design.md`.

Repository layout: `godot/` (Godot 4.7 project), `native/` (macOS GDExtension in
Objective-C++), `bridge/` (connects coding agents, Bun + TypeScript), `art/`
(SVG sources), `openspec/`.

## First hour

From a fresh clone to a running app and a passing test run. The sections below
explain each step.

1. Install the tools ([Requirements](#requirements)): Godot 4.7.2 in
   `/Applications`, Bun 1.4 or newer, and for the native extension the Xcode
   command line tools and SCons (`xcode-select --install`, `brew install scons`).
2. Clone with the godot-cpp submodule:

   ```bash
   git clone --recurse-submodules https://github.com/timtim32/wobbo.git
   ```

3. Import the Godot project once, then run both test suites:

   ```bash
   cd wobbo && /Applications/Godot.app/Contents/MacOS/Godot --headless --path godot --import
   ```

   ```bash
   /Applications/Godot.app/Contents/MacOS/Godot --headless --path godot --script res://tests/run_tests.gd
   ```

   ```bash
   cd bridge && bun install && bun test
   ```

4. Build the native extension (optional, under a minute):

   ```bash
   scons -C native -j8
   ```

5. Quit an installed Wobbo, open `godot/` in the Godot editor, turn off "Embed
   Game on Next Play" and press Play ([Running the project](#running-the-project)).
6. Choose **Play Demo** in the menu bar icon to see Wobbos without a real
   session, or connect Claude Code ([Connecting coding agents](#connecting-coding-agents-bridge)).

**Where things live.**

| To change | Look in |
| --- | --- |
| What a Wobbo does in each session state | `godot/scripts/core/avatar_mood.gd` (pure logic) and `godot/scripts/avatars/session_avatar.gd` (the node) |
| Who gets a slot, colour and place | `godot/scripts/core/avatar_cast.gd` |
| Sessions and requests from the bridge | `godot/scripts/core/session_registry.gd`, `godot/scripts/bridge/bridge_server.gd` |
| Balloons and speech | `godot/scripts/avatars/{messages,balloon}.gd`, `godot/scripts/core/message_policy.gd` |
| Windows, displays, click-through and the Dock | `godot/scripts/autoload/overlay_controller.gd`, `godot/scripts/overlay/` |
| The menu bar menu | `godot/scripts/menu_bar.gd` |
| How Claude Code's hooks become events | `bridge/src/adapters/claude_code.ts` |
| Poses and animation timing | `godot/tools/build_monster_clips.gd` |

Logic in `godot/scripts/core/` has no nodes and takes time as an argument, so
each helper has headless tests in `godot/tests/`. A change there usually comes
with a test.

## AI tooling (optional)

Wobbo is developed with Claude Code. None of this is needed to build or run it.
Agent skills and MCP settings are personal, so they are not in the repository
(see `.gitignore`):

- **OpenSpec.** Changes are planned with [OpenSpec](https://github.com/Fission-AI/OpenSpec)
  in `openspec/`. `openspec init` adds its skills for your coding agent.
- **Godot MCP.** The `godot_ai` editor addon in `godot/addons/` lets an agent
  drive the Godot editor through the [`godot-ai`](https://pypi.org/project/godot-ai/)
  MCP server. To use it with Claude Code, add a `.mcp.json` in the repository
  root that starts `uvx godot-ai attach`.

## Requirements

- macOS on Apple Silicon (Intel works with `arch=x86_64`).
- Godot 4.7.2 at `/Applications/Godot.app`.
- For the native extension: Xcode command line tools and SCons.
- For the agent bridge: [Bun](https://bun.sh) 1.4 or newer.

## Running the project

1. Build the native extension once (see below). Without it the overlay still
   runs, but it is not visible on other Spaces or above fullscreen apps, and it
   shows a Dock icon. A warning in the log says so.
2. Open `godot/` in the Godot editor.
3. **Turn off "Embed Game on Next Play"** (Game tab, the toggle/⋮ menu next to
   the play controls). Since Godot 4.5 the editor embeds the running game in its
   Game tab on macOS, and then the overlay window behaviour (transparency,
   click-through, window level) is lost.
4. Press Play (F5). A transparent strip appears along the bottom of the main
   display, with the menu bar icon top right.

Without the editor:

```bash
/Applications/Godot.app/Contents/MacOS/Godot --path godot
```

Quit through the menu bar icon → "Quit Wobbo". Settings are stored in
`~/Library/Application Support/Wobbo/settings.cfg`. Only one Wobbo runs at a
time: an editor run quits at once while the installed app runs (the log says
so), so quit the app first.

## How Wobbo behaves

What the Wobbos do in each session state, on several displays, when dragged,
and with balloons, speech and the Dock is described in
[behaviour.md](behaviour.md). The requirements behind it are in
`openspec/specs/`.

## Tests

The app's logic has headless tests. After a fresh clone, import the project
once, so Godot knows the scripts' class names (opening it in the editor does
the same):

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path godot --import
```

Then run the tests:

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path godot --script res://tests/run_tests.gd
```

The runner runs every `test_*` method in `godot/tests/test_*.gd` and exits 0 when
all pass, 1 otherwise. A test fails when an assertion fails, when its body hits a
script error, or when it uses `await`: tests are synchronous. Without the import
the runner says so and exits 1. Window and macOS behaviour is checked by hand
(see `openspec/changes/archive/2026-11-23-overlay-window/tasks.md`).

## Character art

The monster is drawn in `art/monster/monster.svg`, one group per rig part (see
`art/monster/README.md`). After editing it, export the parts:

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path godot --script res://tools/export_monster.gd
```

This writes `godot/assets/monster/parts/<part>.png` and
`godot/assets/monster/manifest.json` (each part's rect and pivot). Godot then has to
re-import the changed PNGs: focus the open editor, or run

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path godot --import
```

The output is
deterministic, so an unchanged SVG gives no git diff. The headless tests check
that the export matches the SVG.

### Character clips

The rig is `godot/characters/monster/monster.tscn`. Its animation clips are
generated from the data in `godot/tools/build_monster_clips.gd`; change timing
and poses there, not in the editor (the build overwrites the `.tres` files):

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path godot --script res://tools/build_monster_clips.gd
```

To see every clip at real size on the overlay, run the preview scene
`res://characters/monster/monster_preview.tscn` (in the editor: open it and press
"Run Current Scene", F6). It shows one monster per clip, each in its own colour,
with the pupils following the cursor. `hue_preview.tscn` shows the colour
candidates side by side instead, and `work_preview.tscn` shows `waiting` and the
work clips, taking and putting away their props.

## Connecting coding agents (`bridge/`)

The app listens on `127.0.0.1` for the `wobbo-bridge` program. It writes
the port and a secret token to
`~/Library/Application Support/Wobbo/bridge.json`, which only you can
read. The protocol is described in `bridge/PROTOCOL.md`.

### Build and test

```bash
cd bridge && bun install
```

```bash
cd bridge && bun test
```

```bash
cd bridge && bun run build:plugin
```

`build:plugin` compiles the single binary `bridge/dist/wobbo-bridge` and
copies it into the plugin (`bridge/plugin/bin/`). `build:universal` builds it for
Apple silicon and Intel together (releases use that). Run it again after changing
the bridge source.

To try the app side without an agent, start the app, then run the demo client.
It plays a fake session and asks a question that you answer in the Wobbo's
balloon (or, with menu bar → Debug regions on, in the debug panel):

```bash
bun bridge/scripts/demo_client.ts
```

To drive several fake sessions by hand, for example to try the Wobbos, use
`fake_sessions.ts`. Each command is one short connection:

```bash
bun bridge/scripts/fake_sessions.ts add website
```

```bash
bun bridge/scripts/fake_sessions.ts state website working
```

```bash
bun bridge/scripts/fake_sessions.ts end website
```

Its other commands are `add-many <n>`, `say <name> <text>`, `ask <name>` (waits
for an answer in the Wobbo's balloon) and `end-all <names…>`. Run it without
arguments for the full list.

### Claude Code (plugin)

Users get the plugin from the app: **Connect to Claude Code** copies the
plugin Wobbo carries to `~/Library/Application Support/Wobbo/claude-plugin/` and
installs it as `wobbo@wobbo`. In an editor run, Connect uses `bridge/plugin`
(build it first). The plugin adds status hooks, which run in the background and
never slow Claude down, permission prompts in the app, and an MCP server
`wobbo` with the tools `say` and `ask_user`.

For development the repository is also a marketplace, `wobbo-dev`, with the
same plugin. Connect in Wobbo replaces that install (and an old
`buddy-bridge`), so sessions are never reported twice. To install it by hand,
from the repository root:

```bash
claude plugin marketplace add ./
```

```bash
claude plugin install wobbo@wobbo-dev --scope user
```

New Claude Code sessions then show up in the app. To try the plugin in one
session without installing it:

```bash
claude --plugin-dir bridge/plugin
```

To remove it:

```bash
claude plugin uninstall wobbo@wobbo-dev
```

Claude Code asks permission before it uses Wobbo's tools; the plugin
leaves that prompt in the terminal, because asking in the app for permission
to ask in the app would be circular. To allow them once and for all, add them
to `permissions.allow` in your `~/.claude/settings.json` (or use `/permissions`):

```json
"permissions": { "allow": ["mcp__plugin_wobbo_wobbo__say", "mcp__plugin_wobbo_wobbo__ask_user"] }
```

After changing the bridge, rebuild with `bun run build:plugin`, raise the
version in `bridge/plugin/.claude-plugin/plugin.json`, and update the installed
copy:

```bash
claude plugin marketplace update wobbo-dev
```

```bash
claude plugin update wobbo@wobbo-dev
```

Restart running Claude Code sessions afterwards; they keep the old version
until then.

When Claude asks you something in the terminal (its question tool, plan
approval, or a permission prompt), the hooks report that the session waits for
you, so its Wobbo jumps for attention instead of looking busy.

When the app is not running, the hooks do nothing and the tools tell Claude to
continue in the conversation. A permission prompt waits up to 20 seconds for
Allow or Deny in the Wobbo's balloon before Claude Code shows its own prompt
(at once when the output is Off or the Wobbos are hidden); set
`WOBBO_PERMISSION_WAIT_S` to change that (0 turns it off). The balloon only
offers Allow for what it can show in full: a long command, an edit or write
(whose new content the balloon doesn't show), or an MCP call with several
arguments goes straight to Claude Code's own prompt, and the Wobbo jumps for
attention.

### Claude Desktop (MCP)

Claude Desktop has no hooks, so it only uses the `say` and `ask_user` tools.
There is nothing to set up by hand: when you connect Wobbo to Claude Code and
Claude Desktop is on your Mac, Wobbo adds its `wobbo` entry to
`~/Library/Application Support/Claude/claude_desktop_config.json` and asks you
to restart Claude Desktop. It keeps that entry current on every start while it
is connected, replaces old `claude-buddy` entries, and removes it again when
you disconnect. Other servers and settings in that file are left alone.

For development, the bridge does the same edit itself, and can print the
entry:

```bash
bridge/plugin/bin/wobbo-bridge claude-desktop connect
```

```bash
bridge/plugin/bin/wobbo-bridge print-config claude-desktop
```

`claude-desktop connect` writes the path of the bridge that ran it, so run it
from the binary you want Claude Desktop to start. Claude Desktop runs one MCP server for all its chats, so it
appears as a single "Claude Desktop" session in the app. In Claude Desktop's Code tab,
Claude Desktop also starts this server for each Code session; the app links it
to the Code session of the same project, so its messages show up there.

### Other agents

Every session carries its agent's name, and agent-specific code lives in
`bridge/src/adapters/`. Any MCP client can already use
`wobbo-bridge mcp --agent <name>`. Status hooks for another agent, such
as Codex, are a new adapter.

## Recording the trailer

```bash
tools/record-trailer.sh
```

Plays a short scripted show (`TRAILER_STEPS` in
`godot/scripts/avatars/demo_player.gd`) and writes `build/trailer/wobbo-trailer.mp4`
and `wobbo-trailer.gif`. It quits a running Wobbo first and opens it again
afterwards. Keep your hands off the mouse while it records.

Nothing of your own Mac ends up in the video. Wobbo runs from this repo in
trailer mode (`-- --trailer=<dir>`), which:

- does not listen for agents, so real sessions never appear;
- shows no welcome and does not save settings;
- uses only the main display and paints an opaque backdrop over the strip;
- ignores the real Dock and slides in a pretend one with plain tiles for the
  Dock jump.

The video ends on the title (`godot/scripts/avatars/trailer_title.gd`): "Wobbo"
with Wobbo eyes for the o's, set in Baloo 2 (`godot/assets/fonts/`, SIL Open
Font License, see `OFL.txt` there).

Only that strip is recorded, without the mouse pointer. The crop happens while
recording, so no full-screen frame is written to disk. Options:
`--size small|normal|large|xl`, `--bg '#top,#bottom'`, `--gif-width`,
`--gif-fps` and `--out`. The terminal that runs the script needs Screen Recording
permission. With `gifski` installed (`brew install gifski`) the GIF comes out
sharper.

## Making a release

Releases are built on the maintainer's Mac with `tools/release.sh`. Users never
run it.

**Once:**

1. Install the Godot 4.7.2 export templates: Godot editor → Editor → Manage
   Export Templates → Download and Install.
2. Create Wobbo's signing certificate. Every release is signed with it, so macOS
   keeps permissions such as Accessibility across updates. Keep the backup
   (`.p12` and its password) safe: a new certificate makes every user grant
   Accessibility again.

   ```bash
   tools/make_signing_cert.sh ~/Documents/Wobbo-signing
   ```

**Per release:** build it. This sets the version in the app and the plugin,
builds the universal extension, bridge and app, signs them and makes
`build/Wobbo.dmg`. Add `--debug` for a build that logs to the terminal.

```bash
tools/release.sh build 0.2.0
```

Try it on your own Mac (quit Wobbo first):

```bash
tools/release.sh install
```

Publish it as a GitHub release on the GitHub repository of your `origin`
remote (set `WOBBO_RELEASE_REPO=owner/repo` for another one; the repository
must exist). The notes come from `tools/release-notes.md`. Set `WOBBO_GH_USER` when that account is not gh's
active one:

```bash
WOBBO_GH_USER=<your-account> tools/release.sh publish 0.2.0
```

To re-render the app icon after changing the monster drawing:

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path godot --script res://tools/export_app_icon.gd
```

## Building the native extension (`native/`)

The `macos_overlay` GDExtension sets what Godot cannot: visibility on all Spaces
and above fullscreen apps, the window level, accessory-app mode (no Dock icon or
Cmd-Tab entry) and the focus helpers. It is built with
[godot-cpp](https://github.com/godotengine/godot-cpp) (git submodule) against an
API dump of the installed engine.

One-time setup:

```bash
xcode-select --install
```

```bash
brew install scons
```

```bash
git submodule update --init --recursive
```

Build (from the repo root):

```bash
scons -C native -j8
```

This dumps the engine API to `native/build/api/` (refreshed when the Godot
version changes; set `GODOT=/path/to/Godot` for another binary) and writes
`godot/addons/macos_overlay/bin/libmacos_overlay.macos.template_debug.framework`.
Use `target=template_release` for a release build and `arch=universal` for a
universal binary. Restart the Godot editor after the first build so it loads
the extension.
