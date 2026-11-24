# Spec Delta

## Purpose

Gives every coding-agent session its own monster on the overlay, so the user can see at a glance which sessions are running and what each one is doing.

## ADDED Requirements

### Requirement: One avatar per session
Each active agent session SHALL have its own avatar on the home display's strip. A new session's avatar SHALL start walking in within 2 seconds from an outer edge of the displays (one with no display beyond it). When a session ends, its avatar SHALL wave and then walk off at an outer edge, crossing displays in between, so it never vanishes mid-screen. A session removed without ending SHALL have its avatar walk off without waving. With no active sessions, no avatar SHALL be shown.

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

### Requirement: Behaviour follows session state
An avatar SHALL show its session's state: `thinking`, `working` and `waiting` each with their own looping clip while standing at its spot, a short happy reaction for `done`, a startled flinch for `error`, and strolling around its spot while `idle` or after a reaction. It SHALL take on a new state within 1 second, or on arrival when it is walking in, walking off or travelling.

#### Scenario: A prompt is worked on
- **WHEN** the session goes from `thinking` to `working` to `done`
- **THEN** the avatar plays its thinking clip, then its working clip, then a happy reaction, and then strolls around its spot

#### Scenario: Waiting for the user
- **WHEN** the session asks the user a question or for permission
- **THEN** the avatar stands at its spot and plays its waiting clip until the request is answered or withdrawn

#### Scenario: Error
- **WHEN** the session reports an error
- **THEN** the avatar flinches once and then strolls around its spot

#### Scenario: State changes while walking in
- **WHEN** a session's state changes while its avatar is still walking in
- **THEN** the avatar keeps walking, and plays the clip of the current state once it has reached its spot

### Requirement: Sleeping and waking
An avatar whose session has had no activity for 2 minutes while `idle`, `done` or `error` SHALL fall asleep at its spot. It SHALL wake up and show the session's state when the session becomes active again. An avatar in `thinking`, `working` or `waiting` SHALL NOT fall asleep.

#### Scenario: Falling asleep
- **WHEN** a session stays `done` for 2 minutes without new activity
- **THEN** its avatar stops at its spot and plays its sleep clip

#### Scenario: Waking up
- **WHEN** a sleeping avatar's session receives a new prompt
- **THEN** the avatar wakes up and plays its thinking clip

#### Scenario: Long wait does not sleep
- **WHEN** a session has been `waiting` for the user for 5 minutes
- **THEN** its avatar still plays its waiting clip

### Requirement: Recognisable per session
Each avatar SHALL have a colour taken from a fixed set of hues that keep the character readable. Avatars on screen at the same time SHALL have different colours. An avatar SHALL keep its colour for as long as it is on screen. Each avatar SHALL show a small label with its session's display name, unless the user turned names off in the menu. The label stays with the avatar while it moves, also across displays, and does not cover another avatar's label.

#### Scenario: Two sessions side by side
- **WHEN** two sessions of the projects "claude-buddy" and "website" are active
- **THEN** their avatars have clearly different colours and show the labels "claude-buddy" and "website"

#### Scenario: Colour is stable
- **WHEN** a session's state changes many times, or the home display changes
- **THEN** its avatar keeps the same colour and label

#### Scenario: Label while crossing
- **WHEN** an avatar walks from one display to the next
- **THEN** its label moves along with it and is shown on both displays for the parts on each

### Requirement: Sharing the strip
Each avatar on screen SHALL have its own spot on the home display, spread over its width, and avatars SHALL NOT stand or stroll on top of each other. An avatar SHALL keep its spot while other avatars come and go, unless the spots no longer fit.

#### Scenario: Three sessions
- **WHEN** three sessions are active
- **THEN** three avatars stand or stroll at separate spots on the home display without overlapping

### Requirement: At most five avatars
At most 5 avatars SHALL be on screen. When more than 5 sessions are active, sessions waiting for the user SHALL have an avatar first, and the remaining places SHALL go to the most recently active sessions. When another session becomes active, the avatar of the session that has been quiet the longest SHALL walk off and the newly active session's avatar SHALL walk in.

#### Scenario: A sixth session becomes active
- **WHEN** five avatars are on screen and a sixth session submits a prompt
- **THEN** the avatar of the session that has been quiet the longest walks off, and an avatar for the sixth session walks in

#### Scenario: Waiting session keeps its avatar
- **WHEN** a session is waiting for the user and five other sessions become active after it
- **THEN** the waiting session's avatar stays on screen

#### Scenario: Session without avatar ends
- **WHEN** a session without an avatar on screen ends
- **THEN** no avatar enters or leaves for it

### Requirement: Looking and click reaction
Avatars SHALL look at the mouse pointer, also when it is on another display. Each avatar SHALL be an interactive region of the overlay. A left click on an avatar SHALL make it react happily without changing its session's state, and SHALL NOT take keyboard focus from the frontmost app. In debug mode, a right click on an avatar SHALL open the debug text field at that avatar.

#### Scenario: Pointer moves
- **WHEN** the user moves the mouse pointer along the strip
- **THEN** the avatars' eyes follow the pointer

#### Scenario: Click an avatar
- **WHEN** the user left-clicks an avatar
- **THEN** it plays its happy reaction and then returns to the behaviour of its session's state, and the frontmost app keeps keyboard focus

#### Scenario: Click next to an avatar
- **WHEN** the user clicks on the strip between two avatars
- **THEN** the click reaches the window behind the overlay

### Requirement: Low cost while quiet
While no avatar is on screen, or every avatar on screen is asleep, the app SHALL lower its frame rate so that it uses clearly less CPU than with a strolling avatar. It SHALL return to its normal frame rate within 1 second when an avatar enters, wakes up or is clicked, or when the pointer moves over the strip.

#### Scenario: All asleep
- **WHEN** every avatar on screen has fallen asleep
- **THEN** the app uses clearly less CPU than with one strolling avatar

#### Scenario: Waking from the quiet mode
- **WHEN** all avatars sleep and one session receives a prompt
- **THEN** within 1 second its avatar wakes up and moves smoothly again
