# Design: overlay-window

## Context

This is a new repository. `godot/project.godot` exists with only a name and the GL Compatibility renderer, and there are no scenes or scripts yet. The target is Godot 4.7.2 (official macOS build in `/Applications/Godot.app`) on macOS, Apple Silicon. See proposal.md for motivation and the specs for the required behaviour.

Godot covers part of what we need out of the box: borderless, transparent and always-on-top windows, a mouse pass-through polygon, a no-focus flag, and a `StatusIndicator` node for the menu bar. It has no API for Space and fullscreen behaviour or for app activation policy, so those need native code.

## Goals / Non-Goals

**Goals:**
- One reusable overlay surface that later changes only talk to through a small GDScript API: regions, focus requests and layout signals.
- Keep the native code as small as possible. Only what Godot really cannot do goes into the GDExtension.
- Prove the risky macOS behaviours (spikes S1 to S4) before the rest of the project builds on them.

**Non-Goals:**
- Multi-display support, export and signing (see the out-of-scope list in proposal.md).
- An abstraction for other operating systems. The native module is macOS-only by design.

## Decisions

### D1. One window, the full-width strip, in the main viewport
We use the main Godot window itself as the overlay, sized to the bottom strip of the main display's usable rect.
- Project settings: `display/window/size/borderless=true`, `display/window/size/transparent=true`, `display/window/per_pixel_transparency/allowed=true`, `rendering/viewport/transparent_background=true`, `display/window/size/always_on_top=true`, `display/window/size/no_focus=true`.
- Geometry: `DisplayServer.screen_get_usable_rect(DisplayServer.get_primary_screen())`, which already excludes the menu bar and Dock. The strip height is `STRIP_HEIGHT_PT (360) * screen_get_scale()`.
- **Assumption (verify in task 2):** with `allow_hidpi` on, Godot on macOS reports window and screen rects in the same pixel space, so no manual conversion is needed.
  - **Confirmed (task 2.1):** on the built-in Retina display (scale 2.0) the usable rect is `(0, 1304) 3024×1898` and after placement the window reads back as `(0, 2482) 3024×720`, exactly the computed strip. No conversion needed.
- *Alternatives:* a separate `Window` per avatar. That gives simpler hit-testing, but many native windows, more native configuration, and balloons crossing window boundaries. Rejected.

### D2. Layout tracking by polling
An `OverlayController` autoload re-reads the usable rect every 1 s and on `NOTIFICATION_APPLICATION_FOCUS_IN`. If it changed, it moves and resizes the window and emits `layout_changed(rect)`. Polling is cheap, and it catches Dock resizes, which do not trigger a screen-parameters notification.
- *Alternative:* observing `NSApplicationDidChangeScreenParametersNotification` natively. That is more code and misses Dock changes.

### D3. Hit-testing: dynamic pass-through polygon (spike S1)
Content registers rectangles through `Overlay.set_region(id: StringName, rect: Rect2)` and `Overlay.remove_region(id)`. Every frame the controller reads the global cursor with `DisplayServer.mouse_get_position()` (this works while the window ignores the mouse) and:
- If the cursor is inside a region, it sets the pass-through polygon to that region's rectangle, so the region receives events.
- Otherwise it sets the polygon to a degenerate 1 px polygon outside the visible area, so everything passes through.
- While a mouse button is held after starting inside a region (drag), the polygon covers the whole strip until release, so drags cannot "fall through".

We only update the polygon when the region under the cursor changes, to avoid redundant native calls.
- **Spike S1:** check that Godot's macOS `window_set_mouse_passthrough` switches fast enough (no missed first click) and that scrolling passes through.
- **Fallback:** `MacOverlay.set_ignores_mouse_events(bool)` in the GDExtension, which toggles `-[NSWindow setIgnoresMouseEvents:]` directly from the same per-frame check.
- **Result S1 (task 2.5, 2026-11-23, macOS 27, Godot 4.7.2, max_fps 30):** passed without the fallback. The user clicked the moving blob rapidly in several runs; the log registered 99 clicks and the user noticed no missed clicks. Clicks and scrolls next to the blob reached the windows behind it. Godot itself re-evaluates the polygon against the cursor every frame (`setIgnoresMouseEvents:` in `DisplayServerMacOS::process_events`), so the per-frame polygon swap is enough. Regions are 4 pt larger than the art. `set_ignores_mouse_events` stays in the GDExtension but is unused.
- *Alternative:* one static polygon that joins all regions with zero-width bridges. That is fragile with moving regions and leaks clicks along the bridges. Rejected.

