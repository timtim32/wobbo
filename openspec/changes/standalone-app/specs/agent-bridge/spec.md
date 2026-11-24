## MODIFIED Requirements

### Requirement: Installation
The bridge SHALL ship inside Wobbo as a Claude Code plugin named `wobbo`, in a marketplace named `wobbo`, and Wobbo SHALL install it without the user editing settings files or typing commands (see `claude-code-setup`). For development, the repository SHALL also offer the plugin through a marketplace named `wobbo-dev`. For Claude Desktop, the documentation SHALL give the exact MCP configuration entry. Removing the plugin or the entry SHALL remove all of the bridge's effects.

#### Scenario: Install in Claude Code
- **WHEN** the user connects Wobbo to Claude Code and starts a new Claude Code session
- **THEN** the session reports its status to the app and the `say` and `ask_user` tools are available

#### Scenario: Uninstall
- **WHEN** the plugin is removed, from Wobbo's menu or from Claude Code
- **THEN** new Claude Code sessions no longer contact the app

## ADDED Requirements

### Requirement: Finding the app
The bridge SHALL find the running app through the connection file in `~/Library/Application Support/Wobbo/`. When that file is missing or belongs to an app that is no longer running, it SHALL try `~/Library/Application Support/ClaudeBuddy/` as well. Texts the bridge returns to the agent SHALL name the app "Wobbo".

#### Scenario: Renamed app
- **WHEN** Wobbo is running and a Claude Code session with the bridge starts
- **THEN** the session appears as a buddy

#### Scenario: App from before the rename
- **WHEN** an app from before the rename, which writes its connection file to the `ClaudeBuddy` folder, is running and the bridge reports a session
- **THEN** the session appears as a buddy

#### Scenario: Message shown
- **WHEN** the agent calls `say` and the app shows the message
- **THEN** the tool result says the message was shown in Wobbo
