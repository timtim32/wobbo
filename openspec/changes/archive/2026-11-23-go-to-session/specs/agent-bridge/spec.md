# Spec Delta

## ADDED Requirements

### Requirement: Focus link
An agent adapter MAY send, with a session, a focus link: a URL that opens that session in the app that hosts the agent. When Claude Code runs in the Claude app, the bridge SHALL send the link that opens that Code session there.

#### Scenario: Claude Code in the Claude app
- **WHEN** a Claude Code session runs in the Claude app's Code tab and reports its status
- **THEN** the app receives a focus link that opens exactly that session in the Claude app

#### Scenario: Claude Code in a terminal
- **WHEN** a Claude Code session runs in a terminal
- **THEN** no focus link is sent
