## MODIFIED Requirements

### Requirement: Accessory app presence
The app SHALL NOT show a Dock icon and SHALL NOT appear in the Cmd-Tab application switcher or in Mission Control's window overview. This SHALL hold for the exported app from its first moment, without a Dock icon briefly appearing at launch.

#### Scenario: Running app in Dock and app switcher
- **WHEN** the app is running and the user presses Cmd-Tab or looks at the Dock
- **THEN** Wobbo does not appear there

#### Scenario: Launching the exported app
- **WHEN** the user opens `Wobbo.app` from Finder or at login
- **THEN** no Dock icon appears, not even briefly
