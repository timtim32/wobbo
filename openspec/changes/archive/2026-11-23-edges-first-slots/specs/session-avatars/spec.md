# Spec Delta

## MODIFIED Requirements

### Requirement: Sharing the strip
Each avatar on screen SHALL have its own spot on the home display, spread over its width, and avatars SHALL NOT stand or stroll on top of each other. An avatar SHALL keep its spot while other avatars come and go, unless the spots no longer fit. A newly arriving avatar SHALL take the free spot nearest to a screen edge, the left edge first, then alternating between the right and left side going inward, so the middle spot is taken last.

#### Scenario: Three sessions
- **WHEN** three sessions are active
- **THEN** three avatars stand or stroll at separate spots on the home display without overlapping

#### Scenario: One session
- **WHEN** one session is active and no other avatar is on screen
- **THEN** its avatar walks in from the left and stands at the leftmost spot of the home display

#### Scenario: Two sessions
- **WHEN** a second session becomes active while one avatar stands at the leftmost spot
- **THEN** the second avatar walks in from the right and stands at the rightmost spot

#### Scenario: Five sessions
- **WHEN** five sessions become active one after another on a display with five spots
- **THEN** their avatars take the spots in the order leftmost, rightmost, second from the left, second from the right, middle

#### Scenario: A gap stays until filled
- **WHEN** three avatars stand at the leftmost, rightmost and second-from-left spots and the leftmost avatar walks off
- **THEN** the other two keep their spots, and the next avatar to arrive takes the leftmost spot
