# Proposal

## Why

Clicking the menu bar icon opens the menu late, and the Wobbos stutter. Measured in the app: each time the menu opens, Wobbo asks macOS 4 times whether it is a login item (`SMAppService.mainAppService.status`). Each call blocks for 150 to 450 ms. Two of those calls run before the menu appears (about 0.46 s). The other two run when the background check of Claude Code finishes (about 0.9 s), and during that time the overlay draws no frames.

## What Changes

- Wobbo asks macOS for the "Open at Login" state on a background thread, at start and each time the menu opens, and stores the answer. The menu uses the stored answer, so opening the menu and updating its items never waits on macOS.
- When the answer differs from the stored one, the check mark updates, also while the menu is open.
- Wobbo does not ask at all when "Open at Login" is shown disabled anyway (editor run, disk image, not in an Applications folder).

### Out of scope

- The background check of Claude Code (`claude plugin list`). It already runs on a thread and does not block the overlay.

## Capabilities

### New Capabilities
<!-- none -->

### Modified Capabilities
- `menu-bar-control`: a new requirement that the menu opens at once and the overlay keeps running smoothly.

## Impact

- `godot/scripts/menu_bar.gd`: cached login state, read on a worker thread.
- `godot/scripts/core/app_menu.gd`: `needs_login_status()`.
- `godot/tests/test_app_menu.gd`: test for `needs_login_status()`.
