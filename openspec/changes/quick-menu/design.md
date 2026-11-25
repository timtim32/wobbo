# Design: quick-menu

## Context

`MenuBar._sync_app_items()` calls `Overlay.native.login_item_status()` every time it runs. It runs on `about_to_popup` (directly, and through `ClaudeSetup.busy_changed` when `refresh()` starts), and again on `busy_changed`/`state_changed` when the refresh thread finishes. `login_item_status()` reads `SMAppService.mainAppService.status`, a synchronous call to a system service that took 150 to 450 ms per call in the app. All of it runs on the main thread, so the menu opens late and the overlay freezes.

## Decisions

### D1. A cached login state, read on a worker thread
`MenuBar` keeps `_login_status` (starts as `"not_registered"`). `_read_login_status()` starts one `WorkerThreadPool` task (never two at once) that calls `login_item_status()` and hands the result back with `call_deferred`. On the main thread the result is stored and, when it changed, `_sync_app_items()` runs. `_sync_app_items()` only reads `_login_status`. The read starts in `_ready()` and on each `about_to_popup`.
- *Alternative:* cache with a time limit, like `ClaudeSetup`. That still blocks on the first open after the limit runs out.

### D2. No read when the item is disabled anyway
`AppMenu.needs_login_status(exported, location)` is true only for an exported app in an Applications folder. Otherwise no read starts and the item stays disabled, as now. `bundle_location()` is cheap and stays a direct call.

### D3. Toggling
`_toggle_login_item()` already runs after a click, when the menu has closed. It keeps its direct calls (it must know the result to open System Settings) and stores the new status in `_login_status`.

## Risks / Trade-offs

- [The check mark is briefly stale after a change in System Settings] → It updates within half a second, while the menu is open.
- [A task still running when the app quits] → `_exit_tree()` waits for it.
