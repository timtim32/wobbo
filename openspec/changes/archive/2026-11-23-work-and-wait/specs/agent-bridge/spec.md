# Spec Delta

## MODIFIED Requirements

### Requirement: Session status from Claude Code
When installed in Claude Code, the bridge SHALL report each session's lifecycle and activity to the app: session start and end, a submitted prompt, a tool starting and finishing, a tool failing, a notification, the turn finishing, and the turn failing. It SHALL report that the agent waits for the user when Claude starts a tool that asks the user (a question or plan approval) or Claude Code shows a permission prompt or an input dialog. Each report SHALL identify the session and its project directory.

#### Scenario: A prompt is worked on
- **WHEN** the user submits a prompt in a Claude Code session and Claude runs a tool and then finishes its turn
- **THEN** the app receives, in order, that the session is thinking, that it is working on that tool, and that the turn is done

#### Scenario: Claude asks the user
- **WHEN** Claude asks the user a question with its question tool, or Claude Code shows a permission prompt in the terminal
- **THEN** the app receives that the session waits for the user, and not that it is working

#### Scenario: Session ends
- **WHEN** the user exits a Claude Code session
- **THEN** the app receives that the session ended