### D4. Native GDExtension `macos_overlay` (Objective-C++)
`native/` contains an SConstruct build that uses godot-cpp as a git submodule. It is built against an API dump of the exact engine (`Godot --dump-extension-api` → `custom_api_file`) so 4.7 APIs match. Output goes to `godot/addons/macos_overlay/bin/`, together with `macos_overlay.gdextension`. It exposes one class, `MacOverlay` (an engine singleton), with these methods:
- `configure_window(handle: int)`: takes the `NSWindow*` from `DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE)` and sets:
  - `collectionBehavior = CanJoinAllSpaces | Stationary | FullScreenAuxiliary | IgnoresCycle`
  - `level = NSStatusWindowLevel`
  - `hasShadow = NO`
- `set_accessory_app()`: `[NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory]`. This removes the Dock icon and the Cmd-Tab entry, also when the project is started from the editor.
- `remember_frontmost_app()` / `restore_frontmost_app()`: through `NSWorkspace.frontmostApplication` and `-activateWithOptions:`.
- `set_ignores_mouse_events(bool)`: the S1 fallback only.

GDScript checks `ClassDB.class_exists("MacOverlay")`. If it is missing, the overlay still runs, without the Space, fullscreen and accessory behaviour, and logs a warning. That way the Godot side can be developed before the native build works.
- *Alternatives:* a separate helper process using the Accessibility API. That is clumsy and needs permissions. Swizzling Godot's window class into an `NSPanel` would be brittle across engine versions. Both rejected.

### D5. Focus: no-focus flag plus frontmost restore (spike S2)
By default the window has `WINDOW_FLAG_NO_FOCUS`, so it never becomes the key window. An open question is whether clicking an accessory app's window still *activates* the app (and so takes focus away from the terminal).
- **Spike S2:** click a region while typing in Terminal and check whether keystrokes keep going to Terminal.
- **Fallback:** on mouse-down inside a region, call `remember_frontmost_app()`; on mouse-up, `restore_frontmost_app()`. This happens within one event cycle, so typing is not visibly interrupted.
- **Result S2 (task 4.1, 2026-11-23):** failed. With `NO_FOCUS` the window never becomes key, but a click still *activates* the accessory app: 0.3 s after each click the frontmost app was `org.godotengine.godot` and `NSApp.isActive` was true, and typing no longer reached Terminal.
- **Fallback implemented (task 4.2):** the frontmost app is remembered when the cursor enters a region and on mouse-down (a no-op when we are already frontmost), and re-activated at the end of the mouse-down frame (deferred, skipped while a keyboard-focus request is open) with a safety net on mouse-up. On macOS 14+ this uses `-[NSApp yieldActivationToApplication:]` + `-[NSRunningApplication activateWithOptions:0]`. The remembered app is kept after restoring, so repeated clicks without leaving the region restore it again. Result: keystrokes keep reaching Terminal. A short focus flicker (a few ms) stays visible; that is accepted. Avoiding activation completely would need an `NSPanel` with `NSWindowStyleMaskNonactivatingPanel`, which Godot's window class does not allow (see D4 alternatives).

Explicit focus works through `Overlay.request_keyboard_focus(owner)` and `release_keyboard_focus(owner)`. These remember the frontmost app, clear `NO_FOCUS`, activate the app and call `grab_focus()` on the requesting Control. On release they set `NO_FOCUS` again and restore the previous app. Requests are reference-counted per owner.

### D6. Spaces and fullscreen visibility (spike S3)
- **Spike S3:** check that `CanJoinAllSpaces | FullScreenAuxiliary` with `NSStatusWindowLevel` in an accessory app shows above a native fullscreen app. If it does not, try `NSScreenSaverWindowLevel - 1`.
- **Fallback:** support all Spaces but not fullscreen, and document it as a known limitation. That is a spec deviation, so we discuss it with the user first.
- **Result S3 (task 3.4, 2026-11-23, macOS 27):** passed at `NSStatusWindowLevel` (25); `NSScreenSaverWindowLevel - 1` was not needed. The blob is visible on every Space without animating along with the Space transition, and above Safari in native fullscreen. No Dock icon and no Cmd-Tab entry (process type `UIElement`). Godot may reset the level on window changes, so `OverlayController` re-applies `configure_window` after layout changes and on every 1 s poll (a no-op when nothing changed).

