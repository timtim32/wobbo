## MODIFIED Requirements

### Requirement: Recognisable per session
Each avatar SHALL have a colour taken from a fixed set of hues that keep the character readable. A session's colour SHALL follow from its project folder: the colour the user chose for that folder, or else a colour Wobbo picks by itself from the folder name. Avatars on screen at the same time SHALL have different colours, except avatars whose folders have a chosen colour: every avatar of such a folder wears that colour, also when another avatar on screen wears it. A colour Wobbo picks by itself SHALL avoid colours worn by avatars on screen and colours chosen for folders of sessions on screen, as long as a free colour is left. An avatar SHALL keep its colour for as long as it is on screen, unless the user chooses a colour for its folder, or chooses for another folder the colour this avatar has (see "Choosing a buddy's colour"). Each avatar SHALL show a small label with its session's display name, unless the user turned names off in the menu. The label stays with the avatar while it moves, also across displays, and does not cover another avatar's label.

#### Scenario: Two sessions side by side
- **WHEN** two sessions of the projects "claude-buddy" and "website" are active and no colour was chosen for either folder
- **THEN** their avatars have clearly different colours and show the labels "claude-buddy" and "website"

#### Scenario: Colour is stable
- **WHEN** a session's state changes many times, or the home display changes
- **THEN** its avatar keeps the same colour and label

#### Scenario: Chosen colour on a new session
- **WHEN** the user chose orange for the folder "wobbo" earlier, and a new session starts in "wobbo"
- **THEN** its avatar walks in orange

#### Scenario: Automatic colour avoids a chosen one
- **WHEN** a session of "wobbo" (chosen: orange) is on screen and a session of a folder without a chosen colour starts whose name would give orange
- **THEN** the new avatar gets another free colour

#### Scenario: Label while crossing
- **WHEN** an avatar walks from one display to the next
- **THEN** its label moves along with it and is shown on both displays for the parts on each

### Requirement: Looking and click reaction
Avatars SHALL look at the mouse pointer, also on another display. Each avatar SHALL be an interactive region. A left click (a press and release that does not pick the buddy up) SHALL go to the session, whatever state the session is in, except while the avatar walks off because its session ended; then it SHALL do nothing. The click SHALL act on release. A right click SHALL open a context menu at the pointer with "Colour" (a submenu, see "Choosing a buddy's colour"; not on Wobbo's own buddy), "Send home" and, in debug mode, "Type here (debug)" (opens the debug text field there). Closing it without a choice SHALL change nothing and leave the frontmost app with keyboard focus.

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
- **THEN** a menu with "Colour" and "Send home" appears at the pointer, closes on Escape without changing anything, and further typing goes to the terminal

#### Scenario: Picking up a buddy is not a click
- **WHEN** the user picks up an avatar, carries it and drops it
- **THEN** the session's app does not come to the front, and the frontmost app keeps keyboard focus after the drop

## ADDED Requirements

### Requirement: Choosing a buddy's colour
The "Colour" submenu SHALL list the 8 buddy colours by name and "Automatic", with a check mark on the folder's chosen colour, or on "Automatic". Choosing a colour SHALL give every avatar of that folder on screen that colour at once, in body and balloon name. Another folder's avatar without a choice that wears that colour SHALL take the old colour. Wobbo's own buddy SHALL NOT offer the submenu.

#### Scenario: Choose a colour
- **WHEN** the user right-clicks the blue "iris-mobile" avatar and chooses Colour → Red
- **THEN** that avatar turns red at once, and the submenu shows the check mark on Red the next time

#### Scenario: Colours swap
- **WHEN** a "website" avatar (no choice) is red and the user chooses Red for the blue "iris-mobile" avatar
- **THEN** "iris-mobile" turns red and "website" turns blue

#### Scenario: Two sessions of one folder
- **WHEN** two sessions of "wobbo" are on screen and the user chooses Orange on one of them
- **THEN** both avatars turn orange

#### Scenario: Own buddy
- **WHEN** the user right-clicks Wobbo's own green buddy
- **THEN** the menu has no "Colour" submenu

### Requirement: Remembered colour per folder
A colour the user chose SHALL be remembered per project folder name, also after Wobbo restarts, and used for every later session of that folder. Choosing "Automatic" SHALL forget the folder's choice and give its avatars a colour Wobbo picks by itself.

#### Scenario: Choice is remembered
- **WHEN** the user chose Red for "iris-mobile", quits Wobbo and starts it again, and a session of "iris-mobile" starts
- **THEN** its avatar is red

#### Scenario: Back to automatic
- **WHEN** the user chooses Colour → Automatic on the red "iris-mobile" avatar
- **THEN** the choice is forgotten and the avatar gets a colour Wobbo picks by itself, and the check mark is on "Automatic"
