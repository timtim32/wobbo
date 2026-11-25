## MODIFIED Requirements

### Requirement: Animation clips
The character SHALL be able to play these named animations: `idle`, `blink`, `walk`, `wave`, `sleep`, `thinking`, `working`, `work_hammer`, `work_laptop`, `work_wrench`, `work_papers`, their `_in` and `_out` transitions, `happy`, `error`, `waiting`, `dangle`, `land` and `climb`. `idle`, `walk`, `sleep`, `thinking`, `working`, the four `work_*` loops, `waiting`, `dangle` and `climb` SHALL loop without a visible jump. `blink`, `wave`, `happy`, `error`, `land` and the `_in`/`_out` transitions SHALL play once.

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

## ADDED Requirements

### Requirement: Climb clip
The `climb` clip SHALL show the character climbing up a vertical edge seen from the side: its body upright and close to the edge it faces, the arms reaching up in turns and the legs pushing up in turns, the ears swaying a little and the eye looking up along the edge.

#### Scenario: Climbing
- **WHEN** the character plays `climb` at its normal size while it moves up along a display's side edge
- **THEN** a viewer sees it climb hand over hand, clearly different from `walk`, `dangle` and `waiting`

#### Scenario: Facing the edge
- **WHEN** the character climbs along the right edge of a display
- **THEN** it faces right, towards the edge, and faces left along the left edge
