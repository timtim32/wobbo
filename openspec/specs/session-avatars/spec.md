# session-avatars Specification

## Purpose

Gives every coding-agent session its own monster on the overlay, so the user can see at a glance which sessions are running and what each one is doing.

## Requirements

### Requirement: One avatar per session
Each active session that is not away SHALL have its own avatar on the home display's strip. A new session's avatar SHALL start walking in within 2 seconds from an outer edge of the displays (one with no display beyond it). An ended session's avatar SHALL wave and walk off at an outer edge, crossing displays in between, never vanishing mid-screen; a removed one SHALL walk off without waving. With no active sessions, no avatar SHALL be shown.

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
An avatar SHALL show its session's state while standing at its spot: `thinking` and `waiting` each with their own looping clip, and `working` with one of the work clips, switching every 8 to 15 seconds by putting the current prop away and taking another. It SHALL react happily for `done`, flinch for `error`, and stroll around its spot while `idle` or after a reaction. It SHALL take on a new state within 1 second, or on arrival when it is walking in, walking off or travelling.

#### Scenario: A prompt is worked on
- **WHEN** the session goes from `thinking` to `working` to `done`
- **THEN** the avatar plays its thinking clip, then a work clip, then a happy reaction, and then strolls around its spot

#### Scenario: Long work
- **WHEN** the session stays `working` for a minute
- **THEN** the avatar shows several different work clips, each for 8 to 15 seconds, never the same one twice in a row

#### Scenario: Stop working
- **WHEN** the session goes from `working` to `done` while the avatar uses a prop
- **THEN** the avatar first puts the prop away, and then reacts happily

#### Scenario: Waiting for the user
- **WHEN** the session asks the user a question or for permission
- **THEN** the avatar stands at its spot and keeps jumping for attention until the request is answered or withdrawn

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

### Requirement: Low cost while quiet
While no avatar is on screen, or every avatar on screen is asleep, the app SHALL lower its frame rate so that it uses clearly less CPU than with a strolling avatar. It SHALL return to its normal frame rate within 1 second when an avatar enters, wakes up or is clicked, or when the pointer moves over the strip.

#### Scenario: All asleep
- **WHEN** every avatar on screen has fallen asleep
- **THEN** the app uses clearly less CPU than with one strolling avatar

#### Scenario: Waking from the quiet mode
- **WHEN** all avatars sleep and one session receives a prompt
- **THEN** within 1 second its avatar wakes up and moves smoothly again

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

### Requirement: Go to the session
A left click on an avatar SHALL bring the macOS app that runs the session's agent to the front, found from the agent's process, and SHALL open the session's focus link when it has one, whether or not the session waits for the user. This SHALL work for any agent connected through hooks or MCP. When neither app nor link can be found, the click SHALL do nothing visible and the reason SHALL be logged.

#### Scenario: Claude asks in the Claude app
- **WHEN** a Claude Code session in the Claude app's Code tab waits for an answer, and the user left-clicks its jumping avatar while another app is in front
- **THEN** the Claude app comes to the front and shows that session

#### Scenario: Claude is working in the Claude app
- **WHEN** a Claude Code session in the Claude app's Code tab is working, and the user left-clicks its avatar while another app is in front
- **THEN** the Claude app comes to the front and shows that session

#### Scenario: Agent in a terminal
- **WHEN** a session running in a terminal is idle, and the user left-clicks its avatar
- **THEN** that terminal app comes to the front

#### Scenario: Agent process gone
- **WHEN** the user left-clicks an avatar whose agent process no longer exists
- **THEN** nothing comes to the front, the avatar keeps its state, and a log line names the session

### Requirement: Noticing the auto-hidden Dock
The app SHALL track whether the Dock is shown, but only when the Dock hides automatically and sits at the bottom of the screen. The Dock SHALL count as shown on a display while it is in view there and not sliding away. It SHALL count as hidden as soon as it starts to slide away.

#### Scenario: Dock slides up
- **WHEN** the Dock hides automatically, sits at the bottom, and the user brings it up on a display
- **THEN** the Dock counts as shown on that display as soon as it comes into view

#### Scenario: Using the Dock
- **WHEN** the Dock is shown and the user moves the pointer over the Dock icons
- **THEN** the Dock still counts as shown

#### Scenario: Dock hides
- **WHEN** the Dock is shown and starts to slide away, for example because the pointer left it upward or sideways
- **THEN** the Dock counts as hidden

#### Scenario: Pointer at the bottom beside the Dock
- **WHEN** the pointer touches the bottom edge beside the Dock and the Dock does not appear
- **THEN** the Dock does not count as shown

#### Scenario: Dock always visible or on the side
- **WHEN** automatic hiding of the Dock is off, or the Dock sits on the left or right
- **THEN** the Dock never counts as shown

### Requirement: Noticing the Dock without Accessibility permission
Seeing the Dock itself needs the macOS Accessibility permission. The first time the app needs it, the app SHALL ask macOS to request it. Until the permission is granted, the app SHALL follow the pointer instead. The Dock counts as shown once the pointer has stayed on a display's bottom edge for the Dock's show delay. It counts as hidden once the pointer moves higher than the Dock's height above that edge, or leaves the display.

#### Scenario: Asking for permission
- **WHEN** the app has no Accessibility permission and the Dock hides automatically
- **THEN** macOS is asked once per run to request it, and the app switches to the Dock itself within a second of it being granted

#### Scenario: Pointer on the bottom edge
- **WHEN** the app has no permission and the pointer rests on a display's bottom edge, including pushed against it, for the Dock's show delay
- **THEN** the Dock counts as shown on that display until the pointer moves higher than the Dock's height

### Requirement: Making way for the Dock
While the Dock is shown on a display, every avatar on that display SHALL jump up and stand on top of the Dock. When the Dock hides, the avatars SHALL jump back down to the floor. Each jump SHALL show a jump animation. While lifted, avatars SHALL keep walking, strolling and animating, and their click region and name label SHALL move with them. The lift SHALL never push an avatar's head or name label outside the overlay strip.

#### Scenario: Buddies jump up
- **WHEN** the Dock becomes shown on the display where the buddies stand
- **THEN** the buddies jump up with a jump animation and stand just above the Dock without covering Dock icons, and jump back down when it hides

#### Scenario: Other display
- **WHEN** the Dock is shown on a display where no buddy stands
- **THEN** no buddy jumps

#### Scenario: Large buddy
- **WHEN** the buddy size is Extra large and the Dock is shown with large icons
- **THEN** the buddy lifts at most as high as keeps its head and name label inside the strip

#### Scenario: Clicking a lifted buddy
- **WHEN** a buddy stands lifted above the Dock and the user clicks it
- **THEN** the click reaches the buddy as it does on the floor, and clicks on the Dock next to the buddy reach the Dock

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
