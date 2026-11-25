# Tasks

## 1. Read the login state in the background

- [x] 1.1 Add `AppMenu.needs_login_status(exported, location)` to `godot/scripts/core/app_menu.gd` (design D2). Verify: a test in `godot/tests/test_app_menu.gd`.
- [x] 1.2 In `godot/scripts/menu_bar.gd`, keep `_login_status`, read it with a `WorkerThreadPool` task at start and on each menu open, and make `_sync_app_items()` use only the stored value (design D1, D3). Verify: a timed run of the dev app shows `_sync_app_items()` well under 1 ms and no frame gaps when the menu opens.
- [x] 1.3 Run the Godot test suite headless (`godot --headless --path godot -s res://tests/run_tests.gd`). Verify: all tests pass.
- [ ] 1.4 Manual check in the installed app: the menu opens at once, the Wobbos keep walking, and "Open at Login" still shows the right check mark.
