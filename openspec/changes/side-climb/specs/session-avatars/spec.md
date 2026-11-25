## MODIFIED Requirements

### Requirement: Picking up a buddy
A buddy SHALL be picked up when the user presses the left button on it and either holds the button for at least 0.25 s or moves the pointer at least 6 points while holding. A press released before either happens SHALL count as a click. A buddy that is walking off, climbing between displays or jumping down to another display SHALL NOT be picked up. Only one buddy SHALL be carried at a time.

#### Scenario: Press and hold
- **WHEN** the user presses the left button on a strolling buddy and keeps it pressed without moving
- **THEN** after about a quarter of a second the buddy lifts off the floor and hangs from the pointer

#### Scenario: Press and pull
- **WHEN** the user presses the left button on a buddy and moves the pointer away at once
- **THEN** the buddy is picked up and follows the pointer, without waiting for the hold time

#### Scenario: Quick click
- **WHEN** the user presses and releases the left button on a buddy within a quarter of a second without moving the pointer
- **THEN** the buddy is not picked up and the click reaction applies

#### Scenario: Leaving buddy
- **WHEN** the user presses and holds the left button on a buddy that is waving goodbye or walking off
- **THEN** the buddy is not picked up and keeps walking off

#### Scenario: Climbing buddy
- **WHEN** the user presses and holds the left button on a buddy that climbs along a display's side edge
- **THEN** the buddy is not picked up and keeps climbing

### Requirement: Carrying over the whole screen
A carried buddy SHALL be visible and follow the pointer anywhere within the usable area of any display, including high above the bottom strip and across displays. It SHALL NOT be drawn above the usable area's top edge or beyond the outer ends of the walkway, except where a display stands on top of the one it is on: there it SHALL follow the pointer over the seam onto that display and back. It SHALL NOT be carried sideways from a display onto a display it is only joined to by a climb route.

#### Scenario: Lifting high
- **WHEN** the user carries a buddy up to the middle of the screen
- **THEN** the whole buddy stays visible below the pointer, not cut off at the top of the strip

#### Scenario: To another display
- **WHEN** the user carries a buddy from the built-in display onto an external display
- **THEN** the buddy keeps hanging from the pointer on the external display

#### Scenario: Up onto the display above
- **WHEN** an external display stands on top of the built-in display and the user carries a buddy from the built-in display up over its top edge
- **THEN** the buddy keeps hanging from the pointer on the external display

#### Scenario: Sideways next to stacked displays
- **WHEN** the user carries a buddy on the lower of two stacked displays past its side edge
- **THEN** the buddy stays on the lower display and does not appear at the end of the upper display's strip

### Requirement: Dropping and landing
Releasing the button SHALL let the buddy go with the speed and spin it had at that moment. It SHALL then fall under gravity to the walkway floor on the display below it, staying within the walkway's ends, land upright with the `land` animation and show its name label again. A buddy thrown up out of the top of a display on which another display stands SHALL fly on into that display and land on its floor. A falling buddy SHALL be an interactive region and SHALL be picked up again by pressing on it.

#### Scenario: Simple drop
- **WHEN** the user releases a buddy that hangs still high above the strip
- **THEN** it falls straight down, lands on the floor with a squash, stands upright and its name label reappears

#### Scenario: Throwing
- **WHEN** the user releases a buddy while moving the pointer quickly to the left
- **THEN** the buddy flies on to the left in an arc, falls, and lands further left than where it was released

#### Scenario: Released while spinning
- **WHEN** the user releases a buddy that is spinning round the grab point
- **THEN** it keeps tumbling while it falls and turns upright as it lands

#### Scenario: Catching it again
- **WHEN** the user presses on a buddy while it is falling
- **THEN** the buddy is picked up again and hangs from the pointer

#### Scenario: Landing while the Dock is shown
- **WHEN** a buddy is dropped on a display while the auto-hidden Dock is shown there
- **THEN** it lands on the same height the other buddies stand on above the Dock

#### Scenario: Thrown up onto the display above
- **WHEN** an external display stands on top of the built-in display and the user throws a buddy upwards out of the top of the built-in display
- **THEN** it flies into the external display, lands on that display's floor, and walks back to the home display afterwards if that is another display

## ADDED Requirements

### Requirement: Quiet while climbing
A buddy that climbs or jumps between displays SHALL show no speech balloon and no name label. A message for its session that arrives during the climb SHALL wait and be shown once the buddy stands on a floor again. A buddy that leaves while it stands on a display that is linked to the far end of the walkway only over a climb route SHALL walk off beyond the nearer outer end of its own display instead.

#### Scenario: Message during a climb
- **WHEN** Claude asks a question in a session whose buddy is climbing up to the other display
- **THEN** the balloon with the question appears once the buddy has stepped onto the upper display's floor

#### Scenario: Leaving from the upper display
- **WHEN** a session ends while its buddy stands on the upper of two stacked displays
- **THEN** the buddy walks off beyond the nearer side of the upper display and does not climb down first
