# session-tracking Specification

## Purpose

The Wobbo app's side of the agent connection: a local, protected endpoint that keeps track of every active coding session, its state and its messages, and holds questions and permission prompts until the user answers them.

## Requirements

### Requirement: Local, protected endpoint
While running, the app SHALL accept bridge connections on the loopback interface only, and SHALL reject any connection that does not present the current install token. The app SHALL publish its port and token in a file in its settings folder that only the current user can read, and remove or invalidate it when it quits.

#### Scenario: Bridge connects
- **WHEN** the bridge reads the port and token from the file and connects
- **THEN** the app accepts the connection

#### Scenario: Wrong token
- **WHEN** a local process connects without the correct token
- **THEN** the app closes the connection and ignores its messages

#### Scenario: Not reachable from the network
- **WHEN** another machine on the network tries to connect to the app's port
- **THEN** the connection is refused

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

### Requirement: Messages from the agent
The app SHALL keep the most recent message an agent sent with `say` for each session, and make it available to the overlay content.

#### Scenario: Message arrives
- **WHEN** an agent says "Tests are green"
- **THEN** the session's latest message is "Tests are green"

### Requirement: Requests waiting for the user
The app SHALL hold each question and permission prompt as a pending request of its session, with its text, its choices (or Allow/Deny for permissions) and whether free text is allowed. While a request is pending the session's state SHALL be `waiting`. The user SHALL be able to answer or dismiss it in the app, and the answer SHALL be sent back to the agent that asked. A request SHALL be withdrawn when the asker gives up (time-out, disconnect).

#### Scenario: Answer a question
- **WHEN** a question with choices is pending and the user picks one in the app
- **THEN** the answer is sent to the agent, the request disappears and the session leaves `waiting`

#### Scenario: Asker gives up
- **WHEN** a question times out on the agent's side or its connection closes
- **THEN** the request disappears from the app

#### Scenario: Several requests
- **WHEN** two sessions each have a pending request
- **THEN** both are shown and each answer goes to the session that asked

### Requirement: Debug panel
In debug mode, the overlay SHALL show a panel that lists the active sessions with their agent, name, state and latest message, and lets the user answer or dismiss pending requests. The panel SHALL be an interactive region of the overlay, and the rest of the strip SHALL stay click-through.

#### Scenario: Panel in debug mode
- **WHEN** debug mode is on and two sessions are active
- **THEN** the panel lists both sessions with their current state

#### Scenario: Debug mode off
- **WHEN** debug mode is turned off
- **THEN** the panel is hidden and its region is removed

### Requirement: Session focus link
The app SHALL keep the latest focus link a session reported. It SHALL only use a focus link whose URL scheme is on its list of known agent hosts, and SHALL ignore any other link.

#### Scenario: Link kept
- **WHEN** a session reports a focus link with the `claude` scheme
- **THEN** the session's focus link is that URL

#### Scenario: Unknown scheme
- **WHEN** a session reports a focus link with a `file` or `https` scheme
- **THEN** the app does not keep it
