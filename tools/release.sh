#!/bin/bash
# Builds, installs and publishes Wobbo (standalone-app design D1). For the
# maintainer only: users download Wobbo.dmg and never run a command.
#
#   tools/release.sh build <version> [--debug]   build/Wobbo.app and build/Wobbo.dmg
#   tools/release.sh install                     copy build/Wobbo.app to /Applications
#   tools/release.sh publish <version>           upload build/Wobbo.dmg as a GitHub release
#
# Environment:
#   GODOT                 Godot binary (default /Applications/Godot.app/Contents/MacOS/Godot)
#   WOBBO_SIGN_IDENTITY   signing identity (default "Wobbo", see tools/make_signing_cert.sh)
#   WOBBO_RELEASE_REPO    owner/repo where releases go (default: the GitHub repo of the origin remote)
#   WOBBO_GH_USER         gh account to publish with, when it is not gh's active one
set -Eeuo pipefail # -E: the ERR trap also fires inside functions

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
BUILD="$ROOT/build"
APP="$BUILD/Wobbo.app"
DMG="$BUILD/Wobbo.dmg"
IDENTITY="${WOBBO_SIGN_IDENTITY:-Wobbo}"
PLUGIN_DIR="Contents/Resources/wobbo-plugin"

say() { printf '\033[1m%s\033[0m\n' "$*"; }
die() { printf 'release: %s\n' "$*" >&2; exit 1; }

