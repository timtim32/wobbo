# Spec Delta

## ADDED Requirements

### Requirement: Screen choice
The menu SHALL include a "Screen" submenu with "Automatic (follow the mouse)" and one item per connected display, named the way macOS names it. Exactly one item SHALL be checked. Choosing an item SHALL make that the buddies' home display (or turn on automatic mode). A remembered display that is not connected SHALL be listed as unavailable while it is still the choice.

#### Scenario: Choose a display
- **WHEN** the user opens "Screen" and chooses the external display
- **THEN** that item is checked and the buddies walk to the external display

#### Scenario: Automatic
- **WHEN** the user chooses "Automatic (follow the mouse)"
- **THEN** that item is checked and the home display follows the mouse pointer

#### Scenario: Display list follows connections
- **WHEN** a display is connected or disconnected
- **THEN** the next time the menu opens, the "Screen" submenu lists the displays that are connected now

## MODIFIED Requirements

### Requirement: Menu bar icon
While running, the app SHALL show an icon in the macOS menu bar that adapts to light and dark menu bar appearance, and clicking it SHALL open the app menu.

#### Scenario: App starts
- **WHEN** the app starts
- **THEN** a Claude Buddy icon appears in the menu bar

#### Scenario: Open the menu
- **WHEN** the user clicks the menu bar icon
- **THEN** the app menu opens, showing at least "Show Buddies"/"Hide Buddies", "Screen", "Debug regions" and "Quit Claude Buddy"

### Requirement: Persisted settings
Settings changed through the menu (at least overlay visibility, screen choice and debug regions) SHALL persist across launches in a per-user settings file. A missing or unreadable file SHALL fall back to defaults: visible, screen automatic, debug off.

#### Scenario: Setting survives restart
- **WHEN** the user hides the overlay, quits, and starts the app again
- **THEN** the overlay starts hidden and the menu shows "Show Buddies"

#### Scenario: Screen choice survives restart
- **WHEN** the user chooses the external display, quits, and starts the app again with that display connected
- **THEN** the buddies start on the external display and it is checked under "Screen"

#### Scenario: Corrupt settings file
- **WHEN** the settings file is not valid at startup
- **THEN** the app starts with default settings and does not crash
