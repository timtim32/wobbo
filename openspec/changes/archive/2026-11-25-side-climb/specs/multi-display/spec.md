## MODIFIED Requirements

### Requirement: Walkway across displays
The overlay SHALL treat the bottom strips of all connected displays as one walkway, ordered by the displays' horizontal arrangement from left to right. Buddies SHALL be able to stand on any part of the walkway, and a buddy that is crossing from one display to the next SHALL be drawn on both displays for the part that is on each. Its size SHALL be the same in points on both. When two neighbouring displays on the walkway are stacked, the lower display's bottom edge is below the upper display's bottom edge, the lower display's top edge touches the upper display's bottom edge, and a side edge of the lower display lies under the upper display with room for a buddy on the upper display next to it, that side edge SHALL be a climb route between the two displays.

#### Scenario: Two displays side by side
- **WHEN** a built-in display and an external display to its right are connected
- **THEN** the walkway runs from the left edge of the built-in display's strip to the right edge of the external display's strip

#### Scenario: Crossing the edge
- **WHEN** a buddy walks over the right edge of the left display
- **THEN** the part that has crossed is shown at the left edge of the right display's strip, and the rest is still shown on the left display, until it has fully crossed

#### Scenario: Different display scales
- **WHEN** a buddy stands on a Retina display and on a non-Retina display in turn
- **THEN** it is the same size in points on both and looks sharp on both

#### Scenario: Wider display above
- **WHEN** an external display that is wider than the built-in display stands on top of it and sticks out on both sides
- **THEN** both side edges of the built-in display are climb routes to the external display

#### Scenario: Narrow display above
- **WHEN** a display that is narrower than the display below it stands on top of it, away from both of its side edges
- **THEN** there is no climb route between them and buddies cross between them as between displays that are not side by side

#### Scenario: Displays side by side are no climb route
- **WHEN** two displays stand next to each other at different heights
- **THEN** there is no climb route between them

### Requirement: Walking to the home display
When the home display changes, buddies on other displays SHALL walk along the walkway to the home display, at a quicker pace than their normal stroll, and SHALL NOT jump. When the way leads up over a climb route, a buddy SHALL walk to the bottom of that side edge, climb along the inside of the lower display's side edge to its top, and step onto the upper display's floor there. When the way leads down, it SHALL walk on the upper display to the place above that side edge, jump off with a spin like a thrown buddy, and land on the lower display's floor, keeping its spot in the row. When both side edges of the lower display are climb routes, the buddy SHALL take the one that makes its trip shorter. When two neighbouring displays on the walkway are not side by side and have no climb route, a buddy SHALL walk off one display at its edge and walk in at the facing edge of the next one.

#### Scenario: Walk over to the other screen
- **WHEN** the home display changes from the built-in display to the external display to its right
- **THEN** the buddy turns right, walks to the right edge of the built-in display, crosses into the external display and stops walking towards it once it is on it

#### Scenario: Climbing up
- **WHEN** an external display stands on top of the built-in display and the home display changes from the built-in display to the external display
- **THEN** the buddy walks to the side edge of the built-in display, climbs up along it to the top of the built-in display, steps onto the floor of the external display above and walks to its spot there

#### Scenario: Jumping down
- **WHEN** the home display changes back from the upper display to the lower display
- **THEN** the buddy walks on the upper display to the place above the climb route, jumps off inwards, tumbles through the air down the lower display, lands upright on its floor and walks to its spot there

#### Scenario: Shortest side
- **WHEN** both side edges of the lower display are climb routes and the buddy stands near the lower display's right edge
- **THEN** it climbs along the right edge

#### Scenario: Seen on both displays at the top
- **WHEN** a climbing buddy reaches the top of the lower display
- **THEN** the part of the buddy that is already above the edge is shown on the upper display and the rest on the lower display, until it stands on the upper display's floor, apart from the height of the lower display's menu bar where it may briefly not be shown

#### Scenario: No jumping
- **WHEN** the home display changes
- **THEN** no buddy disappears from one display and reappears somewhere else in the same moment, except when it walks off one display's edge and in at the facing edge of a display that is neither side by side nor linked by a climb route

### Requirement: Display changes
When displays are connected or disconnected, the walkway SHALL be rebuilt within 2 seconds. Buddies on a disconnected display SHALL reappear at the nearest edge of a remaining display. A chosen screen that is disconnected SHALL be remembered, the main display SHALL act as the home display meanwhile, and the chosen screen SHALL become the home display again when it is reconnected. A buddy that is climbing or jumping down when the walkway is rebuilt SHALL stand on a floor of a remaining display, under or near the place where it was.

#### Scenario: Display disconnected
- **WHEN** the external display with a buddy on it is disconnected
- **THEN** within 2 seconds the buddy is on the remaining display, entering at its edge nearest to where the external display was

#### Scenario: Chosen display comes back
- **WHEN** the chosen external display is reconnected after being disconnected
- **THEN** it becomes the home display again and the buddies walk over to it

#### Scenario: Display arrangement changes during a climb
- **WHEN** the user moves the upper display in the display settings while a buddy climbs to it
- **THEN** within 2 seconds the buddy stands on the lower display's floor and, if the home display is still elsewhere, walks there along the new walkway
