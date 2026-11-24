# Spec Delta

## ADDED Requirements

### Requirement: Buddy size
The menu SHALL include a "Size" submenu with the radio items "Small", "Normal", "Large" and "Extra large", for buddies of about 80, 110, 140 and 170 points tall. Exactly one item SHALL be checked. Choosing an item SHALL resize every buddy on screen within 1 second, and buddies that appear later SHALL have the chosen size too.

#### Scenario: Choose a size
- **WHEN** the user opens "Size" and chooses "Large"
- **THEN** "Large" is checked and every buddy becomes about 140 points tall, with its name label above its head and clicks working on its new outline

#### Scenario: New buddies use the size
- **WHEN** the size is "Small" and a new session starts
- **THEN** its buddy walks in at about 80 points tall

## MODIFIED Requirements

### Requirement: Persisted settings
Settings changed through the menu (at least overlay visibility, screen choice, buddy size and debug regions) SHALL persist across launches in a per-user settings file. A missing or unreadable file SHALL fall back to defaults: visible, screen automatic, size Normal, debug off.

#### Scenario: Setting survives restart
- **WHEN** the user hides the overlay, quits, and starts the app again
- **THEN** the overlay starts hidden and the menu shows "Show Buddies"

#### Scenario: Screen choice survives restart
- **WHEN** the user chooses the external display, quits, and starts the app again with that display connected
- **THEN** the buddies start on the external display and it is checked under "Screen"

#### Scenario: Size survives restart
- **WHEN** the user chooses "Extra large", quits, and starts the app again
- **THEN** the buddies are about 170 points tall and "Extra large" is checked under "Size"

#### Scenario: Corrupt settings file
- **WHEN** the settings file is not valid at startup
- **THEN** the app starts with default settings and does not crash
