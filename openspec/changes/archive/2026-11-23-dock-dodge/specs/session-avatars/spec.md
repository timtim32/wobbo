## ADDED Requirements

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
