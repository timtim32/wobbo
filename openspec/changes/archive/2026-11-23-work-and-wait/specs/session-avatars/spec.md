# Spec Delta

## MODIFIED Requirements

### Requirement: Behaviour follows session state
An avatar SHALL show its session's state while standing at its spot: `thinking` and `waiting` each with their own looping clip, and `working` with one of the work clips, switching to another randomly chosen one every 8 to 15 seconds by putting the current prop away and taking the next. It SHALL react happily for `done`, flinch for `error`, and stroll around its spot while `idle` or after a reaction. It SHALL take on a new state within 1 second, or on arrival when it is walking in, walking off or travelling.

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
