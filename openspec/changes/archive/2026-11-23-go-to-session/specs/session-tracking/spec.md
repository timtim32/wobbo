# Spec Delta

## ADDED Requirements

### Requirement: Session focus link
The app SHALL keep the latest focus link a session reported. It SHALL only use a focus link whose URL scheme is on its list of known agent hosts, and SHALL ignore any other link.

#### Scenario: Link kept
- **WHEN** a session reports a focus link with the `claude` scheme
- **THEN** the session's focus link is that URL

#### Scenario: Unknown scheme
- **WHEN** a session reports a focus link with a `file` or `https` scheme
- **THEN** the app does not keep it
