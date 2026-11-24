## MODIFIED Requirements

### Requirement: Installation
The bridge SHALL ship inside Wobbo as a Claude Code plugin named `wobbo`, in a marketplace named `wobbo`, and Wobbo SHALL install it without the user editing settings files or typing commands (see `claude-code-setup`). For development, the repository SHALL also offer the plugin through a marketplace named `wobbo-dev`. For Claude Desktop, Wobbo SHALL add the MCP configuration entry itself (see `claude-desktop-setup`), and `print-config claude-desktop` SHALL keep printing that entry for development. Removing the plugin or the entry SHALL remove all of the bridge's effects.

#### Scenario: Install in Claude Code
- **WHEN** the user connects Wobbo to Claude Code and starts a new Claude Code session
- **THEN** the session reports its status to the app and the `say` and `ask_user` tools are available

#### Scenario: Install in Claude Desktop
- **WHEN** the user connects Wobbo while Claude Desktop is on the Mac, restarts Claude Desktop and opens a chat
- **THEN** the `say` and `ask_user` tools are available in that chat

#### Scenario: Uninstall
- **WHEN** the plugin is removed, from Wobbo's menu or from Claude Code
- **THEN** new Claude Code sessions no longer contact the app

### Requirement: Session identity for MCP calls
Messages and questions sent through the MCP tools SHALL be attributed to the same session that the status reports come from, when the agent provides both. For agents that only use MCP, each MCP connection SHALL count as one session, named after the agent. In Claude Desktop's Code tab, the Desktop server's messages SHALL go to the Code session that sent them, also when Claude Desktop's name for the project differs from its folder name.

#### Scenario: Claude Code session
- **WHEN** Claude calls `say` in a Claude Code session that also reports its status through hooks
- **THEN** the app shows the message for that same session, not as a new session

#### Scenario: Claude Desktop Code tab
- **WHEN** Claude, in a Claude Desktop Code-tab session, calls `say` through the MCP server from the Claude Desktop configuration
- **THEN** the app shows the message for that Code-tab session, not as a separate session

#### Scenario: Code tab project named differently
- **WHEN** Claude Desktop calls the project "wobbo" while its folder is `claude-buddy`, and Claude in a Code-tab session there calls `say` through the Desktop server
- **THEN** the app shows the message on that session's buddy, and no new buddy appears

#### Scenario: Claude Desktop
- **WHEN** Claude Desktop calls `say` from a chat
- **THEN** the app shows the message for a session named "Claude Desktop"

## ADDED Requirements

### Requirement: Claude Desktop configuration command
The bridge SHALL offer `claude-desktop connect`, which sets the `wobbo` entry in Claude Desktop's `mcpServers` to its own binary, and `claude-desktop disconnect`, which removes it. Both SHALL remove other entries that run a `wobbo-bridge` or `claude-buddy-bridge` binary, keep every other value, and leave a file that is not valid JSON untouched.

#### Scenario: Other servers kept
- **WHEN** the configuration lists another MCP server and preferences, and `claude-desktop connect` runs
- **THEN** the other server and the preferences are unchanged and the `wobbo` entry is added

#### Scenario: Stale entry replaced
- **WHEN** the configuration has a `claude-buddy` entry whose command is `.../claude-buddy-bridge`, and `claude-desktop connect` runs
- **THEN** that entry is gone and the `wobbo` entry is present

#### Scenario: Broken file
- **WHEN** the configuration is not valid JSON and `claude-desktop connect` runs
- **THEN** the file is unchanged and the command exits with an error
