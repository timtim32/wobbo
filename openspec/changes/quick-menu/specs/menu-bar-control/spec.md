## ADDED Requirements

### Requirement: The menu opens at once
Opening the app menu SHALL NOT wait on slow system queries. Wobbo SHALL ask macOS for the "Open at Login" state in the background and SHALL show the last known state until the answer arrives; the check mark SHALL then update, also while the menu is open. The overlay SHALL keep animating while the menu opens and while it is open.

#### Scenario: Menu opens without delay
- **WHEN** the user clicks the menu bar icon
- **THEN** the menu appears without a noticeable delay

#### Scenario: Wobbos keep moving
- **WHEN** the user opens the menu while Wobbos walk across the screen
- **THEN** the Wobbos keep moving smoothly, without a pause

#### Scenario: Login state changed elsewhere
- **WHEN** the user has removed Wobbo from Login Items in System Settings and then opens the menu
- **THEN** "Open at Login" becomes unchecked shortly after the menu appears
