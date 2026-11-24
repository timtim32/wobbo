# Spec Delta

## ADDED Requirements

### Requirement: Question text from the agent's own window
When Claude asks the user in its own UI (Claude Code's question tool, a plan to approve, or the Claude app's next-step question), the bridge SHALL send the question's text and its answer options with the status report, so the app can show them. Reports of these questions SHALL stay as fast and as harmless as other status reports.

#### Scenario: Question tool
- **WHEN** Claude asks "Which database?" with the options "Postgres" and "SQLite" in Claude Code's question tool
- **THEN** the app receives that the session waits for the user, with the question "Which database?" and the options "Postgres" and "SQLite"

#### Scenario: Next-step question
- **WHEN** a Claude Code session in the Claude app ends its turn with a next-step question and its buttons
- **THEN** the app receives the question and the button labels

#### Scenario: Unknown shape
- **WHEN** the Claude app's next-step tool is called without a question, or with fields the bridge does not know
- **THEN** the bridge reports a plain tool start, as for any other tool
