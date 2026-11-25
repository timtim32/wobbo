## MODIFIED Requirements

### Requirement: Bottom strip placement
The overlay SHALL occupy, on every connected display, the full width of that display's usable area (excluding menu bar and Dock), anchored to its bottom edge, with a fixed height in points large enough for an avatar plus a speech balloon above it. While a buddy is carried or falling, every strip MAY grow upward to the full usable height of its display, and SHALL return to its fixed height within 1 second after the buddy has landed. While a buddy climbs along a side edge of a display or jumps down onto it, that display's strip MAY grow upward to the full usable height of the display, and SHALL return to its fixed height within 1 second after the last such buddy has left it or landed. Each display's strip SHALL meet all other requirements of the overlay (transparent, click-through outside interactive regions, always on top, on all Spaces, no focus stealing).

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

#### Scenario: Growing while a buddy climbs
- **WHEN** a buddy climbs along the side edge of the lower display
- **THEN** it is drawn in front of other windows all the way up to the menu bar, while clicks next to it still reach the windows behind the overlay

#### Scenario: Back to the strip after a climb
- **WHEN** the last climbing buddy has stepped onto the upper display, or the last jumping buddy has landed
- **THEN** within 1 second clicks above the lower strip's normal height reach the windows behind the overlay again
