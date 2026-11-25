extends SceneTree
## Builds the monster's animation libraries (character-rig D4).
##
##   /Applications/Godot.app/Contents/MacOS/Godot --headless --path godot --script res://tools/build_monster_clips.gd
##
## Writes res://characters/monster/clips/body_clips.tres (BodyPlayer) and
## face_clips.tres (FacePlayer). Clip timing lives in the data below; edits made
## to the .tres files in the editor are overwritten by the next build.
##
## Units: rotation in radians (positive = clockwise on screen), positions in
## export pixels relative to the rest pose (the figure is ~409 px tall),
## pupil_bias in -1..1 of the pupil's travel. For the left arm and left ear a
## positive rotation moves them outward/up; for the right ones, negative does.

const OUT_DIR := "res://characters/monster/clips/"

## Every body track with its rest value. Each body clip keys all of them, so a
## clip never inherits a pose from the previous one.
const BODY_TRACKS := {
	"root_pos": ["Skeleton2D/root:position", Vector2.ZERO],
	"body_rot": ["Skeleton2D/root/body:rotation", 0.0],
	"body_scale": ["Skeleton2D/root/body:scale", Vector2.ONE],
	"leg_l": ["Skeleton2D/root/leg_l:rotation", 0.0],
	"leg_r": ["Skeleton2D/root/leg_r:rotation", 0.0],
	"arm_l": ["Skeleton2D/root/body/arm_l:rotation", 0.0],
	"arm_r": ["Skeleton2D/root/body/arm_r:rotation", 0.0],
	# Thinking swaps the hanging right arm for a drawn arm in front of the body
	# with the hand at the chin (part arm_r_think); its rotation is the tap.
	"arm_r_shown": ["Skeleton2D/root/body/arm_r/ArmR:visible", true],
	"arm_r_think_shown": ["Skeleton2D/root/body/ArmRThink:visible", false],
	"arm_r_think_rot": ["Skeleton2D/root/body/ArmRThink:rotation", 0.0],
	# work-and-wait D3/D4: the front arms (laptop, papers) replace the hanging
	# arms; props are shown only by their own work clip.
	"arm_l_shown": ["Skeleton2D/root/body/arm_l/ArmL:visible", true],
	# Arms drawn in front of the body instead of behind it (waiting: arms up in front).
	"arm_l_z": ["Skeleton2D/root/body/arm_l/ArmL:z_index", 0],
	"arm_r_z": ["Skeleton2D/root/body/arm_r/ArmR:z_index", 0],
	"arm_front_l_shown": ["Skeleton2D/root/body/ArmFrontL:visible", false],
	"arm_front_r_shown": ["Skeleton2D/root/body/ArmFrontR:visible", false],
	"arm_front_l_rot": ["Skeleton2D/root/body/ArmFrontL:rotation", 0.0],
	"arm_front_r_rot": ["Skeleton2D/root/body/ArmFrontR:rotation", 0.0],
	"prop_hammer_shown": ["Skeleton2D/root/body/arm_r/PropHammer:visible", false],
	# The hammer turns around the fist, so its handle stays across the arm.
	"prop_hammer_rot": ["Skeleton2D/root/body/arm_r/PropHammer:rotation", 0.0],
	"prop_wrench_shown": ["Skeleton2D/root/body/arm_r/PropWrench:visible", false],
	"prop_laptop_shown": ["Skeleton2D/root/body/PropLaptop:visible", false],
	"prop_papers_shown": ["Skeleton2D/root/body/PropPapers:visible", false],
	"prop_page_shown": ["Skeleton2D/root/body/PropPage:visible", false],
	"prop_page_scale": ["Skeleton2D/root/body/PropPage:scale", Vector2.ONE],
	# Opening the laptop and taking the papers (work-and-wait D7).
	"prop_laptop_scale": ["Skeleton2D/root/body/PropLaptop:scale", Vector2.ONE],
	"prop_papers_scale": ["Skeleton2D/root/body/PropPapers:scale", Vector2.ONE],
	"ear_l": ["Skeleton2D/root/body/ear_l:rotation", 0.0],
	"ear_r": ["Skeleton2D/root/body/ear_r:rotation", 0.0],
	"eye_scale": ["Skeleton2D/root/body/eye:scale", Vector2.ONE],
	"pupil_bias": [".:pupil_bias", Vector2.ZERO],
}
## Tracks that switch instead of interpolating.
const DISCRETE_TRACKS := ["arm_r_shown", "arm_r_think_shown", "arm_l_shown", "arm_l_z", "arm_r_z", "arm_front_l_shown",
	"arm_front_r_shown", "prop_hammer_shown", "prop_wrench_shown", "prop_laptop_shown", "prop_papers_shown",
	"prop_page_shown"]
