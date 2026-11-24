# multi-display Specification

## Purpose

Lets Wobbo's buddies live on every connected display. They gather on one home display, chosen by the user or following the mouse, and walk from screen to screen along the bottom edges instead of jumping.

## Requirements

### Requirement: Walkway across displays
The overlay SHALL treat the bottom strips of all connected displays as one walkway, ordered by the displays' horizontal arrangement from left to right. Buddies SHALL be able to stand on any part of the walkway, and a buddy that is crossing from one display to the next SHALL be drawn on both displays for the part that is on each. Its size SHALL be the same in points on both.

#### Scenario: Two displays side by side
- **WHEN** a built-in display and an external display to its right are connected
- **THEN** the walkway runs from the left edge of the built-in display's strip to the right edge of the external display's strip

#### Scenario: Crossing the edge
- **WHEN** a buddy walks over the right edge of the left display
- **THEN** the part that has crossed is shown at the left edge of the right display's strip, and the rest is still shown on the left display, until it has fully crossed

#### Scenario: Different display scales
- **WHEN** a buddy stands on a Retina display and on a non-Retina display in turn
- **THEN** it is the same size in points on both and looks sharp on both

### Requirement: Home display
The buddies SHALL gather on one home display. The home display SHALL be either a display the user chose or, in automatic mode, the display under the mouse pointer. In automatic mode the home display SHALL change only after the pointer has stayed on another display for about 2 seconds. Without a valid choice, the home display SHALL be the main display.

#### Scenario: Chosen display
- **WHEN** the user chooses the external display as the screen
- **THEN** the external display becomes the home display and stays it, wherever the mouse goes

#### Scenario: Automatic mode
- **WHEN** automatic mode is on and the user moves the pointer to another display and keeps it there for a few seconds
- **THEN** that display becomes the home display

#### Scenario: Brief visit
- **WHEN** automatic mode is on and the pointer passes over another display for less than a second
- **THEN** the home display does not change

### Requirement: Walking to the home display
When the home display changes, buddies on other displays SHALL walk along the walkway to the home display, at a quicker pace than their normal stroll, and SHALL NOT jump. When two neighbouring displays on the walkway are not side by side on the desk, a buddy SHALL walk off one display at its edge and walk in at the facing edge of the next one.

#### Scenario: Walk over to the other screen
- **WHEN** the home display changes from the built-in display to the external display to its right
- **THEN** the buddy turns right, walks to the right edge of the built-in display, crosses into the external display and stops walking towards it once it is on it

#### Scenario: No jumping
- **WHEN** the home display changes
- **THEN** no buddy disappears from one display and reappears somewhere else in the same moment, except when it walks off one display's edge and in at the facing edge of a display that is not side by side

### Requirement: Display changes
When displays are connected or disconnected, the walkway SHALL be rebuilt within 2 seconds. Buddies on a disconnected display SHALL reappear at the nearest edge of a remaining display. A chosen screen that is disconnected SHALL be remembered, the main display SHALL act as the home display meanwhile, and the chosen screen SHALL become the home display again when it is reconnected.

#### Scenario: Display disconnected
- **WHEN** the external display with a buddy on it is disconnected
- **THEN** within 2 seconds the buddy is on the remaining display, entering at its edge nearest to where the external display was

#### Scenario: Chosen display comes back
- **WHEN** the chosen external display is reconnected after being disconnected
- **THEN** it becomes the home display again and the buddies walk over to it