### D7. Menu bar: `StatusIndicator` + `PopupMenu`
A `StatusIndicator` node in the main scene has `menu` pointing to a `PopupMenu`. On macOS, Godot turns that into a native `NSMenu`. The icon is a monochrome PNG (the monster's silhouette) so macOS can tint it for light and dark menu bars. Items:
- "Hide Buddies" / "Show Buddies" (the label swaps)
- "Debug regions" (check item)
- a separator
- "Quit Claude Buddy" (`get_tree().quit()`)
- **Spike S4 (small):** check that the menu works when the app is an accessory and the window has `NO_FOCUS`.
- **Fallback:** build the menu with the `NativeMenu` API directly.
- **Result S4 (task 5.4, 2026-11-23):** passed. `StatusIndicator` + `PopupMenu` work as an accessory app with `NO_FOCUS`; all items behave as specified. One fix was needed: Godot does not mark the status icon as a template image, so the black silhouette was invisible on a dark menu bar. `MacOverlay.set_status_item_icons_template()` finds this app's `NSStatusBarWindow` buttons and sets `image.template = YES`, so macOS tints the icon for light and dark menu bars. On a notched built-in display macOS may move the icon into the menu bar overflow when space runs out; that is system behaviour.

### D8. Settings store
A `Settings` autoload wraps a `ConfigFile` at `user://settings.cfg`. `application/config/use_custom_user_dir=true` with the name `ClaudeBuddy` puts it in `~/Library/Application Support/ClaudeBuddy/`. It offers typed getters and setters with defaults, saves on every change, and emits a `changed(key, value)` signal. If the file fails to load, it logs a warning and keeps the defaults. Later changes add their own keys (for example the output mode).

### D9. Debug view and placeholder
A `DebugLayer` (a CanvasLayer drawn on top) draws the strip outline and the region rectangles while the setting is on. A temporary `DebugBlob` placeholder (a coloured circle that slides back and forth and changes colour when clicked) registers a moving region. That lets us verify D3 and D5 before any character exists. It gets removed in `session-avatars`.

### D10. Tests
Pure logic (region lookup, drag capture state, settings fallback) lives in plain GDScript classes with no window dependency. It is tested by a tiny headless runner: `godot --headless --path godot --script res://tests/run_tests.gd`, which exits non-zero on failure. Window and macOS behaviour is verified by hand using the checks in tasks.md.

## Risks / Trade-offs

- [Godot's editor runs the game embedded in its Game tab (4.5+ on macOS), so the overlay behaviour is lost] → Turn off "Embed Game on Next Play" for this project and document it in the README. The Godot MCP and CLI runs start a separate window anyway.
- [S1: a pass-through switch that lags misses the first click when the cursor moves quickly onto a moving avatar] → Make regions a few pixels larger than the art. Use the native `setIgnoresMouseEvents` fallback.
- [S2: clicks activate the app and steal focus] → Use the frontmost-restore fallback (D5).
- [S3: macOS refuses to show the window above fullscreen apps] → Try a higher window level first. Otherwise ask the user before accepting the limitation.
- [Rendering every frame in a full-width transparent window costs battery] → Cap at `application/run/max_fps=60` and measure idle CPU in task 2. Lower the cap if it is above about 3% on an M-series Mac.
  - **Result (task 2.6, 2026-11-23, Apple M5 Pro, strip 3024×720 px at scale 2, blob moving, `top` averages):** run from the editor (debugger attached): 60 fps ≈ 10%, 30 fps ≈ 4.8%, 20 fps ≈ 3.6%. Standalone (`Godot --path godot`): 60 fps ≈ 5.8%, 30 fps ≈ 3.7%. The debug outline adds nothing measurable. Cost scales with frame rate, so `max_fps` is lowered to **30**, which is about the 3% budget standalone; 20 fps would save little more and makes walking look choppy. Further savings (e.g. `low_processor_mode` or a lower cap while every avatar sleeps) belong to `session-avatars`.
- [godot-cpp has no branch that matches 4.7 exactly] → Build against the custom API dump from the installed engine (D4).
- [Other overlay apps or private window levels may sit above ours] → Accept this. It is not in scope.

## Migration Plan

None. This is a new project.

## Open Questions

- The exact strip height (360 pt) may change once the character's size and the balloon layout are known. It is a constant, so changing it does not affect the specs or the tasks.
