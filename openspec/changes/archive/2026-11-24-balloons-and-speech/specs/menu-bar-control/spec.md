# Spec Delta

## ADDED Requirements

### Requirement: Messages
The menu SHALL include a "Messages" submenu. It SHALL hold the radio items "Balloons", "Speech", "Balloons and Speech" and "Off", with exactly one checked, then the check items "Turn finished" and "Errors". A choice SHALL take effect at once. When macOS offers no voice, the two speech items SHALL be disabled.

#### Scenario: Choose the output
- **WHEN** the user opens "Messages" and chooses "Balloons and Speech"
- **THEN** that item is checked, and the next message appears in a balloon and is spoken

#### Scenario: Turn messages off
- **WHEN** the user chooses "Off"
- **THEN** "Off" is checked, open balloons close, and no message is shown or spoken until another output is chosen

#### Scenario: Notices on and off
- **WHEN** the user unchecks "Errors"
- **THEN** a failed turn no longer shows or speaks a notice, while questions and messages still appear

## MODIFIED Requirements

### Requirement: Persisted settings
Settings changed through the menu (at least overlay visibility, screen choice, buddy size, debug regions, the message output and the two notices) SHALL persist across launches in a per-user settings file. A missing or unreadable file SHALL fall back to defaults: visible, screen automatic, size Normal, debug off, output Balloons, "Turn finished" on and "Errors" on.

#### Scenario: Setting survives restart
- **WHEN** the user hides the overlay, quits, and starts the app again
- **THEN** the overlay starts hidden and the menu shows "Show Buddies"

#### Scenario: Screen choice survives restart
- **WHEN** the user chooses the external display, quits, and starts the app again with that display connected
- **THEN** the buddies start on the external display and it is checked under "Screen"

#### Scenario: Size survives restart
- **WHEN** the user chooses "Extra large", quits, and starts the app again
- **THEN** the buddies are about 170 points tall and "Extra large" is checked under "Size"

#### Scenario: Messages choice survives restart
- **WHEN** the user chooses "Off" under "Messages", quits, and starts the app again
- **THEN** "Off" is still checked and no balloons appear

#### Scenario: Corrupt settings file
- **WHEN** the settings file is not valid at startup
- **THEN** the app starts with default settings and does not crash
