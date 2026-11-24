# menu-bar-control Specification

## Purpose

Gives the user global control over Wobbo through a macOS menu bar icon, since the app has no Dock icon or regular window, and keeps the user's choices across launches.

## Requirements

### Requirement: Menu bar icon
While running, the app SHALL show an icon in the macOS menu bar that adapts to light and dark menu bar appearance, and clicking it SHALL open the app menu.

#### Scenario: App starts
- **WHEN** the app starts
- **THEN** a Wobbo icon appears in the menu bar

#### Scenario: Open the menu
- **WHEN** the user clicks the menu bar icon
- **THEN** the app menu opens, showing at least "Show Buddies"/"Hide Buddies", "Screen", "Debug regions" and "Quit Wobbo"

### Requirement: Show and hide the overlay
The menu SHALL let the user hide and show the whole overlay. While hidden, the overlay SHALL draw nothing and SHALL pass all mouse events through.

#### Scenario: Hide
- **WHEN** the user chooses "Hide Buddies"
- **THEN** the overlay's content disappears and the menu item changes to "Show Buddies"

#### Scenario: Show
- **WHEN** the overlay is hidden and the user chooses "Show Buddies"
- **THEN** the overlay's content reappears and the menu item changes to "Hide Buddies"

### Requirement: Debug regions toggle
In debug builds (the editor and debug exports), the menu SHALL include a checkable "Debug regions" item that turns the overlay's debug region view on and off. Release builds SHALL NOT show the item, and SHALL treat the debug region view as off whatever the saved setting says.

#### Scenario: Toggle debug regions
- **WHEN** the user selects "Debug regions" in a debug build
- **THEN** the debug region view is toggled and the item's check mark reflects the new state

#### Scenario: Release build
- **WHEN** the user opens the menu of a release build
- **THEN** there is no "Debug regions" item and no debug view is shown, even if the saved setting is on

### Requirement: Quit
The menu SHALL include "Quit Wobbo", which ends the app and removes the menu bar icon.

#### Scenario: Quit from menu
- **WHEN** the user chooses "Quit Wobbo"
- **THEN** the app exits and both the overlay and the menu bar icon are gone

### Requirement: Persisted settings
Settings changed through the menu (at least overlay visibility, screen choice, buddy size, debug regions, the message output and the two notices) SHALL persist across launches in a per-user settings file. A missing or unreadable file SHALL fall back to defaults: visible, screen automatic, size Normal, debug off, output Balloons, "Turn finished" on and "Errors" on.

#### Scenario: Setting survives restart
- **WHEN** the user hides the overlay, quits, and starts the app again
- **THEN** the overlay starts hidden and the menu shows "Show Buddies"

#### Scenario: Screen choice survives restart
- **WHEN** the user chooses the external display, quits, and starts the app again with that display connected
- **THEN** the buddies start on the external display and it is checked under "Screen"

#### Scenario: Size survives restart
- **WHEN** the user chooses "Extra large", quits, and starts the app again
- **THEN** the buddies are about 170 points tall and "Extra large" is checked under "Size"

#### Scenario: Messages choice survives restart
- **WHEN** the user chooses "Off" under "Messages", quits, and starts the app again
- **THEN** "Off" is still checked and no balloons appear

#### Scenario: Corrupt settings file
- **WHEN** the settings file is not valid at startup
- **THEN** the app starts with default settings and does not crash

### Requirement: Screen choice
The menu SHALL include a "Screen" submenu with "Automatic (follow the mouse)" and one item per connected display, named the way macOS names it. Exactly one item SHALL be checked. Choosing an item SHALL make that the buddies' home display (or turn on automatic mode). A remembered display that is not connected SHALL be listed as unavailable while it is still the choice.

#### Scenario: Choose a display
- **WHEN** the user opens "Screen" and chooses the external display
- **THEN** that item is checked and the buddies walk to the external display

#### Scenario: Automatic
- **WHEN** the user chooses "Automatic (follow the mouse)"
- **THEN** that item is checked and the home display follows the mouse pointer

#### Scenario: Display list follows connections
- **WHEN** a display is connected or disconnected
- **THEN** the next time the menu opens, the "Screen" submenu lists the displays that are connected now

### Requirement: Demo
The menu SHALL include "Play Demo", which plays a scripted show of about a minute and a half with pretend sessions: their avatars walk in, show the session states, react, swap when more than five sessions are active, and walk off again. Pretend sessions SHALL exist only inside the app and SHALL NOT reach any agent. While the demo runs, the item SHALL read "Stop Demo", and choosing it SHALL end all pretend sessions. Real sessions SHALL keep working during the demo.

#### Scenario: Play the demo
- **WHEN** the user chooses "Play Demo"
- **THEN** pretend sessions' avatars walk in and go through thinking, working, waiting, a happy reaction, an error, a swap and a goodbye, and after the show no pretend session is left

#### Scenario: Stop the demo
- **WHEN** the user chooses "Stop Demo" while the demo runs
- **THEN** all pretend sessions end, their avatars wave and walk off, and the item reads "Play Demo" again

#### Scenario: Real session during the demo
- **WHEN** a real agent session is active while the demo runs
- **THEN** its avatar keeps showing its own state, and the demo does not change it

### Requirement: Names toggle
The menu SHALL include a checkable "Show Names" item that shows or hides the avatars' name labels. It SHALL be on by default, and the choice SHALL persist across launches like the other menu settings.

#### Scenario: Hide the names
- **WHEN** the user unchecks "Show Names"
- **THEN** every avatar's name label disappears at once, also on avatars that walk in later, while the avatars themselves stay

#### Scenario: Names choice survives restart
- **WHEN** the user hides the names, quits, and starts the app again
- **THEN** the avatars have no name labels and "Show Names" is unchecked

### Requirement: Buddy size
The menu SHALL include a "Size" submenu with the radio items "Small", "Normal", "Large" and "Extra large", for buddies of about 80, 110, 140 and 170 points tall. Exactly one item SHALL be checked. Choosing an item SHALL resize every buddy on screen within 1 second, and buddies that appear later SHALL have the chosen size too.

#### Scenario: Choose a size
- **WHEN** the user opens "Size" and chooses "Large"
- **THEN** "Large" is checked and every buddy becomes about 140 points tall, with its name label above its head and clicks working on its new outline

#### Scenario: New buddies use the size
- **WHEN** the size is "Small" and a new session starts
- **THEN** its buddy walks in at about 80 points tall

### Requirement: Messages
The menu SHALL include a "Messages" submenu. It SHALL hold the radio items "Balloons", "Speech", "Balloons and Speech" and "Off", with exactly one checked, then the check items "Turn finished" and "Errors". A choice SHALL take effect at once. When macOS offers no voice, the two speech items SHALL be disabled.

#### Scenario: Choose the output
- **WHEN** the user opens "Messages" and chooses "Balloons and Speech"
- **THEN** that item is checked, and the next message appears in a balloon and is spoken

#### Scenario: Turn messages off
- **WHEN** the user chooses "Off"
- **THEN** "Off" is checked, open balloons close, and no message is shown or spoken until another output is chosen

#### Scenario: Notices on and off
- **WHEN** the user unchecks "Errors"
- **THEN** a failed turn no longer shows or speaks a notice, while questions and messages still appear
