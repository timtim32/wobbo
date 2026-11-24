#!/bin/bash
# Records the Wobbo trailer: a short scripted show of pretend sessions, saved as
# an MP4 and a GIF.
#
#   tools/record-trailer.sh [--out DIR] [--size small|normal|large|xl]
#                           [--bg '#top,#bottom'] [--gif-width PX] [--gif-fps N]
#
# Nothing of your own Mac ends up in the video:
# - Wobbo runs from this repo in trailer mode: it does not listen for agents, so
#   your real sessions (names, messages, questions) never appear; it shows no
#   welcome and does not save settings.
# - Only the strip the buddies walk on is recorded, over an opaque backdrop that
#   Wobbo paints itself: no menu bar, Dock, wallpaper, windows or mouse pointer.
#   The crop happens while recording, so no full-screen frame is written to disk.
# - A running Wobbo is quit first and opened again afterwards.
#
# Needs ffmpeg (brew install ffmpeg), Godot at /Applications/Godot.app (or
# $GODOT), and Screen Recording permission for the app that runs this script
# (System Settings -> Privacy & Security -> Screen & System Audio Recording).
# gifski (brew install gifski) makes a sharper, smaller GIF when installed.
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
OUT="$REPO/build/trailer"
SIZE="large"
BG=""
GIF_WIDTH=960
GIF_FPS=15
MP4_MAX_WIDTH=1920

while [ $# -gt 0 ]; do
	case "$1" in
		--out) OUT="$2"; shift 2 ;;
		--size) SIZE="$2"; shift 2 ;;
		--bg) BG="$2"; shift 2 ;;
		--gif-width) GIF_WIDTH="$2"; shift 2 ;;
		--gif-fps) GIF_FPS="$2"; shift 2 ;;
		-h|--help) sed -n '2,21p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
		*) echo "Unknown option: $1 (see --help)" >&2; exit 2 ;;
	esac
done

die() { echo "record-trailer: $*" >&2; exit 1; }
command -v ffmpeg >/dev/null || die "ffmpeg not found (brew install ffmpeg)"
[ -x "$GODOT" ] || die "Godot not found at $GODOT (set \$GODOT)"

WORK="$(mktemp -d -t wobbo-trailer)"
GODOT_PID=""
FFMPEG_PID=""
REOPEN=""

cleanup() {
	[ -n "$FFMPEG_PID" ] && kill -INT "$FFMPEG_PID" 2>/dev/null || true
	if [ -n "$GODOT_PID" ] && kill -0 "$GODOT_PID" 2>/dev/null; then
		touch "$WORK/quit"
		sleep 1
		kill "$GODOT_PID" 2>/dev/null || true
	fi
	rm -rf "$WORK"
	if [ -n "$REOPEN" ]; then
		echo "Opening Wobbo again."
		open -a Wobbo || true
	fi
}
trap cleanup EXIT

# Seconds to wait for a file in the handshake folder while Godot keeps running.
wait_for() {
	local file="$1" timeout="$2" waited=0
	while [ ! -e "$WORK/$file" ]; do
		if ! kill -0 "$GODOT_PID" 2>/dev/null; then
			echo "--- Godot log ---" >&2; tail -n 20 "$WORK/godot.log" >&2
			die "Wobbo stopped before writing $file (is another Wobbo or a Godot run still open?)"
		fi
		[ "$waited" -ge "$((timeout * 10))" ] && die "timed out waiting for $file"
		sleep 0.1
		waited=$((waited + 1))
	done
}

# 1. Quit a running Wobbo: two would both draw buddies, with real names.
if pgrep -x Wobbo >/dev/null; then
	echo "Quitting Wobbo for the recording."
	osascript -e 'tell application "Wobbo" to quit' >/dev/null 2>&1 || true
	for _ in $(seq 50); do pgrep -x Wobbo >/dev/null || break; sleep 0.2; done
	pgrep -x Wobbo >/dev/null && die "Wobbo did not quit; quit it from its menu bar icon and try again"
	REOPEN=1
fi

