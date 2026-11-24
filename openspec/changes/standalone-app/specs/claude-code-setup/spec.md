## ADDED Requirements

### Requirement: Welcome on first start
On its first start (no settings file in its data folder and none to copy from the old `ClaudeBuddy` folder), Wobbo SHALL show a buddy named "Wobbo" that walks in and greets the user in a balloon. When Wobbo is not connected to Claude Code, the greeting SHALL offer "Connect to Claude Code" and "Not now". When it is already connected, the greeting SHALL say that Claude Code sessions will show up as buddies. The welcome buddy SHALL walk off after the greeting is answered or closed.

#### Scenario: First start, not connected
- **WHEN** a new user opens Wobbo for the first time
- **THEN** the Wobbo buddy walks in and offers to connect to Claude Code

#### Scenario: Not now
- **WHEN** the user chooses "Not now"
- **THEN** the welcome buddy walks off, nothing is installed, and the menu still offers to connect

### Requirement: Wobbo's own colour
The buddy named "Wobbo" SHALL always wear the monster's original green, also when a session's buddy already wears it.

#### Scenario: Green while another buddy is green
- **WHEN** a session whose buddy is green is shown and the Wobbo buddy walks in
- **THEN** the Wobbo buddy is green as well

### Requirement: Connect offer until answered
On later starts, Wobbo SHALL offer "Connect to Claude Code" in the same way while it is not connected and the user has never chosen "Not now" to that offer, so a user upgrading from Claude Buddy is offered to connect too. Once the user chose "Not now", Wobbo SHALL NOT offer it at start again, until the user connects.

#### Scenario: Upgrade from Claude Buddy
- **WHEN** a user whose settings were copied from the old folder opens Wobbo, not connected
- **THEN** the Wobbo buddy walks in and offers to connect to Claude Code

#### Scenario: Declined before
- **WHEN** the user chose "Not now" earlier and starts Wobbo again, still not connected
- **THEN** no offer is shown at start, and the menu still offers to connect

#### Scenario: Already connected
- **WHEN** Wobbo starts, is connected, and it is not the first start
- **THEN** no welcome is shown

### Requirement: Connect to Claude Code
Connecting SHALL make every new Claude Code session report to Wobbo without the user typing any command. Wobbo SHALL find the user's Claude Code installation on its own and install the plugin it carries, which matches its own version. While connecting, the balloon SHALL show that it is busy; afterwards it SHALL say that new sessions will show up and that sessions already open must be restarted.

#### Scenario: Connect
- **WHEN** the user chooses "Connect to Claude Code" and then starts a new Claude Code session
- **THEN** that session appears as a buddy, and the `say` and `ask_user` tools are available in it

#### Scenario: Connecting fails
- **WHEN** Claude Code reports an error while installing
- **THEN** the balloon says that connecting failed, with Claude Code's first error line, and offers "Try again"

### Requirement: No double reporting
Connecting SHALL replace an existing install of the older `buddy-bridge` plugin and any other install of the `wobbo` plugin, so each session is reported once.

#### Scenario: Replacing the old plugin
- **WHEN** `buddy-bridge` is installed and the user connects
- **THEN** `buddy-bridge` is no longer installed and each session appears once

### Requirement: Claude Code not found
When Wobbo cannot find Claude Code, it SHALL say so in plain words with a link to Claude Code's install page and a "Try again" button. It SHALL NOT change any files.

#### Scenario: No Claude Code
- **WHEN** the user connects on a Mac without Claude Code
- **THEN** the balloon explains that Claude Code is needed, links to its install page, and nothing is changed

### Requirement: Connection state in the menu
The menu SHALL show whether Wobbo is connected to Claude Code, checked each time the menu opens: "Connect to Claude Code…" when not connected, and "Disconnect from Claude Code" when connected. Disconnecting SHALL remove the plugin and the marketplace Wobbo added, so new sessions no longer report to Wobbo.

#### Scenario: Connect later
- **WHEN** the user chose "Not now" and later chooses "Connect to Claude Code…" in the menu
- **THEN** Wobbo connects as from the welcome

#### Scenario: Disconnect
- **WHEN** the user chooses "Disconnect from Claude Code" and starts a new Claude Code session
- **THEN** no buddy appears for it, and the menu offers to connect again

### Requirement: Keeping the plugin current
When Wobbo starts while connected and the installed plugin is older than the one it carries, Wobbo SHALL update the plugin without asking. It SHALL then say once, in a balloon, that open sessions must be restarted to use the new version. When updating fails, the old plugin SHALL stay in place, and the menu SHALL offer to connect again.

#### Scenario: After updating Wobbo
- **WHEN** the user installs a newer Wobbo and opens it
- **THEN** the plugin is updated to Wobbo's version and a balloon says to restart open sessions
