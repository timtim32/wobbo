# Spec Delta

## ADDED Requirements

### Requirement: Sending a buddy home
A session's avatar SHALL go home, walking off at an outer edge, when it has been asleep for 15 minutes, or when the user chooses "Send home" in its context menu. Its session SHALL then be away: it keeps running in the agent and in the app, but has no avatar. Away sessions SHALL NOT count towards the at most 5 avatars.

#### Scenario: Going home by itself
- **WHEN** a session stays idle until its avatar has slept for 15 minutes
- **THEN** the avatar wakes up, walks off at an outer edge, and does not come back while the session stays idle

#### Scenario: Send home from the menu
- **WHEN** the user right-clicks an avatar and chooses "Send home"
- **THEN** the avatar walks off at an outer edge right away, and the agent session is not affected

#### Scenario: Away frees a place
- **WHEN** five avatars are on screen, a sixth session is active without one, and the user sends one avatar home
- **THEN** the sixth session's avatar walks in

### Requirement: Away sessions come back
An away session SHALL get its avatar back, walking in as usual, when it is used again: a new prompt, a tool start, or a question or permission request. Background notifications SHALL NOT bring it back.

#### Scenario: Coming back
- **WHEN** an away session receives a new prompt
- **THEN** within 2 seconds its avatar walks in again and shows the thinking clip

#### Scenario: Notifications do not bring it back
- **WHEN** an away session only sends a background notification
- **THEN** its avatar stays away

## MODIFIED Requirements

### Requirement: One avatar per session
Each active agent session that is not away SHALL have its own avatar on the home display's strip. A new session's avatar SHALL start walking in within 2 seconds from an outer edge of the displays (one with no display beyond it). When a session ends, its avatar SHALL wave and then walk off at an outer edge, crossing displays in between, so it never vanishes mid-screen. A session removed without ending SHALL have its avatar walk off without waving. With no active sessions, no avatar SHALL be shown.

#### Scenario: Session starts
- **WHEN** a new agent session sends its first event
- **THEN** within 2 seconds an avatar for it starts walking in from the nearest outer edge of the displays and stops at its own spot on the home display

#### Scenario: Session ends
- **WHEN** a session with an avatar reports that it ended
- **THEN** the avatar waves and walks to the nearest outer edge of the displays, crossing any display in between, and disappears beyond that edge

#### Scenario: Session disappears silently
- **WHEN** a session is removed because it sent no events for a long time
- **THEN** its avatar walks off at the nearest outer edge without waving

#### Scenario: No sessions
- **WHEN** no agent session is active
- **THEN** the overlay shows no avatar, and every point of the strips passes clicks through

### Requirement: Looking and click reaction
Avatars SHALL look at the mouse pointer, also when it is on another display. Each avatar SHALL be an interactive region of the overlay. A left click on an avatar SHALL make it react happily without changing its session's state, and SHALL NOT take keyboard focus from the frontmost app. A right click on an avatar SHALL open a context menu at the pointer with "Send home" and, in debug mode, "Type here (debug)", which opens the debug text field at that avatar. Closing the menu without a choice SHALL change nothing, and the previously frontmost app SHALL have keyboard focus again afterwards.

#### Scenario: Pointer moves
- **WHEN** the user moves the mouse pointer along the strip
- **THEN** the avatars' eyes follow the pointer

#### Scenario: Click an avatar
- **WHEN** the user left-clicks an avatar
- **THEN** it plays its happy reaction and then returns to the behaviour of its session's state, and the frontmost app keeps keyboard focus

#### Scenario: Click next to an avatar
- **WHEN** the user clicks on the strip between two avatars
- **THEN** the click reaches the window behind the overlay

#### Scenario: Context menu
- **WHEN** the user right-clicks an avatar while typing in a terminal, then presses Escape
- **THEN** a menu with "Send home" appears at the pointer, closes on Escape without changing anything, and further typing goes to the terminal
