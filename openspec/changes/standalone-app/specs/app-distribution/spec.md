## ADDED Requirements

### Requirement: Release build
One maintainer command SHALL build the app from a checkout into `Wobbo.app` and pack it as `Wobbo.dmg`, given the installed Godot version and its export templates. The app SHALL run on Apple silicon and Intel Macs with macOS 13 or later. The disk image SHALL show the app next to a link to Applications. Users SHALL NOT need this command or any other command.

#### Scenario: Build a release
- **WHEN** the maintainer runs the release command with a version number
- **THEN** it produces `Wobbo.dmg` holding `Wobbo.app` with that version, without opening the Godot editor

#### Scenario: Missing export templates
- **WHEN** the release command runs and the export templates for the installed Godot version are missing
- **THEN** it stops with a message that says how to install them, and leaves no half-built app or disk image behind

#### Scenario: Intel Mac
- **WHEN** a user opens the released app on an Intel Mac with macOS 13 or later
- **THEN** Wobbo runs as on Apple silicon

### Requirement: Publishing a release
The release command SHALL only publish when the maintainer asks for it explicitly. Publishing SHALL create a release with the disk image and release notes. The notes SHALL explain in plain steps, without commands:
- downloading and installing;
- the one-time "Open Anyway" for an app that is not notarized;
- connecting to Claude Code.

#### Scenario: Publish
- **WHEN** the maintainer runs the release command with the publish option
- **THEN** a release with `Wobbo.dmg` and the install steps appears on the download page

#### Scenario: Build only
- **WHEN** the maintainer runs the release command without the publish option
- **THEN** nothing is uploaded

### Requirement: First open of a download
The app is not notarized. A user who opens it for the first time SHALL be able to start it with only Finder and System Settings: the macOS warning, then "Open Anyway" under Privacy & Security. The steps SHALL be in the README and the release notes. Later opens SHALL start without a warning.

#### Scenario: First open
- **WHEN** a user downloads `Wobbo.dmg`, drags Wobbo to Applications, opens it, and confirms "Open Anyway" in System Settings
- **THEN** Wobbo starts, and later opens start without a warning

### Requirement: Moving to Applications
When Wobbo starts from outside an Applications folder (from the disk image, from Downloads, or from a location macOS has moved it to for safety), it SHALL offer once per start to move itself to `/Applications`. When the user accepts, Wobbo SHALL put itself there, replacing an older Wobbo that is not running, and start again from there. When the move fails, Wobbo SHALL say to drag it to Applications by hand.

#### Scenario: Started from the disk image
- **WHEN** the user opens Wobbo directly from the mounted disk image and accepts the offer
- **THEN** Wobbo restarts from `/Applications/Wobbo.app`

#### Scenario: Declined
- **WHEN** the user declines the offer
- **THEN** Wobbo keeps running where it is, and offers again on its next start

### Requirement: Name and identity towards macOS
macOS SHALL show the app as "Wobbo": in Finder, in the Accessibility list under Privacy & Security and in Login Items. Every release SHALL be signed with the same Wobbo signing identity, so a permission granted to one version stays granted after updating to a newer one. Without that identity the build SHALL still succeed, sign ad hoc and warn that permissions will be asked again.

#### Scenario: Shown under its own name
- **WHEN** Wobbo needs Accessibility access for the first time
- **THEN** macOS lists "Wobbo", not "Godot"

#### Scenario: Accessibility after an update
- **WHEN** the user has granted Wobbo Accessibility access and then installs a newer release
- **THEN** the newer Wobbo has Accessibility access without asking again

### Requirement: Data folder
Wobbo SHALL keep its per-user files in `~/Library/Application Support/Wobbo/`, both as the app and when run from the editor. When that folder has no settings file and `~/Library/Application Support/ClaudeBuddy/settings.cfg` exists, Wobbo SHALL copy it once at startup. The old folder SHALL be left in place.

#### Scenario: First start after the rename
- **WHEN** the user had chosen "Extra large" before the rename and starts Wobbo for the first time
- **THEN** the buddies are Extra large and a settings file exists in the new folder

#### Scenario: Later starts
- **WHEN** both folders contain a settings file
- **THEN** Wobbo reads only the one in the new folder

### Requirement: One running instance
At most one Wobbo SHALL run at a time per user, counting the app and editor runs alike. A second instance that finds another one alive SHALL quit at once without showing an overlay or a menu bar icon and without changing the bridge connection file, and SHALL log why. A connection file left by an instance that no longer runs SHALL NOT block a start.

#### Scenario: Second start
- **WHEN** Wobbo is running and the user opens it again, or the project is started from the Godot editor
- **THEN** the second instance quits, and the running Wobbo keeps its buddies and sessions

#### Scenario: After a crash
- **WHEN** Wobbo was killed and is started again
- **THEN** it starts normally