## Tracks that interpolate linearly (cubic would overshoot, e.g. the page flip).
const LINEAR_TRACKS := ["prop_page_scale", "prop_laptop_scale", "prop_papers_scale"]
## The work clips with props (work-and-wait D4).
const WORK_CLIPS := ["work_hammer", "work_laptop", "work_wrench", "work_papers"]
## Their transitions (work-and-wait D7).
const WORK_TRANSITIONS := ["work_hammer_in", "work_hammer_out", "work_laptop_in", "work_laptop_out",
	"work_wrench_in", "work_wrench_out", "work_papers_in", "work_papers_out"]
const MOUTHS := {
	"neutral": "Skeleton2D/root/body/mouth/MouthNeutral:visible",
	"smile": "Skeleton2D/root/body/mouth/MouthSmile:visible",
	"open": "Skeleton2D/root/body/mouth/MouthOpen:visible",
	"laugh": "Skeleton2D/root/body/mouth/MouthLaugh:visible",
}


static func v(x: float, y: float) -> Vector2:
	return Vector2(x, y)


## Body clips: name -> {length, loop, mouth, tracks: {track: [[time, value], ...]}}.
## Looping clips start and end on the same value for every track.
static func body_clips() -> Dictionary:
	return {
		"idle": {"length": 2.4, "loop": true, "mouth": "neutral", "tracks": {
			"body_scale": [[0.0, v(1, 1)], [1.2, v(1.025, 0.975)], [2.4, v(1, 1)]],
			"arm_l": [[0.0, 0.0], [1.2, 0.05], [2.4, 0.0]],
			"arm_r": [[0.0, 0.0], [1.2, -0.05], [2.4, 0.0]],
			"ear_l": [[0.0, 0.0], [0.8, 0.06], [1.6, -0.02], [2.4, 0.0]],
			"ear_r": [[0.0, 0.0], [0.8, -0.06], [1.6, 0.02], [2.4, 0.0]],
		}},
		"walk": {"length": 0.6, "loop": true, "mouth": "neutral", "tracks": {
			"root_pos": [[0.0, v(0, 0)], [0.15, v(0, -10)], [0.3, v(0, 0)], [0.45, v(0, -10)], [0.6, v(0, 0)]],
			"body_rot": [[0.0, -0.01], [0.3, 0.09], [0.6, -0.01]],
			"body_scale": [[0.0, v(1.03, 0.97)], [0.15, v(0.98, 1.02)], [0.3, v(1.03, 0.97)],
				[0.45, v(0.98, 1.02)], [0.6, v(1.03, 0.97)]],
			"leg_l": [[0.0, 0.2], [0.3, -0.12], [0.6, 0.2]],
			"leg_r": [[0.0, 0.12], [0.3, -0.2], [0.6, 0.12]],
			"arm_l": [[0.0, 0.28], [0.3, 0.04], [0.6, 0.28]],
			"arm_r": [[0.0, -0.04], [0.3, -0.28], [0.6, -0.04]],
			"ear_l": [[0.0, 0.07], [0.15, -0.07], [0.3, 0.07], [0.45, -0.07], [0.6, 0.07]],
			"ear_r": [[0.0, -0.07], [0.15, 0.07], [0.3, -0.07], [0.45, 0.07], [0.6, -0.07]],
			"pupil_bias": [[0.0, v(0.5, 0.0)]],
		}},
		"wave": {"length": 1.8, "loop": false, "mouth": "smile", "tracks": {
			"arm_r": [[0.0, 0.0], [0.3, -2.5], [0.5, -2.05], [0.7, -2.5], [0.9, -2.05], [1.1, -2.5],
				[1.5, 0.0], [1.8, 0.0]],
			"body_rot": [[0.0, 0.0], [0.3, -0.05], [1.4, -0.05], [1.8, 0.0]],
			"ear_r": [[0.0, 0.0], [0.3, -0.12], [1.4, -0.12], [1.8, 0.0]],
			"pupil_bias": [[0.0, v(0, 0)], [0.3, v(0.25, -0.1)], [1.4, v(0.25, -0.1)], [1.8, v(0, 0)]],
		}},
		"sleep": {"length": 3.2, "loop": true, "mouth": "neutral", "tracks": {
			"body_scale": [[0.0, v(1, 1)], [1.6, v(1.04, 0.96)], [3.2, v(1, 1)]],
			"body_rot": [[0.0, 0.06]],
			"ear_l": [[0.0, -0.3], [1.6, -0.34], [3.2, -0.3]],
			"ear_r": [[0.0, 0.3], [1.6, 0.34], [3.2, 0.3]],
			"arm_l": [[0.0, -0.04]],
			"arm_r": [[0.0, 0.04]],
		}},
		"thinking": {"length": 2.4, "loop": true, "mouth": "neutral", "tracks": {
			"pupil_bias": [[0.0, v(0.7, -0.7)]],
			"body_rot": [[0.0, 0.05], [1.2, 0.09], [2.4, 0.05]],
			"root_pos": [[0.0, v(0, 0)], [0.6, v(0, -4)], [1.2, v(0, 0)], [1.8, v(0, -4)], [2.4, v(0, 0)]],
			# The thinking-face pose: hand at the chin, tapping it twice, then a pause.
			"arm_r_shown": [[0.0, false]],
			"arm_r_think_shown": [[0.0, true]],
			"arm_r_think_rot": [[0.0, 0.0], [0.25, 0.05], [0.5, 0.0], [0.75, 0.05], [1.0, 0.0], [2.4, 0.0]],
			"ear_r": [[0.0, -0.1], [0.25, -0.18], [0.5, -0.1], [0.75, -0.18], [1.0, -0.1], [2.4, -0.1]],
			"ear_l": [[0.0, 0.0], [1.6, 0.0], [1.7, 0.14], [1.85, 0.0], [2.4, 0.0]],
			"eye_scale": [[0.0, v(1, 0.96)]],
		}},
		"working": {"length": 0.8, "loop": true, "mouth": "neutral", "tracks": {
			"pupil_bias": [[0.0, v(0, 0.6)]],
			"arm_l": [[0.0, 0.18], [0.1, -0.12], [0.2, 0.18], [0.3, -0.12], [0.4, 0.18],
				[0.5, -0.12], [0.6, 0.18], [0.7, -0.12], [0.8, 0.18]],
			"arm_r": [[0.0, 0.12], [0.1, -0.18], [0.2, 0.12], [0.3, -0.18], [0.4, 0.12],
				[0.5, -0.18], [0.6, 0.12], [0.7, -0.18], [0.8, 0.12]],
			"root_pos": [[0.0, v(0, 0)], [0.2, v(0, -5)], [0.4, v(0, 0)], [0.6, v(0, -5)], [0.8, v(0, 0)]],
			"body_scale": [[0.0, v(1, 1)], [0.2, v(0.98, 1.02)], [0.4, v(1, 1)], [0.6, v(0.98, 1.02)], [0.8, v(1, 1)]],
			"body_rot": [[0.0, 0.03]],
		}},
		"happy": {"length": 1.6, "loop": false, "mouth": "laugh", "tracks": {
			# Jump with arms up, then a few short "ha-ha" bounces with a squinting eye.
			"root_pos": [[0.0, v(0, 0)], [0.12, v(0, 6)], [0.4, v(0, -70)], [0.68, v(0, 0)], [0.8, v(0, 4)],
				[0.9, v(0, -10)], [1.0, v(0, 0)], [1.1, v(0, -10)], [1.2, v(0, 0)], [1.3, v(0, -8)],
				[1.4, v(0, 0)], [1.6, v(0, 0)]],
			"body_scale": [[0.0, v(1, 1)], [0.12, v(1.1, 0.88)], [0.3, v(0.93, 1.08)], [0.68, v(1.08, 0.9)],
				[0.8, v(1, 1)], [0.9, v(0.97, 1.04)], [1.0, v(1.04, 0.96)], [1.1, v(0.97, 1.04)],
				[1.2, v(1.04, 0.96)], [1.3, v(0.98, 1.03)], [1.4, v(1.02, 0.98)], [1.6, v(1, 1)]],
			"body_rot": [[0.0, 0.0], [0.8, 0.0], [1.0, 0.05], [1.2, -0.05], [1.4, 0.03], [1.6, 0.0]],
			"arm_l": [[0.0, 0.0], [0.15, 0.2], [0.35, 2.3], [0.7, 2.3], [0.9, 0.6], [1.0, 0.85], [1.1, 0.6],
				[1.2, 0.85], [1.6, 0.0]],
			"arm_r": [[0.0, 0.0], [0.15, -0.2], [0.35, -2.3], [0.7, -2.3], [0.9, -0.6], [1.0, -0.85], [1.1, -0.6],
				[1.2, -0.85], [1.6, 0.0]],
			"ear_l": [[0.0, 0.0], [0.35, 0.25], [1.3, 0.25], [1.6, 0.0]],
			"ear_r": [[0.0, 0.0], [0.35, -0.25], [1.3, -0.25], [1.6, 0.0]],
			"eye_scale": [[0.0, v(1, 1)], [0.3, v(1.12, 1.12)], [0.8, v(1.12, 1.12)], [0.9, v(1.08, 0.88)],
				[1.4, v(1.08, 0.88)], [1.6, v(1, 1)]],
			"pupil_bias": [[0.0, v(0, 0)], [0.3, v(0, -0.3)], [1.4, v(0, -0.3)], [1.6, v(0, 0)]],
		}},
		"error": {"length": 1.0, "loop": false, "mouth": "open", "tracks": {
			"root_pos": [[0.0, v(0, 0)], [0.05, v(-8, 0)], [0.1, v(8, 0)], [0.15, v(-8, 0)], [0.2, v(8, 0)],
				[0.25, v(0, 0)], [1.0, v(0, 0)]],
			"body_scale": [[0.0, v(1, 1)], [0.08, v(0.92, 1.1)], [0.3, v(1, 1)], [1.0, v(1, 1)]],
			"body_rot": [[0.0, 0.0], [0.1, -0.08], [0.3, 0.0], [1.0, 0.0]],
			"eye_scale": [[0.0, v(1, 1)], [0.08, v(1.2, 1.2)], [0.6, v(1.2, 1.2)], [1.0, v(1, 1)]],
			"arm_l": [[0.0, 0.0], [0.08, 1.0], [0.6, 0.9], [1.0, 0.0]],
			"arm_r": [[0.0, 0.0], [0.08, -1.0], [0.6, -0.9], [1.0, 0.0]],
			"ear_l": [[0.0, 0.0], [0.08, 0.35], [0.6, 0.3], [1.0, 0.0]],
			"ear_r": [[0.0, 0.0], [0.08, -0.35], [0.6, -0.3], [1.0, 0.0]],
		}},
		# work-and-wait D2: keeps hopping with both arms shaking high in the air.
		"waiting": {"length": 1.2, "loop": true, "mouth": "open", "tracks": {
			"arm_l_z": [[0.0, 1]],
			"arm_r_z": [[0.0, 1]],
			"root_pos": [[0.0, v(0, 0)], [0.08, v(0, 6)], [0.3, v(0, -40)], [0.52, v(0, 0)], [0.6, v(0, 6)],
				[0.82, v(0, -40)], [1.04, v(0, 0)], [1.2, v(0, 0)]],
			"body_scale": [[0.0, v(1, 1)], [0.08, v(1.08, 0.9)], [0.2, v(0.94, 1.08)], [0.45, v(1, 1)],
				[0.52, v(1.06, 0.92)], [0.6, v(1.08, 0.9)], [0.72, v(0.94, 1.08)], [0.97, v(1, 1)],
				[1.04, v(1.06, 0.92)], [1.2, v(1, 1)]],
			"arm_l": [[0.0, 2.35], [0.1, 2.7], [0.2, 2.35], [0.3, 2.7], [0.4, 2.35], [0.5, 2.7], [0.6, 2.35],
				[0.7, 2.7], [0.8, 2.35], [0.9, 2.7], [1.0, 2.35], [1.1, 2.7], [1.2, 2.35]],
			"arm_r": [[0.0, -2.7], [0.1, -2.35], [0.2, -2.7], [0.3, -2.35], [0.4, -2.7], [0.5, -2.35], [0.6, -2.7],
				[0.7, -2.35], [0.8, -2.7], [0.9, -2.35], [1.0, -2.7], [1.1, -2.35], [1.2, -2.7]],
			"ear_l": [[0.0, 0.1], [0.3, -0.15], [0.52, 0.25], [0.82, -0.15], [1.04, 0.25], [1.2, 0.1]],
			"ear_r": [[0.0, -0.1], [0.3, 0.15], [0.52, -0.25], [0.82, 0.15], [1.04, -0.25], [1.2, -0.1]],
			"eye_scale": [[0.0, v(1.08, 1.08)]],
			"pupil_bias": [[0.0, v(0, 0.15)]],
		}},
		# dock-dodge D4: a quick jump onto or off the Dock. The lift itself moves the
		# avatar; this only adds the take-off stretch, arms up and the landing squash.
		"dock_hop": {"length": 0.36, "loop": false, "mouth": "open", "tracks": {
			"arm_l_z": [[0.0, 1]],
			"arm_r_z": [[0.0, 1]],
			"root_pos": [[0.0, v(0, 0)], [0.04, v(0, 5)], [0.1, v(0, 0)], [0.3, v(0, 5)], [0.36, v(0, 0)]],
			"body_scale": [[0.0, v(1, 1)], [0.04, v(1.08, 0.9)], [0.1, v(0.92, 1.1)], [0.24, v(1, 1)],
				[0.3, v(1.1, 0.88)], [0.36, v(1, 1)]],
			"arm_l": [[0.0, 0.0], [0.1, 2.2], [0.24, 2.2], [0.32, 0.3], [0.36, 0.0]],
			"arm_r": [[0.0, 0.0], [0.1, -2.2], [0.24, -2.2], [0.32, -0.3], [0.36, 0.0]],
			"leg_l": [[0.0, 0.0], [0.12, -0.2], [0.24, -0.2], [0.3, 0.0]],
			"leg_r": [[0.0, 0.0], [0.12, 0.2], [0.24, 0.2], [0.3, 0.0]],
			"ear_l": [[0.0, 0.0], [0.1, 0.3], [0.3, 0.1], [0.36, 0.0]],
			"ear_r": [[0.0, 0.0], [0.1, -0.3], [0.3, -0.1], [0.36, 0.0]],
			"eye_scale": [[0.0, v(1, 1)], [0.1, v(1.12, 1.12)], [0.3, v(1.05, 1.05)], [0.36, v(1, 1)]],
			"pupil_bias": [[0.0, v(0, 0)], [0.1, v(0, -0.4)], [0.36, v(0, 0)]],
		}},
		# buddy-drag D7: held up by the pointer. Legs kick in turn, arms flail above
		# the body out of step, ears flop, eye wide. The swing itself rotates the view.
		"dangle": {"length": 0.6, "loop": true, "mouth": "open", "tracks": {
			"arm_l_z": [[0.0, 1]],
			"arm_r_z": [[0.0, 1]],
			"body_rot": [[0.0, -0.04], [0.3, 0.04], [0.6, -0.04]],
			"body_scale": [[0.0, v(0.96, 1.05)], [0.15, v(0.98, 1.03)], [0.3, v(0.96, 1.05)],
				[0.45, v(0.98, 1.03)], [0.6, v(0.96, 1.05)]],
			"leg_l": [[0.0, 0.4], [0.15, -0.3], [0.3, 0.4], [0.45, -0.3], [0.6, 0.4]],
			"leg_r": [[0.0, -0.3], [0.15, 0.4], [0.3, -0.3], [0.45, 0.4], [0.6, -0.3]],
			"arm_l": [[0.0, 2.0], [0.1, 2.8], [0.2, 2.1], [0.35, 2.7], [0.5, 2.2], [0.6, 2.0]],
			"arm_r": [[0.0, -2.6], [0.12, -2.0], [0.25, -2.8], [0.4, -2.1], [0.5, -2.7], [0.6, -2.6]],
			"ear_l": [[0.0, 0.3], [0.2, -0.2], [0.4, 0.35], [0.6, 0.3]],
			"ear_r": [[0.0, -0.2], [0.2, 0.3], [0.4, -0.35], [0.6, -0.2]],
			"eye_scale": [[0.0, v(1.15, 1.15)]],
			"pupil_bias": [[0.0, v(0, -0.2)]],
		}},
		# side-climb D7: climbing a display's side edge, hand over hand. The view
		# faces the edge; arms reach up in turns in front of the body, the legs
		# push in counter-phase, a small hitch on each pull, eye up along the edge.
		"climb": {"length": 0.6, "loop": true, "mouth": "neutral", "tracks": {
			"arm_l_z": [[0.0, 1]],
			"arm_r_z": [[0.0, 1]],
			"root_pos": [[0.0, v(0, 0)], [0.12, v(0, -8)], [0.3, v(0, 0)], [0.42, v(0, -8)], [0.6, v(0, 0)]],
			"body_rot": [[0.0, 0.1], [0.3, 0.14], [0.6, 0.1]],
			"body_scale": [[0.0, v(0.98, 1.03)], [0.12, v(1.02, 0.98)], [0.3, v(0.98, 1.03)],
				[0.42, v(1.02, 0.98)], [0.6, v(0.98, 1.03)]],
			"arm_l": [[0.0, 2.8], [0.3, 1.5], [0.6, 2.8]],
			"arm_r": [[0.0, -1.5], [0.3, -2.8], [0.6, -1.5]],
			"leg_l": [[0.0, -0.1], [0.3, 0.45], [0.6, -0.1]],
			"leg_r": [[0.0, -0.45], [0.3, 0.1], [0.6, -0.45]],
			"ear_l": [[0.0, 0.08], [0.15, -0.05], [0.3, 0.08], [0.45, -0.05], [0.6, 0.08]],
			"ear_r": [[0.0, -0.05], [0.15, 0.08], [0.3, -0.05], [0.45, 0.08], [0.6, -0.05]],
			"pupil_bias": [[0.0, v(0.45, -0.6)]],
		}},
		# buddy-drag D7: touching down after a drop. Squash with bent legs and arms
		# out, spring back, settle in the idle pose.
		"land": {"length": 0.35, "loop": false, "mouth": "open", "tracks": {
			"root_pos": [[0.0, v(0, 0)], [0.06, v(0, 4)], [0.18, v(0, -3)], [0.35, v(0, 0)]],
			"body_scale": [[0.0, v(1.15, 0.85)], [0.07, v(1.18, 0.82)], [0.18, v(0.94, 1.07)],
				[0.28, v(1.02, 0.98)], [0.35, v(1, 1)]],
			"leg_l": [[0.0, 0.3], [0.1, 0.35], [0.28, 0.0], [0.35, 0.0]],
			"leg_r": [[0.0, -0.3], [0.1, -0.35], [0.28, 0.0], [0.35, 0.0]],
			"arm_l": [[0.0, 1.0], [0.1, 1.2], [0.3, 0.0], [0.35, 0.0]],
			"arm_r": [[0.0, -1.0], [0.1, -1.2], [0.3, 0.0], [0.35, 0.0]],
			"ear_l": [[0.0, 0.35], [0.12, -0.15], [0.35, 0.0]],
			"ear_r": [[0.0, -0.35], [0.12, 0.15], [0.35, 0.0]],
			"eye_scale": [[0.0, v(1.1, 0.9)], [0.18, v(1.0, 1.05)], [0.35, v(1, 1)]],
		}},
		# work-and-wait D7: taking each prop and putting it away again (one-shots).
		# Hammer and wrench come from behind the back, over the shoulder: the hand
		# is behind the head when the prop appears.
		"work_hammer_in": {"length": 0.6, "loop": false, "mouth": "neutral", "tracks": {
			"prop_hammer_shown": [[0.0, false], [0.26, true]],
			"prop_hammer_rot": [[0.0, 0.0], [0.3, 0.0], [0.6, 3.14]],
			"arm_r": [[0.0, 0.0], [0.25, -2.9], [0.6, -1.1]],
			"body_rot": [[0.0, 0.0], [0.25, -0.03], [0.6, 0.03]],
			"pupil_bias": [[0.0, v(0, 0)], [0.25, v(0.5, -0.4)], [0.6, v(0.5, 0.3)]],
		}},
		"work_hammer_out": {"length": 0.6, "loop": false, "mouth": "neutral", "tracks": {
			"prop_hammer_shown": [[0.0, true], [0.32, false]],
			"prop_hammer_rot": [[0.0, 3.14], [0.3, 0.0]],
			"arm_r": [[0.0, -1.1], [0.3, -2.9], [0.6, 0.0]],
			"body_rot": [[0.0, 0.03], [0.3, -0.03], [0.6, 0.0]],
			"pupil_bias": [[0.0, v(0.5, 0.3)], [0.3, v(0.5, -0.4)], [0.6, v(0, 0)]],
		}},
		"work_wrench_in": {"length": 0.6, "loop": false, "mouth": "neutral", "tracks": {
			"prop_wrench_shown": [[0.0, false], [0.26, true]],
			"arm_r": [[0.0, 0.0], [0.25, -2.9], [0.6, -0.45]],
			"body_rot": [[0.0, 0.0], [0.25, -0.03], [0.6, 0.04]],
			"pupil_bias": [[0.0, v(0, 0)], [0.25, v(0.5, -0.4)], [0.6, v(0.6, 0.0)]],
		}},
		"work_wrench_out": {"length": 0.6, "loop": false, "mouth": "neutral", "tracks": {
			"prop_wrench_shown": [[0.0, true], [0.32, false]],
			"arm_r": [[0.0, -0.45], [0.3, -2.9], [0.6, 0.0]],
			"body_rot": [[0.0, 0.04], [0.3, -0.03], [0.6, 0.0]],
			"pupil_bias": [[0.0, v(0.6, 0.0)], [0.3, v(0.5, -0.4)], [0.6, v(0, 0)]],
		}},
		# The laptop opens: the lid rises from its base.
		"work_laptop_in": {"length": 0.6, "loop": false, "mouth": "neutral", "tracks": {
			"arm_l_shown": [[0.0, false]],
			"arm_r_shown": [[0.0, false]],
			"arm_front_l_shown": [[0.0, true]],
			"arm_front_r_shown": [[0.0, true]],
			"prop_laptop_shown": [[0.0, true]],
			"prop_laptop_scale": [[0.0, v(1, 0.12)], [0.15, v(1, 0.12)], [0.5, v(1, 1)], [0.6, v(1, 1)]],
			"pupil_bias": [[0.0, v(0, 0.2)], [0.6, v(0, 0.55)]],
			"eye_scale": [[0.0, v(1, 1)], [0.6, v(1, 0.94)]],
		}},
		"work_laptop_out": {"length": 0.6, "loop": false, "mouth": "neutral", "tracks": {
			"arm_l_shown": [[0.0, false], [0.5, true]],
			"arm_r_shown": [[0.0, false], [0.5, true]],
			"arm_front_l_shown": [[0.0, true], [0.5, false]],
			"arm_front_r_shown": [[0.0, true], [0.5, false]],
			"prop_laptop_shown": [[0.0, true], [0.5, false]],
			"prop_laptop_scale": [[0.0, v(1, 1)], [0.4, v(1, 0.12)], [0.6, v(1, 0.12)]],
			"pupil_bias": [[0.0, v(0, 0.55)], [0.6, v(0, 0)]],
			"eye_scale": [[0.0, v(1, 0.94)], [0.6, v(1, 1)]],
		}},
		# The papers rise from the hands like the laptop lid: stack and page scale
		# up together from their bottom edge (pivots at the bottom).
		"work_papers_in": {"length": 0.6, "loop": false, "mouth": "neutral", "tracks": {
			# Exactly work_papers_out played backwards (the user's wish).
			"arm_l_shown": [[0.0, true], [0.1, false]],
			"arm_r_shown": [[0.0, true], [0.1, false]],
			"arm_front_l_shown": [[0.0, false], [0.1, true]],
			"arm_front_r_shown": [[0.0, false], [0.1, true]],
			"prop_papers_shown": [[0.0, false], [0.1, true]],
			"prop_page_shown": [[0.0, false], [0.1, true]],
			"prop_papers_scale": [[0.0, v(1, 0.1)], [0.2, v(1, 0.1)], [0.6, v(1, 1)]],
			"prop_page_scale": [[0.0, v(1, 0.1)], [0.2, v(1, 0.1)], [0.6, v(1, 1)]],
			"pupil_bias": [[0.0, v(0, 0)], [0.6, v(0.3, 0.45)]],
		}},
		"work_papers_out": {"length": 0.6, "loop": false, "mouth": "neutral", "tracks": {
			"arm_l_shown": [[0.0, false], [0.5, true]],
			"arm_r_shown": [[0.0, false], [0.5, true]],
			"arm_front_l_shown": [[0.0, true], [0.5, false]],
			"arm_front_r_shown": [[0.0, true], [0.5, false]],
			"prop_papers_shown": [[0.0, true], [0.5, false]],
			"prop_page_shown": [[0.0, true], [0.5, false]],
			"prop_papers_scale": [[0.0, v(1, 1)], [0.4, v(1, 0.1)], [0.6, v(1, 0.1)]],
			"prop_page_scale": [[0.0, v(1, 1)], [0.4, v(1, 0.1)], [0.6, v(1, 0.1)]],
			"pupil_bias": [[0.0, v(0.3, 0.45)], [0.6, v(0, 0)]],
		}},
		# work-and-wait D4: four ways of working, each with a prop.
		"work_hammer": {"length": 0.9, "loop": true, "mouth": "neutral", "tracks": {
			"prop_hammer_shown": [[0.0, true]],
			# The handle extends the forearm from the fist (gripped at its end), the
			# head across it: swing up over the shoulder, strike down at the side.
			"prop_hammer_rot": [[0.0, 3.14]],
			"arm_r": [[0.0, -1.1], [0.1, -1.05], [0.45, -2.5], [0.6, -2.6], [0.72, -1.0], [0.78, -1.1], [0.9, -1.1]],
			"arm_l": [[0.0, 0.05]],
			"root_pos": [[0.0, v(0, 0)], [0.68, v(0, 0)], [0.72, v(0, 0)], [0.76, v(0, 5)], [0.84, v(0, 0)], [0.9, v(0, 0)]],
			"body_scale": [[0.0, v(1, 1)], [0.68, v(1, 1)], [0.72, v(1, 1)], [0.76, v(1.04, 0.96)], [0.86, v(1, 1)],
				[0.9, v(1, 1)]],
			"body_rot": [[0.0, 0.03], [0.6, 0.05], [0.76, 0.02], [0.9, 0.03]],
			"eye_scale": [[0.0, v(1, 1)], [0.68, v(1, 1)], [0.72, v(1, 1)], [0.76, v(1.05, 0.85)], [0.86, v(1, 1)],
				[0.9, v(1, 1)]],
			"pupil_bias": [[0.0, v(0.5, 0.3)]],
		}},
		"work_laptop": {"length": 0.8, "loop": true, "mouth": "neutral", "tracks": {
			"arm_l_shown": [[0.0, false]],
			"arm_r_shown": [[0.0, false]],
			"arm_front_l_shown": [[0.0, true]],
			"arm_front_r_shown": [[0.0, true]],
			"prop_laptop_shown": [[0.0, true]],
			"arm_front_l_rot": [[0.0, 0.0], [0.1, -0.05], [0.2, 0.0], [0.4, 0.0], [0.5, -0.05], [0.6, 0.0], [0.8, 0.0]],
			"arm_front_r_rot": [[0.0, 0.0], [0.2, 0.0], [0.3, 0.05], [0.4, 0.0], [0.6, 0.0], [0.7, 0.05], [0.8, 0.0]],
			"root_pos": [[0.0, v(0, 0)], [0.4, v(0, 2)], [0.8, v(0, 0)]],
			"eye_scale": [[0.0, v(1, 0.94)]],
			"pupil_bias": [[0.0, v(0, 0.55)]],
		}},
		"work_wrench": {"length": 1.2, "loop": true, "mouth": "neutral", "tracks": {
			"prop_wrench_shown": [[0.0, true]],
			"arm_r": [[0.0, -0.45], [0.3, -0.8], [0.6, -0.45], [0.9, -0.8], [1.2, -0.45]],
			"arm_l": [[0.0, 0.05]],
			"body_rot": [[0.0, 0.04], [0.3, 0.08], [0.6, 0.04], [0.9, 0.08], [1.2, 0.04]],
			"root_pos": [[0.0, v(0, 0)], [0.3, v(0, 3)], [0.6, v(0, 0)], [0.9, v(0, 3)], [1.2, v(0, 0)]],
			"pupil_bias": [[0.0, v(0.6, 0.0)]],
		}},
		"work_papers": {"length": 2.0, "loop": true, "mouth": "neutral", "tracks": {
			"arm_l_shown": [[0.0, false]],
			"arm_r_shown": [[0.0, false]],
			"arm_front_l_shown": [[0.0, true]],
			"arm_front_r_shown": [[0.0, true]],
			"prop_papers_shown": [[0.0, true]],
			# The right page flips over to the left, then the next page is the same drawing.
			"prop_page_shown": [[0.0, true], [1.3, false], [1.5, true], [2.0, true]],
			"prop_page_scale": [[0.0, v(1, 1)], [0.6, v(1, 1)], [1.0, v(-1, 1)], [1.3, v(-1, 1)], [1.35, v(1, 1)],
				[2.0, v(1, 1)]],
			"arm_front_r_rot": [[0.0, 0.0], [0.6, 0.0], [0.8, 0.1], [1.0, 0.04], [1.2, 0.0], [2.0, 0.0]],
			"pupil_bias": [[0.0, v(0.3, 0.45)], [0.6, v(0.3, 0.45)], [1.0, v(-0.3, 0.45)], [1.5, v(-0.3, 0.45)],
				[2.0, v(0.3, 0.45)]],
			"body_rot": [[0.0, 0.0], [1.0, -0.02], [2.0, 0.0]],
		}},
	}


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var err := ResourceSaver.save(build_body_library(), OUT_DIR + "body_clips.tres")
	if err == OK:
		err = ResourceSaver.save(build_face_library(), OUT_DIR + "face_clips.tres")
	print("build_monster_clips: %s" % error_string(err))
	quit(0 if err == OK else 1)


