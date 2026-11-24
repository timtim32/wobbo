## ADDED Requirements

### Requirement: Set up Claude Desktop when connecting
When the user connects Wobbo to Claude Code and Claude Desktop is on the Mac, Wobbo SHALL add its MCP entry to Claude Desktop's configuration without the user editing files or typing commands. The entry SHALL point at the bridge in Wobbo's data folder. When the entry was added or changed, the balloon SHALL say to restart Claude Desktop. When Claude Desktop's step fails, connecting to Claude Code SHALL still count as done.

#### Scenario: Connect with Claude Desktop
- **WHEN** the user chooses "Connect to Claude Code", Claude Desktop is installed, and the user restarts Claude Desktop
- **THEN** Claude Desktop's chats have the `say` and `ask_user` tools, and the balloon had said to restart Claude Desktop

#### Scenario: No Claude Desktop
- **WHEN** the user connects on a Mac without Claude Desktop
- **THEN** no Claude Desktop file is created, and the balloon does not mention Claude Desktop

#### Scenario: Unreadable configuration
- **WHEN** Claude Desktop's configuration is not valid JSON and the user connects
- **THEN** that file is unchanged, Wobbo is connected to Claude Code, and the failure is logged

### Requirement: Keep Claude Desktop's entry current
When Wobbo starts while connected to Claude Code, it SHALL make sure its Claude Desktop entry exists and points at its current bridge, also when the plugin itself needs no update. When it added or changed the entry, it SHALL say once, in a balloon, to restart Claude Desktop.

#### Scenario: Connected before this change
- **WHEN** a user who connected with an older Wobbo, and has Claude Desktop, starts this version
- **THEN** the entry is added and a balloon says to restart Claude Desktop

#### Scenario: Nothing to do
- **WHEN** Wobbo starts, connected, with the entry already current
- **THEN** the configuration file is not written and no balloon is shown for it

### Requirement: Remove Claude Desktop's entry when disconnecting
Disconnecting from Claude Code SHALL also remove Wobbo's entry from Claude Desktop's configuration.

#### Scenario: Disconnect
- **WHEN** the user chooses "Disconnect from Claude Code" and later restarts Claude Desktop
- **THEN** Claude Desktop's configuration no longer has a Wobbo entry, and its chats no longer have Wobbo's tools
