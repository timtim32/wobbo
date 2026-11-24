# Spec Delta

## Purpose

Gives the user global control over Claude Buddy through a macOS menu bar icon, since the app has no Dock icon or regular window, and keeps the user's choices across launches.

## ADDED Requirements

### Requirement: Menu bar icon
While running, the app SHALL show an icon in the macOS menu bar that adapts to light and dark menu bar appearance, and clicking it SHALL open the app menu.

#### Scenario: App starts
- **WHEN** the app starts
- **THEN** a Claude Buddy icon appears in the menu bar

#### Scenario: Open the menu
- **WHEN** the user clicks the menu bar icon
- **THEN** the app menu opens, showing at least "Show Buddies"/"Hide Buddies", "Debug regions" and "Quit Claude Buddy"

### Requirement: Show and hide the overlay
The menu SHALL let the user hide and show the whole overlay. While hidden, the overlay SHALL draw nothing and SHALL pass all mouse events through.

#### Scenario: Hide
- **WHEN** the user chooses "Hide Buddies"
- **THEN** the overlay's content disappears and the menu item changes to "Show Buddies"

#### Scenario: Show
- **WHEN** the overlay is hidden and the user chooses "Show Buddies"
- **THEN** the overlay's content reappears and the menu item changes to "Hide Buddies"

### Requirement: Debug regions toggle
The menu SHALL include a checkable "Debug regions" item that turns the overlay's debug region view on and off.

#### Scenario: Toggle debug regions
- **WHEN** the user selects "Debug regions"
- **THEN** the debug region view is toggled and the item's check mark reflects the new state

### Requirement: Quit
The menu SHALL include "Quit Claude Buddy", which ends the app and removes the menu bar icon.

#### Scenario: Quit from menu
- **WHEN** the user chooses "Quit Claude Buddy"
- **THEN** the app exits and both the overlay and the menu bar icon are gone

### Requirement: Persisted settings
Settings changed through the menu (at least overlay visibility and debug regions) SHALL persist across launches in a per-user settings file. A missing or unreadable file SHALL fall back to defaults: visible, debug off.

#### Scenario: Setting survives restart
- **WHEN** the user hides the overlay, quits, and starts the app again
- **THEN** the overlay starts hidden and the menu shows "Show Buddies"

#### Scenario: Corrupt settings file
- **WHEN** the settings file is not valid at startup
- **THEN** the app starts with default settings and does not crash
