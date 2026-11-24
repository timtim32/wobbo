# Spec Delta

## ADDED Requirements

### Requirement: Go to the session
While an avatar's session waits for the user, a left click on the avatar SHALL bring the macOS app that runs the session's agent to the front, found from the agent's process, and SHALL open the session's focus link when it has one. This SHALL work for any agent connected through hooks or MCP. When neither app nor link can be found, the click SHALL do nothing visible and the reason SHALL be logged.

#### Scenario: Claude asks in the Claude app
- **WHEN** a Claude Code session in the Claude app's Code tab waits for an answer, and the user left-clicks its jumping avatar while another app is in front
- **THEN** the Claude app comes to the front and shows that session

#### Scenario: Agent in a terminal
- **WHEN** a session running in a terminal waits for the user, and the user left-clicks its avatar
- **THEN** that terminal app comes to the front

#### Scenario: Agent process gone
- **WHEN** the user left-clicks a waiting avatar whose agent process no longer exists
- **THEN** nothing comes to the front, the avatar keeps its state, and a log line names the session

## MODIFIED Requirements

### Requirement: Looking and click reaction
Avatars SHALL look at the mouse pointer, also on another display. Each avatar SHALL be an interactive region. A left click SHALL go to the session while it waits for the user, and SHALL do nothing otherwise. A right click SHALL open a context menu at the pointer with "Send home" and, in debug mode, "Type here (debug)" (opens the debug text field there). Closing it without a choice SHALL change nothing and leave the frontmost app with keyboard focus.

#### Scenario: Pointer moves
- **WHEN** the user moves the mouse pointer along the strip
- **THEN** the avatars' eyes follow the pointer

#### Scenario: Click an avatar
- **WHEN** the user left-clicks an avatar whose session is working, idle or asleep
- **THEN** nothing happens: the avatar keeps its behaviour and the frontmost app keeps keyboard focus

#### Scenario: Click next to an avatar
- **WHEN** the user clicks on the strip between two avatars
- **THEN** the click reaches the window behind the overlay

#### Scenario: Context menu
- **WHEN** the user right-clicks an avatar while typing in a terminal, then presses Escape
- **THEN** a menu with "Send home" appears at the pointer, closes on Escape without changing anything, and further typing goes to the terminal