check_version() {
	[[ "${1:-}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "give a version like 0.2.0"
}

# The export templates for the installed Godot version must be installed once.
check_templates() {
	local version
	version="$("$GODOT" --version | cut -d. -f1-4)" # 4.7.2.stable
	local templates="$HOME/Library/Application Support/Godot/export_templates/$version/macos.zip"
	if [ ! -f "$templates" ]; then
		die "the Godot $version export templates are missing.
Install them once: Godot editor > Editor > Manage Export Templates > Download and Install."
	fi
}

# One version for the app and the plugin (design D8).
set_version() {
	local v="$1"
	sed -i '' -E "s/^application\/(short_version|version)=\".*\"/application\/\1=\"$v\"/" "$ROOT/godot/export_presets.cfg"
	sed -i '' -E "s/^config\/version=\".*\"/config\/version=\"$v\"/" "$ROOT/godot/project.godot"
	sed -i '' -E "s/(\"version\": )\"[^\"]*\"/\1\"$v\"/" "$ROOT/bridge/package.json" "$ROOT/bridge/plugin/.claude-plugin/plugin.json"
	sed -i '' -E "s/BRIDGE_VERSION = \"[^\"]*\"/BRIDGE_VERSION = \"$v\"/" "$ROOT/bridge/src/protocol.ts"
}

sign() {
	local identity="$IDENTITY"
	if ! security find-certificate -c "$identity" >/dev/null 2>&1; then
		say "warning: no \"$identity\" signing identity; signing ad hoc."
		say "         macOS will ask users for permissions (Accessibility) again after each update."
		identity="-"
	fi
	local framework
	for framework in "$APP"/Contents/Frameworks/*.framework; do
		codesign --force --timestamp=none --sign "$identity" "$framework"
	done
	codesign --force --timestamp=none --sign "$identity" "$APP/$PLUGIN_DIR/bin/wobbo-bridge"
	codesign --force --timestamp=none --sign "$identity" "$APP"
	codesign --verify --strict --deep "$APP"
}

make_dmg() {
	local staging="$BUILD/dmg"
	rm -rf "$staging" "$DMG"
	mkdir -p "$staging"
	ditto "$APP" "$staging/Wobbo.app"
	ln -s /Applications "$staging/Applications"
	local try
	for try in 1 2 3; do # hdiutil sometimes fails with "Resource busy"
		hdiutil create -quiet -volname "Wobbo" -srcfolder "$staging" -ov -format UDZO "$DMG" && break
		[ "$try" = 3 ] && return 1
		sleep 2
	done
	rm -rf "$staging"
}

# Puts Wobbo's own licences and every third-party notice in the app, under
# Contents/Resources/Licenses (open-source-readiness D5).
notices() {
	local dir="$APP/Contents/Resources/Licenses"
	mkdir -p "$dir"
	cp "$ROOT/LICENSE" "$ROOT/ARTWORK.md" "$ROOT/THIRD_PARTY_NOTICES.md" "$ROOT"/licenses/*.txt "$dir/"
	cp "$ROOT/godot/assets/fonts/OFL.txt" "$dir/Baloo2-OFL.txt"
	cp "$ROOT/native/godot-cpp/LICENSE.md" "$dir/godot-cpp-LICENSE.md"
	"$GODOT" --headless --path "$ROOT/godot" --script res://tools/godot_notices.gd -- "--out=$dir/godot-engine.txt" \
		>"$BUILD/notices.log" 2>&1
	[ -s "$dir/godot-engine.txt" ] || { cat "$BUILD/notices.log" >&2; die "could not write the Godot notices"; }
	(cd "$ROOT/bridge" && bun scripts/licenses.ts texts) >"$dir/wobbo-bridge-packages.txt"
}

build() {
	local version="${1:-}" mode="release"
	check_version "$version"
	[ "${2:-}" = "--debug" ] && mode="debug"
	check_templates
	rm -rf "$APP" "$DMG"
	trap 'rm -rf "$APP" "$DMG" "$BUILD/dmg"; die "build failed; nothing was left behind"' ERR

	say "Version $version"
	set_version "$version"

	say "Native extension (universal)"
	scons -C "$ROOT/native" -s target="template_$mode" arch=universal -j"$(sysctl -n hw.ncpu)"

	say "Bridge (universal)"
	(cd "$ROOT/bridge" && bun run build:universal >/dev/null)
	mkdir -p "$ROOT/bridge/plugin/bin"
	rm -f "$ROOT/bridge/plugin/bin/claude-buddy-bridge"
	cp "$ROOT/bridge/dist/wobbo-bridge" "$ROOT/bridge/plugin/bin/wobbo-bridge"

	say "Godot export ($mode)"
	mkdir -p "$BUILD"
	"$GODOT" --headless --path "$ROOT/godot" "--export-$mode" "macOS" "$APP" >"$BUILD/export.log" 2>&1 \
		|| { tail -20 "$BUILD/export.log" >&2; false; }
	[ -x "$APP/Contents/MacOS/Wobbo" ] || { tail -20 "$BUILD/export.log" >&2; false; }

	say "Claude Code plugin"
	mkdir -p "$APP/$PLUGIN_DIR"
	rsync -a --delete --exclude .DS_Store "$ROOT/bridge/plugin/" "$APP/$PLUGIN_DIR/"

	say "Licences"
	notices

	say "Signing"
	sign

	say "Disk image"
	make_dmg
	trap - ERR
	say "Done: $APP and $DMG"
}

install_app() {
	[ -d "$APP" ] || die "build first: tools/release.sh build <version>"
	if pgrep -x Wobbo >/dev/null; then
		die "Quit Wobbo first (menu bar icon > Quit Wobbo)."
	fi
	rm -rf /Applications/Wobbo.app
	ditto "$APP" /Applications/Wobbo.app
	say "Installed /Applications/Wobbo.app"
}

# Where releases go: WOBBO_RELEASE_REPO, or the GitHub repository of the origin
# remote, so a fork never publishes to someone else's (open-source-readiness D7).
release_repo() {
	if [ -n "${WOBBO_RELEASE_REPO:-}" ]; then
		echo "$WOBBO_RELEASE_REPO"
		return
	fi
	local url
	url="$(git -C "$ROOT" remote get-url origin 2>/dev/null)" || die "no origin remote; set WOBBO_RELEASE_REPO=owner/repo"
	[[ "$url" =~ github\.com[:/]([^/]+/[^/]+)$ ]] || die "origin is not a GitHub repository ($url); set WOBBO_RELEASE_REPO=owner/repo"
	echo "${BASH_REMATCH[1]%.git}"
}

publish() {
	local version="${1:-}"
	check_version "$version"
	[ -f "$DMG" ] || die "build first: tools/release.sh build $version"
	local built
	built="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$APP/Contents/Info.plist")"
	[ "$built" = "$version" ] || die "build/Wobbo.app is version $built, not $version"
	if [ -n "${WOBBO_GH_USER:-}" ]; then
		GH_TOKEN="$(gh auth token --user "$WOBBO_GH_USER")"
		export GH_TOKEN
	fi
	local repo
	repo="$(release_repo)"
	gh repo view "$repo" >/dev/null 2>&1 || die "no access to the GitHub repository $repo; create it first, or set WOBBO_RELEASE_REPO"
	local notes="$BUILD/release-notes.md"
	sed "s/{{VERSION}}/$version/g" "$ROOT/tools/release-notes.md" >"$notes"
	gh release create "v$version" "$DMG" --repo "$repo" --title "Wobbo $version" --notes-file "$notes"
	say "Published: https://github.com/$repo/releases/tag/v$version"
}

case "${1:-}" in
	build) shift; build "$@" ;;
	install) install_app ;;
	publish) shift; publish "$@" ;;
	*) sed -n '2,13p' "$0" | sed 's/^# \{0,1\}//'; exit 2 ;;
esac
