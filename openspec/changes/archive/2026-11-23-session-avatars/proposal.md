# Proposal: session-avatars

## Why

All the parts are now in place: the overlay on every display, the rigged monster, and the bridge that knows each coding session and its state. But the user still sees only one debug monster, which mirrors whichever session was active last. Claude Buddy is meant to be the face of every session. The user should see at a glance how many sessions are running, which one is which, and what each is doing (thinking, working, waiting for them, done or failing) without opening a terminal. This change gives every session its own monster on the walkway and retires the debug monster.

## What Changes

- **One avatar per session:** every active agent session gets its own monster on the home display's strip.
  - A new session's monster walks in from an outer edge of the displays.
  - When the session ends, its monster waves and walks off until it has left at an outer edge, crossing other displays if needed.
  - With no sessions, the strip stays empty.
- **Mood follows the session:** the avatar plays the clip for its session's state.
  - Thinking, working and waiting have their own clips.
  - A finished turn gets a short happy reaction.
  - An error gets a startled flinch.
  - An idle session strolls around its spot.
  - After a while without activity the avatar falls asleep, and the next activity wakes it up.
- **Recognisable per session:**
  - Each avatar has its own colour, from a curated set of hues that stay readable. The colour stays the same for the session's whole life, and two visible avatars never share a colour.
  - A small label with the session's display name (the project name) is shown with the avatar. A "Show Names" item in the menu hides or shows all labels, and the choice is saved.
- **Sharing the strip:**
  - Avatars keep their own spot on the home display and do not overlap.
  - At most 5 avatars are on screen. When a sixth session becomes active, the avatar of the session that has been quiet the longest walks off and the new one walks in. A session without an avatar gets one back as soon as it is among the 5 most recently active again.
- **Walking between displays:** all avatars follow the home display (`multi-display`). When the home display changes, they all walk over.
- **Looking and clicking:**
  - The avatars look at the mouse pointer.
  - Clicking an avatar makes it react happily. Focusing the session's window is left to `avatar-interactions`.
  - In debug mode, right-clicking an avatar opens the debug text field there, as before.
- **Demo in the menu:** a "Play Demo" item in the menu bar plays a short scripted show with pretend sessions (walking in, every state, a swap at six, waving goodbye), so the buddies can be shown without running real agents. The pretend sessions exist only inside the app.
- **Quiet when nothing happens:** while every avatar sleeps or no avatar is shown, the app lowers its frame rate to save CPU.
- **Removed:** the debug monster (`DebugBlob`) and its "mirror the most recent session" behaviour. The debug session panel stays.

### Out of scope

- Speech balloons, text-to-speech, and answering questions or permission requests at the avatar (`balloons-and-speech`). Until then, requests are answered in the debug session panel.
- Click to focus the session's window, drag and drop, and the right-click menu (`avatar-interactions`).
- Deeper needs such as feeding, levels or evolution (never planned), and detecting failing tests from tool output.
- Choosing a colour or name per session by hand.
- A per-avatar home display. All avatars share one home display.

## Capabilities

### New Capabilities

- `session-avatars`: the avatars that represent agent sessions on the overlay. It covers:
  - one avatar per session, with entering and leaving;
  - the mapping from session state to behaviour and clips, including sleeping and waking;
  - colour and name label per session;
  - sharing the strip, and the limit of 5 avatars;
  - looking at the pointer and the click reaction;
  - lowering the frame rate while nothing moves.
- The demo show's content (which pretend sessions do what) is part of `session-avatars` design; the menu item is in `menu-bar-control`.

### Modified Capabilities

- `menu-bar-control`: the app menu gains a "Play Demo" / "Stop Demo" item and a "Show Names" check item, and the names choice is saved.

The overlay, character, session tracking and multi-display requirements stay as they are. The debug monster that this change removes was never part of a spec.

## Impact

- **New code:** an avatar manager that turns `Bridge` session signals into avatars. Its decisions (which sessions get an avatar, spots on the strip, colour assignment, state-to-behaviour mapping, sleep timing) live in a pure, headless-tested core. A `SessionAvatar` node builds on `WalkwayBody` and adds a name label view per strip window.
- **Changed code:**
  - `main.tscn` / `main.gd`: the debug monster is removed, and the debug text field opens at an avatar;
  - `Monster`: only if the label needs to live in the view;
  - frame-rate handling.
- **Removed code:** `scripts/debug/debug_blob.gd`.
- **Performance:** up to 5 monsters cost about 0.2 percentage points CPU each, measured in `character-rig`. Sleeping and empty states lower the frame rate.
- **Later changes:** `balloons-and-speech` attaches balloons to these avatars, and `avatar-interactions` adds window focus, dragging and the right-click menu.
