# Proposal: work-and-wait

## Why

Two things came up while the buddies were in use:

- **Waiting looks like working.** When Claude asks the user something through its own question tool (`AskUserQuestion`), Claude Code reports that as a tool starting. The buddy then plays its busy *working* clip, shaking its arms, while it is really waiting for the user. The same happens when Claude Code shows a permission prompt in the terminal after the app's 20-second permission window has passed. A buddy that waits for the user should ask for attention, and keep doing so until the user answers.
- **Working gets boring.** During long tasks the buddy plays the same working clip for minutes. The user would like more variety: sometimes it grabs a hammer, types on a laptop, turns a wrench, or leafs through papers.

## What Changes

- **Waiting for the user is recognised:** the Claude Code hook adapter reports these as a new event, `input_wait`, and the app shows the session as `waiting` until the next step:
  - Claude starting a tool that asks the user (`AskUserQuestion`, and `ExitPlanMode` for plan approval);
  - Claude Code showing a permission prompt or an input dialog (its `permission_prompt` and `elicitation_dialog` notifications).
- **Jumping for attention:** the `waiting` clip becomes a clear, continuous jump. The buddy hops up and down and waves, looking out at the user, for as long as the session waits.
- **Several ways of working:** besides the current busy clip, there are four work clips, each with a prop:
  - **hammer:** grabs a hammer and hammers away;
  - **laptop:** opens a small laptop and types fast;
  - **wrench:** turns a wrench;
  - **papers:** leafs through a stack of papers.

  While a session is `working`, its buddy switches to another randomly chosen work clip every 8 to 15 seconds.
- **Art:** the four props are drawn as new hidden parts in `monster.svg`, in the same flat style, and only shown by their clip. Each prop hangs on the hand or body bone, so it moves with the rig.
- **Protocol:** `input_wait` is an additive event kind (`v: 1` stays). The bridge plugin gets a new version, and the README tells how to update it.

### Out of scope

- Other agents' ways of asking the user. Other adapters can send `input_wait` later.
- Props or variants for other states (thinking, idle).
- Sounds.
- Choosing a work clip by tool (for example a hammer for `Bash`). The choice is random.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `avatar-character`:
  - "Animation clips" gains the work clips `work_hammer`, `work_laptop`, `work_wrench` and `work_papers`;
  - "Clip meaning" changes `waiting` to a continuous jump for attention and describes the work clips.
- `session-avatars`: "Behaviour follows session state" alternates the work clips while `working`.
- `agent-bridge`: "Session status from Claude Code" reports that the agent waits for the user (a question tool, plan approval, a permission prompt or an input dialog) as `input_wait`.
- `session-tracking`: "Session list and state" puts a session in `waiting` on `input_wait`, until its next state event.

## Impact

- **Art:** `art/monster/monster.svg` (4 hidden prop parts), the exported parts and the manifest.
- **Godot:**
  - `monster.tscn` (prop sprites on their bones);
  - `build_monster_clips.gd` (four work clips and a new `waiting` clip) and the generated clip libraries;
  - `Monster.LOOPING_CLIPS`;
  - `AvatarMood` (work clip rotation);
  - `SessionRegistry` (the `input_wait` event);
  - `Protocol.EVENT_KINDS`.
- **Bridge:** the `claude_code.ts` adapter, `PROTOCOL.md`, the plugin version bump and the rebuilt binary.
- **Users:** the Claude Code plugin has to be updated (`claude plugin update`) and sessions restarted to get the new waiting detection.
