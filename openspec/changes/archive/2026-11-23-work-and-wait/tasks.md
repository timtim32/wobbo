# Tasks

## 1. Waiting for the user (spike S2)

- [x] 1.1 Add the `input_wait` event kind (design D1): `PROTOCOL.md`, `bridge/src/protocol.ts`, `Protocol.EVENT_KINDS`, and `SessionRegistry.apply_event` (sets `waiting` and the tool, normal `last_ts` ordering). Verify: Godot tests cover `input_wait` → `waiting`, followed by `tool_end` → `thinking`, an out-of-order `input_wait` being ignored, and a pending request still working as before.
- [x] 1.2 Map Claude Code's waiting cases in `claude_code.ts` (design D1): `PreToolUse` for `AskUserQuestion` and `ExitPlanMode`, and `Notification` with `permission_prompt` or `elicitation_dialog`. Verify: bridge tests for each mapping, and for other tools and notifications staying as before.
- [x] 1.3 Bump the plugin to 0.1.2, run `bun run build:plugin`, update the plugin in Claude Code (`claude plugin marketplace update buddy-local` and `claude plugin update buddy-bridge@buddy-local`), and document the update in the README (design D6). Verify: `claude plugin list` shows 0.1.2.
- [x] 1.4 Spike S2 result: in a real Claude Code session, check the order of `PreToolUse` and `PostToolUse` around `AskUserQuestion`, and the `Notification` type for a permission prompt in the terminal (from the app's log). Record it in `design.md` under D1, and apply the fallback if needed.
- [x] 1.5 Manual check: while Claude asks the user a question in the terminal, its buddy is in `waiting`, not shaking its arms, and after the answer it goes on with thinking or working.

## 2. Props and clips (spike S1)

- [x] 2.1 Draw the props `prop_hammer`, `prop_wrench`, `prop_laptop`, `prop_papers` and `prop_page` as hidden parts in `art/monster/monster.svg` (design D3), and document them in `art/monster/README.md`. Export them with `export_monster.gd`. Verify: the manifest lists the five parts with pivots, and the existing manifest tests stay green.
- [x] 2.2 Add the prop sprites to `monster.tscn` / `PARTS` on their bones, and the discrete visibility tracks plus `prop_page_rot` to `build_monster_clips.gd`, all hidden by default. Verify: a test that every non-`work_*` clip keys every prop as hidden.
- [x] 2.3 Write the new `waiting` clip (design D2) and the four work clips (design D4), add them to `LOOPING_CLIPS`, rebuild the clip libraries, and add a 0.2 s crossfade between looping clips in `Monster.play`. Verify: clip tests (every clip exists, loops seamlessly with the same first and last key, and its props are shown only in its own clip); existing monster tests stay green.
- [x] 2.4 Spike S1 result: show `waiting` and the five work clips side by side at real size in `monster_preview`, and let the user judge whether the props read well, are in style and are well placed. Record it in `design.md` under D3, and adjust or drop props with the user if needed.

- [x] 2.5 Add the `_in` / `_out` transition clips for the four prop clips (design D7), with the scale tracks for the laptop and papers. Verify: clip tests (each transition exists, plays once, and ends in the pose its loop starts in, or the rest pose for `_out`); the user approves the transitions in the work preview.

## 3. Work clip rotation

- [x] 3.1 Rotate the work clips in `AvatarMood` while `working` (design D5, D7): a random different clip every 8–15 s, a new pick on entering `working`, and the `_in` / `_out` transitions around each prop clip, including putting away before a new state. Verify: headless tests cover the switch within 8–15 s, never the same clip twice in a row, in → loop → out → next in, out before `done`'s reaction, and no effect in other states.
- [x] 3.2 Manual check: with a fake session kept `working` (`fake_sessions state <name> working`) the user watches the buddy switch between the work clips with props for a minute, without popping, and the demo shows the variety too.

## 4. Documentation and integration

- [x] 4.1 Update the README: the buddy table (waiting jumps, working has several variants with props) and the plugin update. Verify: the README describes them.
- [x] 4.2 Walk through every scenario in the four delta specs of this change by test or by hand, and tick them off in a short checklist in the PR description. Any deviation found by a spike is either fixed or explicitly accepted by the user.

## Workflow follow-up

- After review and merge: archive with `openspec archive work-and-wait`.
- Next change: `avatar-interactions` or `balloons-and-speech`.
