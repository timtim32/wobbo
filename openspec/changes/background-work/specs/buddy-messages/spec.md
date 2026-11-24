## MODIFIED Requirements

### Requirement: Turn finished notice
When "Turn finished" is on, a session whose turn ends after at least 20 seconds since the user's prompt SHALL show the notice "Done" (spoken: "<name> is done"). Shorter turns SHALL NOT be announced. A turn that ends while background commands still run SHALL NOT be announced.

#### Scenario: Long task finished
- **WHEN** a turn of the "api" session ends 3 minutes after the prompt
- **THEN** the "api" buddy shows "Done"

#### Scenario: Quick reply
- **WHEN** a turn ends 5 seconds after the prompt
- **THEN** no notice appears

#### Scenario: Turned off
- **WHEN** "Turn finished" is unchecked and a long turn ends
- **THEN** no notice appears and the buddy still does its happy jump

#### Scenario: Waiting for a background command
- **WHEN** a turn of the "api" session ends 3 minutes after the prompt with a background command still running, and Claude ends its turn again 5 minutes later with nothing running in the background
- **THEN** the "api" buddy shows no notice at the first end, and shows "Done" at the second
