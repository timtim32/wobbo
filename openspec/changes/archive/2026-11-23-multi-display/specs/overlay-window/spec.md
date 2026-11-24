# Spec Delta

## MODIFIED Requirements

### Requirement: Bottom strip placement
The overlay SHALL occupy, on every connected display, the full width of that display's usable area (excluding menu bar and Dock), anchored to its bottom edge, with a fixed height in points large enough for an avatar plus a speech balloon above it. Each display's strip SHALL meet all other requirements of the overlay (transparent, click-through outside interactive regions, always on top, on all Spaces, no focus stealing).

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

### Requirement: Debug region view
The overlay SHALL offer a debug mode that outlines the bounds of every display's strip and every registered interactive region.

#### Scenario: Debug mode enabled
- **WHEN** debug mode is turned on
- **THEN** each strip's outline and each interactive region are drawn as visible outlines that follow the regions as they move, also while a region crosses from one display to another
