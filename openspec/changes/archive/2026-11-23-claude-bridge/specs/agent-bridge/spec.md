# Spec Delta

## Purpose

Connects coding agents (Claude Code now, Claude Desktop through MCP, other agents later) to the Claude Buddy app: it reports what each session is doing and lets the agent show messages and ask the user questions, without ever slowing the agent down or breaking it when the app is not running.

## ADDED Requirements

### Requirement: Session status from Claude Code
When installed in Claude Code, the bridge SHALL report each session's lifecycle and activity to the app: session start and end, a submitted prompt, a tool starting and finishing, a tool failing, a notification, the turn finishing, and the turn failing. Each report SHALL identify the session and its project directory.

#### Scenario: A prompt is worked on
- **WHEN** the user submits a prompt in a Claude Code session and Claude runs a tool and then finishes its turn
- **THEN** the app receives, in order, that the session is thinking, that it is working on that tool, and that the turn is done

#### Scenario: Session ends
- **WHEN** the user exits a Claude Code session
- **THEN** the app receives that the session ended

### Requirement: Never slow down or break the agent
Status reporting SHALL NOT delay the agent noticeably and SHALL NOT change what the agent does. When the app is not running or not reachable, the bridge SHALL do nothing visible to the agent: no error output, no failed hook, no delay of more than half a second.

#### Scenario: App not running
- **WHEN** a Claude Code session with the bridge installed runs while the Claude Buddy app is closed
- **THEN** the session behaves exactly as without the bridge, and no hook errors are shown

#### Scenario: Busy session
- **WHEN** Claude runs many tools in a row
- **THEN** each tool call is delayed by at most a few tens of milliseconds by the bridge

### Requirement: MCP tools for any agent
The bridge SHALL provide an MCP server, usable by any MCP client, with the tools `say` and `ask_user`. `say` SHALL show a short message from the agent in the app. `ask_user` SHALL ask the user a question, optionally with a list of choices and optionally allowing free text, and SHALL return the user's answer to the agent.

#### Scenario: Say something
- **WHEN** the agent calls `say` with a message
- **THEN** the app shows the message for that agent's session, and the tool returns that the message was shown

#### Scenario: Ask with choices
- **WHEN** the agent calls `ask_user` with a question and the choices "yes" and "no", and the user picks "no" in the app
- **THEN** the tool returns "no" as the answer

#### Scenario: Free-text answer
- **WHEN** the agent calls `ask_user` allowing free text and the user types an answer in the app
- **THEN** the tool returns the typed text

### Requirement: Questions without an answer
An `ask_user` call SHALL end with a clear result when it cannot be answered: when the app is not running, when the user dismisses the question, or when no answer arrives within the time-out (default 10 minutes, configurable per call). The result SHALL tell the agent to ask in its own conversation instead.

#### Scenario: App not running
- **WHEN** the agent calls `ask_user` while the app is closed
- **THEN** the tool returns at once that the buddy is not available and that the agent should ask in the conversation

#### Scenario: No answer in time
- **WHEN** the user does not answer an `ask_user` question within its time-out
- **THEN** the tool returns that no answer was given, and the question disappears from the app

### Requirement: Permission prompts in the app
When installed in Claude Code, the bridge SHALL offer each permission prompt to the app, so that the user can allow or deny it there. When the user does not decide in the app within a short wait, or the app is not running, the decision SHALL be left to Claude Code's own prompt.

#### Scenario: Allow from the app
- **WHEN** Claude asks permission to run a command and the user chooses Allow in the app
- **THEN** Claude runs the command without showing its own permission prompt

#### Scenario: Deny from the app
- **WHEN** the user chooses Deny in the app
- **THEN** Claude does not run the command and is told that the user denied it

#### Scenario: No decision in the app
- **WHEN** the user does not decide in the app within the wait
- **THEN** Claude Code shows its own permission prompt as usual

### Requirement: Session identity for MCP calls
Messages and questions sent through the MCP tools SHALL be attributed to the same session that the status reports come from, when the agent provides both. For agents that only use MCP, each MCP connection SHALL count as one session, named after the agent.

#### Scenario: Claude Code session
- **WHEN** Claude calls `say` in a Claude Code session that also reports its status through hooks
- **THEN** the app shows the message for that same session, not as a new session

#### Scenario: Claude Desktop Code tab
- **WHEN** Claude, in a Claude Desktop Code-tab session, calls `say` through the MCP server from the Claude Desktop configuration
- **THEN** the app shows the message for that Code-tab session, not as a separate session

#### Scenario: Claude Desktop
- **WHEN** Claude Desktop calls `say` from a chat
- **THEN** the app shows the message for a session named after Claude Desktop

### Requirement: Installation
The bridge SHALL be installable in Claude Code as a plugin from a marketplace in this repository, without editing the user's own settings files by hand. For Claude Desktop, the documentation SHALL give the exact MCP configuration entry. Removing the plugin or the entry SHALL remove all of the bridge's effects.

#### Scenario: Install in Claude Code
- **WHEN** the user follows the documented plugin install steps and starts a new Claude Code session
- **THEN** the session reports its status to the app and the `say` and `ask_user` tools are available

#### Scenario: Uninstall
- **WHEN** the user uninstalls the plugin
- **THEN** new Claude Code sessions no longer contact the app

### Requirement: Open to other agents
The protocol and the bridge SHALL name the agent in every session and keep agent-specific code in separate adapters, so that support for another coding agent can be added without changing the app or the protocol.

#### Scenario: Agent named per session
- **WHEN** sessions from Claude Code and Claude Desktop are active at the same time
- **THEN** the app can tell which agent each session belongs to
