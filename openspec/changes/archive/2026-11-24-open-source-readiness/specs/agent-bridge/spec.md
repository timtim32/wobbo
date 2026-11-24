## MODIFIED Requirements

### Requirement: Permission prompts in the app
When installed in Claude Code, the bridge SHALL offer each permission prompt to the app, so that the user can allow or deny it there, but only when the app can show what is being asked in full. When the description had to be cut, or the request has more than one significant argument, the bridge SHALL NOT offer it to the app. When the user does not decide in the app within a short wait, when the prompt is not offered, or when the app is not running, the decision SHALL be left to Claude Code's own prompt.

#### Scenario: Allow from the app
- **WHEN** Claude asks permission to run a command and the user chooses Allow in the app
- **THEN** Claude runs the command without showing its own permission prompt

#### Scenario: Deny from the app
- **WHEN** the user chooses Deny in the app
- **THEN** Claude does not run the command and is told that the user denied it

#### Scenario: No decision in the app
- **WHEN** the user does not decide in the app within the wait
- **THEN** Claude Code shows its own permission prompt as usual

#### Scenario: Request too long to show
- **WHEN** Claude asks permission to run a command whose description is longer than the app can show
- **THEN** the app offers no Allow or Deny for it, the session's Wobbo shows that it is waiting, and Claude Code shows its own permission prompt without waiting