# 2. Start Wobbo in trailer mode and wait for the strip it will draw on.
echo "Starting Wobbo in trailer mode."
ARGS=(--trailer="$WORK" --trailer-size="$SIZE")
[ -n "$BG" ] && ARGS+=(--trailer-bg="$BG")
"$GODOT" --path "$REPO/godot" -- "${ARGS[@]}" >"$WORK/godot.log" 2>&1 &
GODOT_PID=$!
wait_for strip.json 30

num() { plutil -extract "$1" raw -o - "$WORK/strip.json"; }
SX=$(num x); SY=$(num y); SW=$(num w); SH=$(num h)
SHOW_SEC=$(num show_sec)
# Even numbers for H.264, rounded so the crop stays inside the strip.
X=$(( (SX + 1) / 2 * 2 )); Y=$(( (SY + 1) / 2 * 2 ))
W=$(( (SW - (X - SX)) / 2 * 2 )); H=$(( (SH - (Y - SY)) / 2 * 2 ))
echo "Recording the strip: ${W}x${H} px at ${X},${Y} of the main display."

# 3. Record only that strip of the main display, without the mouse pointer.
ffmpeg -nostdin -hide_banner -loglevel error -y \
	-f avfoundation -capture_cursor 0 -capture_mouse_clicks 0 -framerate 30 -i "Capture screen 0:none" \
	-vf "crop=${W}:${H}:${X}:${Y}" -c:v libx264 -preset ultrafast -crf 8 -pix_fmt yuv420p \
	-progress "$WORK/progress" -stats_period 0.2 \
	"$WORK/raw.mkv" 2>"$WORK/ffmpeg.log" &
FFMPEG_PID=$!
# Frames are flowing once ffmpeg reports a frame (the file itself grows late).
for _ in $(seq 150); do
	grep -qE '^frame=[1-9]' "$WORK/progress" 2>/dev/null && break
	kill -0 "$FFMPEG_PID" 2>/dev/null || break
	sleep 0.1
done
if ! kill -0 "$FFMPEG_PID" 2>/dev/null; then
	cat "$WORK/ffmpeg.log" >&2
	FFMPEG_PID=""
	die "the screen recording did not start; allow Screen Recording for this terminal app"
fi

# 4. The show. Hands off the mouse: nothing to click.
echo "Recording (about $(printf '%.0f' "$SHOW_SEC") s plus walking off)..."
touch "$WORK/go"
wait_for done "$(( ${SHOW_SEC%.*} + 60 ))"
kill -INT "$FFMPEG_PID"
wait "$FFMPEG_PID" || true
FFMPEG_PID=""
touch "$WORK/quit"
wait "$GODOT_PID" || true
GODOT_PID=""

# 5. MP4 (for GitHub, sites, Slack) and GIF.
mkdir -p "$OUT"
echo "Writing $OUT/wobbo-trailer.mp4"
ffmpeg -nostdin -hide_banner -loglevel error -y -i "$WORK/raw.mkv" \
	-vf "scale='min(${MP4_MAX_WIDTH},iw)':-2:flags=lanczos" \
	-c:v libx264 -preset slow -crf 20 -pix_fmt yuv420p -movflags +faststart -an \
	"$OUT/wobbo-trailer.mp4"

echo "Writing $OUT/wobbo-trailer.gif"
if command -v gifski >/dev/null; then
	mkdir "$WORK/frames"
	ffmpeg -nostdin -hide_banner -loglevel error -i "$WORK/raw.mkv" \
		-vf "fps=${GIF_FPS},scale=${GIF_WIDTH}:-1:flags=lanczos" "$WORK/frames/f%05d.png"
	gifski --quiet --fps "$GIF_FPS" --quality 90 -o "$OUT/wobbo-trailer.gif" "$WORK"/frames/f*.png
else
	ffmpeg -nostdin -hide_banner -loglevel error -y -i "$WORK/raw.mkv" \
		-vf "fps=${GIF_FPS},scale=${GIF_WIDTH}:-1:flags=lanczos,split[a][b];[a]palettegen=stats_mode=diff[p];[b][p]paletteuse=dither=bayer:bayer_scale=4:diff_mode=rectangle" \
		-loop 0 "$OUT/wobbo-trailer.gif"
fi

ls -lh "$OUT"/wobbo-trailer.* | awk '{print "  " $5 "  " $9}'
echo "Done. Check the video before sharing it."
