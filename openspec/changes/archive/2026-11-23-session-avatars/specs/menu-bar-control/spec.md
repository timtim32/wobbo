# Spec Delta

## ADDED Requirements

### Requirement: Demo
The menu SHALL include "Play Demo", which plays a scripted show of about a minute and a half with pretend sessions: their avatars walk in, show the session states, react, swap when more than five sessions are active, and walk off again. Pretend sessions SHALL exist only inside the app and SHALL NOT reach any agent. While the demo runs, the item SHALL read "Stop Demo", and choosing it SHALL end all pretend sessions. Real sessions SHALL keep working during the demo.

#### Scenario: Play the demo
- **WHEN** the user chooses "Play Demo"
- **THEN** pretend sessions' avatars walk in and go through thinking, working, waiting, a happy reaction, an error, a swap and a goodbye, and after the show no pretend session is left

#### Scenario: Stop the demo
- **WHEN** the user chooses "Stop Demo" while the demo runs
- **THEN** all pretend sessions end, their avatars wave and walk off, and the item reads "Play Demo" again

#### Scenario: Real session during the demo
- **WHEN** a real agent session is active while the demo runs
- **THEN** its avatar keeps showing its own state, and the demo does not change it

### Requirement: Names toggle
The menu SHALL include a checkable "Show Names" item that shows or hides the avatars' name labels. It SHALL be on by default, and the choice SHALL persist across launches like the other menu settings.

#### Scenario: Hide the names
- **WHEN** the user unchecks "Show Names"
- **THEN** every avatar's name label disappears at once, also on avatars that walk in later, while the avatars themselves stay

#### Scenario: Names choice survives restart
- **WHEN** the user hides the names, quits, and starts the app again
- **THEN** the avatars have no name labels and "Show Names" is unchecked
