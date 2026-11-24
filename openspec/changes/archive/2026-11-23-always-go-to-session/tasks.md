# Tasks

No design.md: the change only removes the waiting check from the pure click rule.

Headless tests: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path godot --script res://tests/run_tests.gd`.

## 1. Click rule

- [x] 1.1 Change `ClickAction.for_left_click()` to return `go` for every state except `ended`, keeping `none` when no agent process is known; update its doc comment and the comment on `AvatarManager.go_to_session()`. Verify: `tests/test_click_action.gd` covers `go` for thinking, working, waiting, done, error and idle, `none` for ended, and `none` without a process; the full suite passes.
- [x] 1.2 Update the README's "Looking and clicking" text: a click on any buddy goes to its session. Verify: the README no longer says a click on a buddy that does not wait does nothing.
- [x] 1.3 Manual check: with sessions in the Claude app and in a terminal, the user clicks a working buddy, an idle (or sleeping) buddy and a waiting buddy while another app is in front. Each time the right app comes to the front (and the Claude app shows that session), and the buddy keeps its animation.

## Workflow follow-up

- After review and merge: archive with `openspec archive always-go-to-session`.