static func build_body_library() -> AnimationLibrary:
	var lib := AnimationLibrary.new()
	lib.add_animation(&"RESET", _make_body_clip({"length": 0.001, "loop": false, "mouth": "neutral", "tracks": {}}))
	var clips := body_clips()
	for name: String in clips:
		lib.add_animation(StringName(name), _make_body_clip(clips[name]))
	return lib


static func build_face_library() -> AnimationLibrary:
	var lib := AnimationLibrary.new()
	var blink := Animation.new()
	blink.length = 0.18
	var vis := blink.add_track(Animation.TYPE_VALUE)
	blink.track_set_path(vis, "Skeleton2D/root/body/eye/Eyelid:visible")
	blink.value_track_set_update_mode(vis, Animation.UPDATE_DISCRETE)
	blink.track_insert_key(vis, 0.0, true)
	blink.track_insert_key(vis, 0.18, false)
	var sc := blink.add_track(Animation.TYPE_VALUE)
	blink.track_set_path(sc, "Skeleton2D/root/body/eye/Eyelid:scale")
	for key in [[0.0, v(1, 0.01)], [0.07, v(1, 1)], [0.1, v(1, 1)], [0.18, v(1, 0.01)]]:
		blink.track_insert_key(sc, key[0], key[1])
	lib.add_animation(&"blink", blink)
	return lib


