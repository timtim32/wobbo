## MODIFIED Requirements

### Requirement: Animation clips
The character SHALL be able to play these named animations: `idle`, `blink`, `walk`, `wave`, `sleep`, `thinking`, `working`, `work_hammer`, `work_laptop`, `work_wrench`, `work_papers`, their `_in` and `_out` transitions, `happy`, `error`, `waiting`, `dangle` and `land`. `idle`, `walk`, `sleep`, `thinking`, `working`, the four `work_*` loops, `waiting` and `dangle` SHALL loop without a visible jump. `blink`, `wave`, `happy`, `error`, `land` and the `_in`/`_out` transitions SHALL play once.

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

### Requirement: Carry clips
The `dangle` clip SHALL show a character that hangs helplessly: legs kicking in the air, arms flailing above the body, ears flopping and the eye wide open. The `land` clip SHALL show the character hitting the ground: the body squashes, the legs bend, and it bounces back to its normal stance, ending in the `idle` pose.

#### Scenario: Dangling
- **WHEN** the character plays `dangle` at its normal size
- **THEN** a viewer sees it kicking and flailing as if held up in the air, clearly different from `walk` and `waiting`

#### Scenario: Landing
- **WHEN** the character plays `land`
- **THEN** it squashes down, springs back up to standing, and continues with `idle` without a visible jump
