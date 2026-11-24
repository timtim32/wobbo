# Spec Delta

## Purpose

Defines the buddy character that represents a Claude Code session on the overlay: what it looks like, which animations it can play, where its eye looks, how each instance gets its own colour, and how large it is on screen.

## ADDED Requirements

### Requirement: Monster appearance
The character SHALL be an original one-eyed green monster with a rounded pill-shaped body that doubles as the head, one large eye with a pupil, highlights, a single brow and a soft shadow around it, pink cheeks, a gently smiling mouth in its resting face, two pointy ears, two small fangs, a few dark spots, a light belly patch, two short arms with three-fingered hands and two short legs with three toes.

#### Scenario: Character at rest
- **WHEN** a character is shown without any colour shift, playing its idle animation
- **THEN** it shows all of the listed features in the default greens

#### Scenario: Original artwork
- **WHEN** the character artwork is inspected
- **THEN** every part is drawn from scratch as plain vector paths in `art/monster/monster.svg`, and nothing is traced or copied

### Requirement: Flat drawing style
The character SHALL be drawn in a flat vector style with flat greens for skin, shading and spots and no outlines, except a thin outline where a limb in front of the body would otherwise not be readable.

#### Scenario: No outlines
- **WHEN** the character plays `idle`
- **THEN** no part has an outline and shapes are separated only by colour

#### Scenario: Limb in front of the body
- **WHEN** the character holds a hand in front of its body, as in `thinking`
- **THEN** that arm and hand have a thin dark outline, so they stand out from the body

### Requirement: Independent parts
The character SHALL be built from separate parts: body, eye (white, pupil and highlight), brows, left and right ear, left and right arm, left and right leg, fangs and mouth, and spots. The parts SHALL move independently, so that animations can move the eye, ears, arms and legs without distorting the rest.

#### Scenario: Arm moves alone
- **WHEN** an animation raises one arm
- **THEN** only that arm moves, and the body, eye and other limbs keep their shapes

#### Scenario: Squash and stretch
- **WHEN** an animation squashes or stretches the body
- **THEN** the eye, fangs, spots, ears and arms stay attached to the body in the right places

### Requirement: Animation clips
The character SHALL be able to play these named animations: `idle`, `blink`, `walk`, `wave`, `sleep`, `thinking`, `working`, `happy`, `error` and `waiting`. `idle`, `walk`, `sleep`, `thinking`, `working` and `waiting` SHALL loop without a visible jump at the loop point. `blink`, `wave`, `happy` and `error` SHALL play once and then return to `idle`.

#### Scenario: Looping clip
- **WHEN** the character plays `walk` for several cycles
- **THEN** the motion repeats smoothly, with no jump where the clip restarts

#### Scenario: One-shot clip returns to idle
- **WHEN** the character plays `wave`
- **THEN** it waves once and then continues with `idle` without a visible jump

#### Scenario: Unknown clip
- **WHEN** something asks the character to play an animation name it does not have
- **THEN** the character keeps playing its current animation and a warning is logged

### Requirement: Clip meaning
Each animation SHALL express its own meaning through body language that is readable at the overlay size, so that clips with different meanings look clearly different.

#### Scenario: Resting and moving clips
- **WHEN** the character plays `idle`, `blink`, `walk` or `sleep`
- **THEN** `idle` gently breathes, `blink` closes and opens the eye, `walk` moves legs and arms in a walking cycle in place, and `sleep` keeps the eye closed with slow breathing

#### Scenario: Work-state clips
- **WHEN** the character plays `thinking`, `working` or `waiting`
- **THEN** `thinking` looks up and to the side and taps its chin with one hand, `working` shows busy, quick movement, and `waiting` looks out at the user and gestures for attention

#### Scenario: Reaction clips
- **WHEN** the character plays `wave`, `happy` or `error`
- **THEN** `wave` waves one arm, `happy` jumps with a wide eye and then laughs with a wide-open mouth, and `error` shows a startled flinch

#### Scenario: Recognisable at real size
- **WHEN** each clip plays on the overlay at the character's normal size
- **THEN** a viewer can tell the clips apart and match each one to its meaning

### Requirement: Idle blinking
While the character plays `idle`, it SHALL blink by itself at irregular intervals of about 2 to 6 seconds.

#### Scenario: Character idles
- **WHEN** the character plays `idle` for 30 seconds
- **THEN** it blinks several times, not at a fixed rhythm

### Requirement: Facing direction
The character SHALL be able to face left or right, and switching direction SHALL mirror the whole character without changing its position on screen.

#### Scenario: Walking the other way
- **WHEN** the character is turned to face left while walking
- **THEN** it is drawn mirrored and keeps walking in place at the same position

### Requirement: Eye looks at a target
The character SHALL be able to look towards a given screen point. The pupil SHALL move towards that point within the white of the eye and never leave it. Without a target the pupil SHALL return to the centre.

#### Scenario: Look at a point
- **WHEN** a target point is set to the upper right of the character
- **THEN** the pupil moves towards the upper right and stays inside the eye white

#### Scenario: Clear the target
- **WHEN** the target is cleared
- **THEN** the pupil eases back to the centre of the eye

### Requirement: Per-instance colour
Each character instance SHALL accept its own colour, given as a hue. The light and dark skin greens SHALL shift together to that hue, keeping their contrast. The eye white, pupil, highlights, fangs and pink cheeks SHALL keep their own colours. Instances with different hues SHALL be clearly distinguishable from each other.

#### Scenario: Two coloured instances
- **WHEN** two characters are shown with hues that are far apart, for example green and purple
- **THEN** their skins have clearly different colours, and both have a white eye, black pupil and white fangs

#### Scenario: Default colour
- **WHEN** no hue is set
- **THEN** the character shows its original greens

### Requirement: On-screen size and sharpness
The character SHALL be about 110 points tall at its default scale, so that it and a speech balloon above it fit within the overlay strip. It SHALL look sharp, without blurry or jagged edges or coloured fringes, on both Retina and non-Retina displays and on the transparent overlay.

#### Scenario: Retina display
- **WHEN** the character is shown on a Retina display at its default scale
- **THEN** its edges are sharp and smooth, with no visible pixels or halos against the desktop behind it

#### Scenario: Fits the strip
- **WHEN** the character stands at the bottom of the overlay strip
- **THEN** it is fully visible and leaves room above it for a speech balloon
