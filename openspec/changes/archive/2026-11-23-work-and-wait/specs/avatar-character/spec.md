# Spec Delta

## MODIFIED Requirements

### Requirement: Animation clips
The character SHALL be able to play these named animations: `idle`, `blink`, `walk`, `wave`, `sleep`, `thinking`, `working`, `work_hammer`, `work_laptop`, `work_wrench`, `work_papers`, their `_in` and `_out` transitions, `happy`, `error` and `waiting`. `idle`, `walk`, `sleep`, `thinking`, `working`, the four `work_*` loops and `waiting` SHALL loop without a visible jump. `blink`, `wave`, `happy`, `error` and the `_in`/`_out` transitions SHALL play once.

#### Scenario: Looping clip
- **WHEN** the character plays `walk` for several cycles
- **THEN** the motion repeats smoothly, with no jump where the clip restarts

#### Scenario: One-shot clip returns to idle
- **WHEN** the character plays `wave`
- **THEN** it waves once and then continues with `idle` without a visible jump

#### Scenario: Unknown clip
- **WHEN** something asks the character to play an animation name it does not have
- **THEN** the character keeps playing its current animation and a warning is logged

#### Scenario: Taking and putting away a prop
- **WHEN** the character plays `work_hammer_in`, then `work_hammer`, then `work_hammer_out`
- **THEN** it takes the hammer out from behind its back, hammers, and puts the hammer away again, without the hammer popping into view in its hand

#### Scenario: Props only in their clip
- **WHEN** the character switches from `work_hammer` to any other clip
- **THEN** the hammer is no longer visible, and no other clip ever shows a prop

### Requirement: Clip meaning
Each animation SHALL express its own meaning through body language that is readable at the overlay size, so that clips with different meanings look clearly different. The `work_*` clips SHALL each show a prop in the character's own flat style, held by the hand or in front of the body, moving with the rig.

#### Scenario: Resting and moving clips
- **WHEN** the character plays `idle`, `blink`, `walk` or `sleep`
- **THEN** `idle` gently breathes, `blink` closes and opens the eye, `walk` moves legs and arms in a walking cycle in place, and `sleep` keeps the eye closed with slow breathing

#### Scenario: Work-state clips
- **WHEN** the character plays `thinking`, `working` or `waiting`
- **THEN** `thinking` looks up and to the side and taps its chin with one hand, `working` shows busy, quick movement, and `waiting` keeps jumping up and down while waving and looking out at the user for attention

#### Scenario: Work clips with props
- **WHEN** the character plays `work_hammer`, `work_laptop`, `work_wrench` or `work_papers`
- **THEN** it hammers with a hammer, types fast on a small laptop, turns a wrench, or leafs through a stack of papers

#### Scenario: Reaction clips
- **WHEN** the character plays `wave`, `happy` or `error`
- **THEN** `wave` waves one arm, `happy` jumps with a wide eye and then laughs with a wide-open mouth, and `error` shows a startled flinch

#### Scenario: Recognisable at real size
- **WHEN** each clip plays on the overlay at the character's normal size
- **THEN** a viewer can tell the clips apart, recognise each prop, and match each clip to its meaning
