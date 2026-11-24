## MODIFIED Requirements

### Requirement: Session status from Claude Code
When installed in Claude Code, the bridge SHALL report each session's lifecycle and activity to the app: session start and end, a submitted prompt, a tool starting and finishing, a tool failing, a notification, the turn finishing, and the turn failing. It SHALL report that the agent waits for the user when Claude asks a question, asks to approve a plan, or shows a permission prompt or input dialog. When the turn finishes while commands Claude started in the background still run, the report of the turn finishing SHALL carry how many still run. Each report SHALL identify the session and its project directory.

#### Scenario: A prompt is worked on
- **WHEN** the user submits a prompt in a Claude Code session and Claude runs a tool and then finishes its turn
- **THEN** the app receives, in order, that the session is thinking, that it is working on that tool, and that the turn is done

#### Scenario: Claude asks the user
- **WHEN** Claude asks the user a question with its question tool, or Claude Code shows a permission prompt in the terminal
- **THEN** the app receives that the session waits for the user, and not that it is working

#### Scenario: Session ends
- **WHEN** the user exits a Claude Code session
- **THEN** the app receives that the session ended

#### Scenario: Turn ends while a background command runs
- **WHEN** Claude starts a script in the background and ends its turn to wait for it
- **THEN** the app receives that the turn is done with one background command still running

#### Scenario: Background command already finished
- **WHEN** Claude started a command in the background, was told that it ended, and then ends its turn
- **THEN** the app receives that the turn is done with no background command running

#### Scenario: Transcript not readable
- **WHEN** the bridge cannot read the session's transcript at the end of a turn
- **THEN** the app receives that the turn is done with no background command running, and the agent is not slowed down or disturbed