static func _make_body_clip(data: Dictionary) -> Animation:
	var anim := Animation.new()
	anim.length = data.length
	anim.loop_mode = Animation.LOOP_LINEAR if data.loop else Animation.LOOP_NONE
	var tracks: Dictionary = data.tracks
	for key: String in BODY_TRACKS:
		var t := anim.add_track(Animation.TYPE_VALUE)
		anim.track_set_path(t, BODY_TRACKS[key][0])
		if key in DISCRETE_TRACKS:
			anim.value_track_set_update_mode(t, Animation.UPDATE_DISCRETE)
		elif key in LINEAR_TRACKS:
			anim.track_set_interpolation_type(t, Animation.INTERPOLATION_LINEAR)
		else:
			anim.track_set_interpolation_type(t, Animation.INTERPOLATION_CUBIC)
		anim.track_set_interpolation_loop_wrap(t, data.loop)
		var keys: Array = tracks.get(key, [[0.0, BODY_TRACKS[key][1]]])
		for k in keys:
			anim.track_insert_key(t, k[0], k[1])
	for mouth: String in MOUTHS:
		var t := anim.add_track(Animation.TYPE_VALUE)
		anim.track_set_path(t, MOUTHS[mouth])
		anim.value_track_set_update_mode(t, Animation.UPDATE_DISCRETE)
		anim.track_insert_key(t, 0.0, mouth == data.mouth)
	return anim
