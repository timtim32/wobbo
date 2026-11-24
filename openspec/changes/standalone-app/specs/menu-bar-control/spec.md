## MODIFIED Requirements

### Requirement: Menu bar icon
While running, the app SHALL show an icon in the macOS menu bar that adapts to light and dark menu bar appearance, and clicking it SHALL open the app menu.

#### Scenario: App starts
- **WHEN** the app starts
- **THEN** a Wobbo icon appears in the menu bar

#### Scenario: Open the menu
- **WHEN** the user clicks the menu bar icon
- **THEN** the app menu opens, showing at least "Show Buddies"/"Hide Buddies", "Screen", the Claude Code connection item, "Open at Login", "Debug regions" and "Quit Wobbo"

### Requirement: Quit
The menu SHALL include "Quit Wobbo", which ends the app and removes the menu bar icon.

#### Scenario: Quit from menu
- **WHEN** the user chooses "Quit Wobbo"
- **THEN** the app exits and both the overlay and the menu bar icon are gone

## ADDED Requirements

### Requirement: Open at Login
The menu SHALL include a checkable "Open at Login" item. Turning it on SHALL register the installed app with macOS to open when the user logs in; turning it off SHALL remove that registration. When macOS needs the user's approval, the item SHALL stay unchecked and the app SHALL open the Login Items settings.

#### Scenario: Turn on
- **WHEN** the user checks "Open at Login" in the installed app, logs out and logs in again
- **THEN** Wobbo starts by itself and the item is checked

#### Scenario: Turn off
- **WHEN** the user unchecks "Open at Login"
- **THEN** Wobbo no longer starts at login and no longer appears under Login Items

### Requirement: Login state from macOS
The check mark of "Open at Login" SHALL show what macOS reports each time the menu opens, not a stored setting, so a change made in System Settings is reflected.

#### Scenario: Changed in System Settings
- **WHEN** the user removes Wobbo from Login Items in System Settings and then opens the menu
- **THEN** "Open at Login" is unchecked

### Requirement: Open at Login outside the app
When Wobbo does not run as an exported app bundle in an Applications folder, for example from the Godot editor or the disk image, "Open at Login" SHALL be shown disabled.

#### Scenario: Run from the editor
- **WHEN** the project runs from the Godot editor
- **THEN** "Open at Login" is shown disabled
