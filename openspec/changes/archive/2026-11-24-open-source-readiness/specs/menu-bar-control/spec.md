## MODIFIED Requirements

### Requirement: Debug regions toggle
In debug builds (the editor and debug exports), the menu SHALL include a checkable "Debug regions" item that turns the overlay's debug region view on and off. Release builds SHALL NOT show the item, and SHALL treat the debug region view as off whatever the saved setting says.

#### Scenario: Toggle debug regions
- **WHEN** the user selects "Debug regions" in a debug build
- **THEN** the debug region view is toggled and the item's check mark reflects the new state

#### Scenario: Release build
- **WHEN** the user opens the menu of a release build
- **THEN** there is no "Debug regions" item and no debug view is shown, even if the saved setting is on
