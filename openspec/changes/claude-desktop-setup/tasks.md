# Tasks

## 1. Bridge

- [x] 1.1 Add `bridge/src/claude_desktop.ts` with pure `connectConfig(text, binary)` and `disconnectConfig(text)` (design D2), and the file step `runClaudeDesktop(action, home, binary)` with an atomic write. Verify: `bun test` covers a missing file, an empty file, other servers and preferences kept, a stale `claude-buddy` entry removed, `unchanged` without a write, `removed`, `absent`, and invalid JSON left untouched.
- [x] 1.2 Wire `wobbo-bridge claude-desktop connect|disconnect` into `src/main.ts`. Verify: `bun run typecheck`, and the built binary run with a temporary `HOME` prints `added`, then `unchanged`.

## 2. App

- [x] 2.1 In `ClaudeSetup`, run the copied bridge's `claude-desktop connect` after a successful connect, `disconnect` after disconnecting, and `connect` on start while the plugin is installed (design D3, D4). Add `desktop` to the result. Verify: headless tests in `test_claude_setup.gd`.
- [x] 2.2 Welcome texts for Claude Desktop (design D5). Verify: the tests check the texts' conditions through the result.

- [x] 2.3 Link Code-tab messages from the Desktop server to the calling session when Claude Desktop's project name differs from the folder, and name an unlinked one "Claude Desktop" (design D6). Verify: `test_session_registry.gd`.

## 3. Docs

- [x] 3.1 Replace the manual Claude Desktop step in `README.md`. Verify: the section names no file to edit for users and keeps `print-config` for development.

## 4. Manual checks (need the user)

- [ ] 4.1 The user connects from Wobbo's menu, restarts Claude Desktop, and asks a chat to say hello through Wobbo. The message appears as the "Claude Desktop" buddy.
- [ ] 4.2 The user changes a Claude Desktop setting, quits Claude Desktop, and checks that the `wobbo` entry is still in its configuration.
- [ ] 4.3 The user disconnects from Wobbo's menu, restarts Claude Desktop, and the chat no longer has Wobbo's tools.

## 5. Public page with the 0.2.2 release

Update the public `timtim32/wobbo` repo together with the 0.2.2 release, not before: 0.2.1 still says "buddy" and needs the manual Claude Desktop step. Publish as gh account `timtim32`, with the user's go-ahead at release time; never push branches there.

- [x] 5.1 README: "buddy"/"buddies" become Wobbo/Wobbos, also in the image alt texts ("Wobbo itself walks in", "A Wobbo per session").
- [x] 5.2 README: replace the "Claude Desktop chats" section (Wobbo sets it up on connect; restart Claude Desktop), the "Claude Desktop chats" row in "Where it works" (works, `say` and `ask_user` only), and add to Uninstall that Disconnect also removes the Claude Desktop entry.
- [x] 5.3 README: update "Still being checked in this release" to what is confirmed by then.
- [ ] 5.4 New `assets/welcome.png` from the 0.2.2 welcome ("gets a Wobbo like me"). The user makes the screenshot later.
- [x] 5.5 Repo description: "Wobbo: a Wobbo on your desktop for every Claude Code session". Release notes of v0.2.0 and v0.2.1: "buddy" becomes Wobbo/Wobbos.
- [x] 5.6 Repo settings: add topics (`claude-code`, `macos`, `desktop-pet`) and turn off the empty wiki. No licence for now (the user's choice, 2026-11-24).
- Not now: re-recording the trailer (`assets/wobbo-trailer.gif` and `.mp4`) with the new tagline; the user deferred it.
