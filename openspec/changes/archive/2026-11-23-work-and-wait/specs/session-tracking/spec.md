# Spec Delta

## MODIFIED Requirements

### Requirement: Session list and state
The app SHALL keep a list of active sessions. Each session SHALL have an identifier, the agent's name, a display name derived from its project directory, and a state: `idle`, `thinking`, `working` (with the tool name), `waiting` (for the user), `done`, `error` or `ended`. A session SHALL be `waiting` while it has a pending request, and from a report that the agent waits for the user until its next state event. A session SHALL be added on its first event and removed shortly after it ends.

#### Scenario: Session appears
- **WHEN** the first event of a new session arrives
- **THEN** the session is added with its agent, display name and state

#### Scenario: State follows activity
- **WHEN** a session reports a submitted prompt, then a tool start, then the end of the turn
- **THEN** its state changes from `thinking` to `working` to `done`

#### Scenario: Agent waits for the user
- **WHEN** a session reports that the agent waits for the user, and later that the tool finished
- **THEN** its state is `waiting` until the tool finished, and `thinking` after that

#### Scenario: Session ends
- **WHEN** a session reports that it ended
- **THEN** its state becomes `ended` and it is removed from the list a few seconds later

#### Scenario: Session disappears silently
- **WHEN** a session sends no events for 30 minutes and has no open connection
- **THEN** it is removed from the list
