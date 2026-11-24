# overlay-window Specification

## Purpose

Provides the transparent, click-through desktop surface along the bottom of the screen on which Wobbo's avatars and balloons live, so they feel part of the desktop rather than an application window.

## Requirements

### Requirement: Bottom strip placement
The overlay SHALL occupy, on every connected display, the full width of that display's usable area (excluding menu bar and Dock), anchored to its bottom edge, with a fixed height in points large enough for an avatar plus a speech balloon above it. While a buddy is carried or falling, every strip MAY grow upward to the full usable height of its display, and SHALL return to its fixed height within 1 second after the buddy has landed. Each display's strip SHALL meet all other requirements of the overlay (transparent, click-through outside interactive regions, always on top, on all Spaces, no focus stealing).

#### Scenario: Launch on a single display
- **WHEN** the app starts on a Mac with one display
- **THEN** the overlay spans the full usable width of that display
- **AND** its bottom edge touches the top of the Dock, or the screen bottom if the Dock is hidden or placed at the side

#### Scenario: Launch with several displays
- **WHEN** the app starts on a Mac with a built-in and an external display
- **THEN** each display has its own strip along its bottom edge, spanning that display's usable width

#### Scenario: Display layout changes
- **WHEN** the resolution, Dock size or position, or set of connected displays changes while the app is running
- **THEN** the strips reposition, resize, appear or disappear within 2 seconds to match the new usable areas of the connected displays

#### Scenario: Growing while a buddy is carried
- **WHEN** the user picks up a buddy and carries it to the top half of the screen
- **THEN** the buddy is drawn there, the other buddies stay where they were on the strip without any visible jump, and nothing else changes on screen

#### Scenario: Back to the strip after landing
- **WHEN** a dropped buddy has landed
- **THEN** within 1 second clicks above the strip's normal height reach the windows behind the overlay again, as before the buddy was picked up

#### Scenario: Clicks after an aborted drag
- **WHEN** the mouse button is released outside the overlay windows while a buddy is carried
- **THEN** the buddy is dropped as if released normally and the strips return to their fixed height after it lands

### Requirement: Transparent background
The overlay SHALL render nothing outside its drawn content: no window frame, title bar, shadow or background colour.

#### Scenario: Empty overlay
- **WHEN** the overlay is shown with no content drawn
- **THEN** the desktop and windows behind the strip look exactly as they would without the app running

### Requirement: Mouse pass-through outside interactive regions
The overlay SHALL let mouse events (move, click, scroll, drag) pass through to whatever is behind it, except within currently registered interactive regions.

#### Scenario: Click on empty overlay area
- **WHEN** the user clicks a point in the strip that is not inside any interactive region
- **THEN** the click reaches the window or desktop behind the overlay as if the overlay did not exist

#### Scenario: Scroll through the overlay
- **WHEN** the user scrolls with the cursor over a non-interactive part of the strip
- **THEN** the content behind the overlay scrolls

### Requirement: Interactive regions
The overlay SHALL let its content register, update and remove interactive regions. Mouse events within a region SHALL be delivered to the overlay, and region changes SHALL take effect within one rendered frame plus 50 ms.

#### Scenario: Click on an interactive region
- **WHEN** the user clicks inside a registered interactive region
- **THEN** the overlay receives the click and the window behind it does not

#### Scenario: Moving region
- **WHEN** an interactive region moves across the strip (for example a walking avatar) and the user clicks on its current position
- **THEN** the overlay receives the click

#### Scenario: Multiple disjoint regions
- **WHEN** several non-overlapping interactive regions are registered
- **THEN** each region receives clicks
- **AND** points between them still pass through

### Requirement: Always on top
The overlay SHALL stay above normal application windows at all times, including after other apps are activated.

#### Scenario: Another app is activated
- **WHEN** the user activates another application or opens a new window
- **THEN** the overlay's content stays visible above that window

### Requirement: Visible on all Spaces and over fullscreen apps
The overlay SHALL appear on every Space (virtual desktop) and over applications in native fullscreen mode, without animating along with Space transitions.

#### Scenario: Switch Space
- **WHEN** the user switches to another Space
- **THEN** the overlay is visible on that Space in the same position

#### Scenario: Fullscreen application
- **WHEN** the user puts an application into native macOS fullscreen
- **THEN** the overlay is drawn above that fullscreen application

### Requirement: No focus stealing
The overlay SHALL NOT activate the app or take keyboard focus from the frontmost application when it appears, updates or receives a click on an interactive region. It SHALL take keyboard focus only when its content explicitly requests it, and SHALL hand focus back to the previously frontmost app when that request is released.

#### Scenario: Click on an interactive region keeps typing target
- **WHEN** the user is typing in a terminal, clicks an interactive region of the overlay, and then keeps typing
- **THEN** the keystrokes still go to the terminal

#### Scenario: Explicit focus request
- **WHEN** overlay content requests keyboard focus (for example a text field in a balloon)
- **THEN** keystrokes are delivered to the overlay until the request is released
- **AND** afterwards the previously frontmost application is frontmost again

### Requirement: Accessory app presence
The app SHALL NOT show a Dock icon and SHALL NOT appear in the Cmd-Tab application switcher or in Mission Control's window overview.

#### Scenario: Running app in Dock and app switcher
- **WHEN** the app is running and the user presses Cmd-Tab or looks at the Dock
- **THEN** Wobbo does not appear there

### Requirement: Debug region view
The overlay SHALL offer a debug mode that outlines the bounds of every display's strip and every registered interactive region.

#### Scenario: Debug mode enabled
- **WHEN** debug mode is turned on
- **THEN** each strip's outline and each interactive region are drawn as visible outlines that follow the regions as they move, also while a region crosses from one display to another
