## ADDED Requirements

### Requirement: Picking up a buddy
A buddy SHALL be picked up when the user presses the left button on it and either holds the button for at least 0.25 s or moves the pointer at least 6 points while holding. A press released before either happens SHALL count as a click. A buddy that is walking off SHALL NOT be picked up. Only one buddy SHALL be carried at a time.

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

### Requirement: Dangling from the pointer
While carried, the buddy SHALL hang from the point where it was grabbed, and that point SHALL follow the pointer without visible lag. The buddy SHALL rotate freely around that point under gravity, play the `dangle` animation, keep looking at the pointer, and hide its name label.

#### Scenario: Grabbed by an ear
- **WHEN** the user picks up a buddy by one of its ears and holds the pointer still
- **THEN** the buddy swings down until its body hangs below the ear, then comes to rest kicking its legs

#### Scenario: Carrying it around
- **WHEN** the user carries the buddy across the screen
- **THEN** the grabbed point stays under the pointer the whole time and the buddy hangs from it

### Requirement: Swinging and spinning
A carried buddy SHALL swing like a pendulum in response to pointer movement: sideways movement SHALL make it swing back and forth, and small circular pointer movements at the swing's own pace SHALL build up the swing until the buddy spins all the way round the grab point. The swing SHALL die down slowly once the pointer stops.

#### Scenario: Shaking sideways
- **WHEN** the user moves a carried buddy quickly to the right and stops
- **THEN** the buddy lags behind, swings past the pointer to the right and swings back and forth with decreasing amplitude until it hangs still

#### Scenario: Stirring in small circles
- **WHEN** the user moves the pointer in small circles of a few centimetres, about once per second, while carrying a buddy
- **THEN** within a few circles the buddy swings higher and higher and then spins round the grab point like a hinge, for as long as the user keeps circling

#### Scenario: Spinning stops
- **WHEN** the user stops circling and holds the pointer still
- **THEN** the buddy slows down, swings back and forth for a while and comes to rest hanging below the grab point

### Requirement: Carrying over the whole screen
A carried buddy SHALL be visible and follow the pointer anywhere within the usable area of any display, including high above the bottom strip and across displays. It SHALL NOT be drawn above the usable area's top edge or beyond the outer ends of the walkway.

#### Scenario: Lifting high
- **WHEN** the user carries a buddy up to the middle of the screen
- **THEN** the whole buddy stays visible below the pointer, not cut off at the top of the strip

#### Scenario: To another display
- **WHEN** the user carries a buddy from the built-in display onto an external display
- **THEN** the buddy keeps hanging from the pointer on the external display

### Requirement: Dropping and landing
Releasing the button SHALL let the buddy go with the speed and spin it had at that moment. It SHALL then fall under gravity to the walkway floor on the display below it, staying within the walkway's ends, land upright with the `land` animation and show its name label again. A falling buddy SHALL be an interactive region and SHALL be picked up again by pressing on it.

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

### Requirement: A new spot after a drop
After landing on the home display, the buddy SHALL take the slot nearest to where it landed. If another buddy has that slot, the two SHALL swap slots, and the other buddy SHALL walk to the dropped buddy's former slot. A buddy that lands on another display SHALL keep its slot and walk back to it on the home display. The dropped buddy SHALL then go on with what its session's state asks for.

#### Scenario: Swapping places
- **WHEN** three buddies stand in slots 1, 2 and 3 and the user drops the buddy from slot 1 near slot 3
- **THEN** the dropped buddy stays near slot 3 and strolls there, and the buddy that stood in slot 3 walks to slot 1

#### Scenario: Dropped on an empty slot
- **WHEN** two buddies are on screen with room for five, and the user drops one near a free slot
- **THEN** it takes that slot and the other buddy stays where it is

#### Scenario: Dropped on another display
- **WHEN** the home display is the built-in display and the user drops a buddy on the external display
- **THEN** it lands on the external display's strip, then walks across to its own slot on the built-in display

#### Scenario: Session state while carried
- **WHEN** a buddy's session starts waiting for the user while the buddy is carried
- **THEN** the buddy keeps dangling, and after landing it shows the waiting behaviour

## MODIFIED Requirements

### Requirement: Looking and click reaction
Avatars SHALL look at the mouse pointer, also on another display. Each avatar SHALL be an interactive region. A left click (a press and release that does not pick the buddy up) SHALL go to the session, whatever state the session is in, except while the avatar walks off because its session ended; then it SHALL do nothing. The click SHALL act on release. A right click SHALL open a context menu at the pointer with "Send home" and, in debug mode, "Type here (debug)" (opens the debug text field there). Closing it without a choice SHALL change nothing and leave the frontmost app with keyboard focus.

#### Scenario: Pointer moves
- **WHEN** the user moves the mouse pointer along the strip
- **THEN** the avatars' eyes follow the pointer

#### Scenario: Click an avatar
- **WHEN** the user left-clicks an avatar whose session is working, idle or asleep
- **THEN** the app that runs the session comes to the front, and the avatar keeps its behaviour

#### Scenario: Click a leaving avatar
- **WHEN** the user left-clicks an avatar that waves goodbye and walks off because its session ended
- **THEN** nothing happens and the frontmost app keeps keyboard focus

#### Scenario: Click next to an avatar
- **WHEN** the user clicks on the strip between two avatars
- **THEN** the click reaches the window behind the overlay

#### Scenario: Context menu
- **WHEN** the user right-clicks an avatar while typing in a terminal, then presses Escape
- **THEN** a menu with "Send home" appears at the pointer, closes on Escape without changing anything, and further typing goes to the terminal

#### Scenario: Picking up a buddy is not a click
- **WHEN** the user picks up an avatar, carries it and drops it
- **THEN** the session's app does not come to the front, and the frontmost app keeps keyboard focus after the drop
