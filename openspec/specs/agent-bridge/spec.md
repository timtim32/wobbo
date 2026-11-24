# agent-bridge Specification

## Purpose

Connects coding agents (Claude Code now, Claude Desktop through MCP, other agents later) to the Wobbo app: it reports what each session is doing and lets the agent show messages and ask the user questions, without ever slowing the agent down or breaking it when the app is not running.

## Requirements

### Requirement: Session status from Claude Code
When installed in Claude Code, the bridge SHALL report each session's lifecycle and activity to the app: session start and end, a submitted prompt, a tool starting and finishing, a tool failing, a notification, the turn finishing, and the turn failing. It SHALL report that the agent waits for the user when Claude asks a question, asks to approve a plan, or shows a permission prompt or input dialog. Each report SHALL identify the session and its project directory.

#### Scenario: A prompt is worked on
- **WHEN** the user submits a prompt in a Claude Code session and Claude runs a tool and then finishes its turn
- **THEN** the app receives, in order, that the session is thinking, that it is working on that tool, and that the turn is done

#### Scenario: Claude asks the user
- **WHEN** Claude asks the user a question with its question tool, or Claude Code shows a permission prompt in the terminal
- **THEN** the app receives that the session waits for the user, and not that it is working

#### Scenario: Session ends
- **WHEN** the user exits a Claude Code session
- **THEN** the app receives that the session ended

### Requirement: Never slow down or break the agent
Status reporting SHALL NOT delay the agent noticeably and SHALL NOT change what the agent does. When the app is not running or not reachable, the bridge SHALL do nothing visible to the agent: no error output, no failed hook, no delay of more than half a second.

#### Scenario: App not running
- **WHEN** a Claude Code session with the bridge installed runs while the Wobbo app is closed
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
When installed in Claude Code, the bridge SHALL offer each permission prompt to the app, so that the user can allow or deny it there, but only when the app can show what is being asked in full. When the description had to be cut, or the request has more than one significant argument, the bridge SHALL NOT offer it to the app. When the user does not decide in the app within a short wait, when the prompt is not offered, or when the app is not running, the decision SHALL be left to Claude Code's own prompt.

#### Scenario: Allow from the app
- **WHEN** Claude asks permission to run a command and the user chooses Allow in the app
- **THEN** Claude runs the command without showing its own permission prompt

#### Scenario: Deny from the app
- **WHEN** the user chooses Deny in the app
- **THEN** Claude does not run the command and is told that the user denied it

#### Scenario: No decision in the app
- **WHEN** the user does not decide in the app within the wait
- **THEN** Claude Code shows its own permission prompt as usual

#### Scenario: Request too long to show
- **WHEN** Claude asks permission to run a command whose description is longer than the app can show
- **THEN** the app offers no Allow or Deny for it, the session's Wobbo shows that it is waiting, and Claude Code shows its own permission prompt without waiting

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

### Requirement: Focus link
An agent adapter MAY send, with a session, a focus link: a URL that opens that session in the app that hosts the agent. When Claude Code runs in the Claude app, the bridge SHALL send the link that opens that Code session there.

#### Scenario: Claude Code in the Claude app
- **WHEN** a Claude Code session runs in the Claude app's Code tab and reports its status
- **THEN** the app receives a focus link that opens exactly that session in the Claude app

#### Scenario: Claude Code in a terminal
- **WHEN** a Claude Code session runs in a terminal
- **THEN** no focus link is sent

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
