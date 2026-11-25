# Tasks

## 1. Walk breaks between work stints

- [x] 1.1 Add the stint count, `_break_after` and `_break_until` to `godot/scripts/core/avatar_mood.gd`, and start a 2.5 to 3.5 s `walk`/`stroll` break where the next way of working would be picked after 2 to 4 stints (design D1). Verify: tests in `godot/tests/test_avatar_mood.gd` that the first stint never starts with a break, that a break follows after 2 to 4 stints with no prop visible, and that work resumes after it.
- [x] 1.2 End the break on any other state, and on walking in, travelling or leaving (design D2). Verify: a test that `done` during a break gives the happy reaction at once.
- [x] 1.3 Run the Godot test suite headless (`godot --headless --path godot -s res://tests/run_tests.gd`). Verify: all tests pass.
- [x] 1.4 Manual check: let a Claude Code session work for a few minutes (or use the demo/fake sessions); the Wobbo works through a few props, walks around for about 3 seconds, and goes back to work.
