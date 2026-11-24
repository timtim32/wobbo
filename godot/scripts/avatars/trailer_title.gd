extends Node2D
## The trailer's last shot (TrailerMode): the word "Wobbo" whose two o's are
## buddy eyes. The word rises, the eyes open and look around, a green buddy
## peeks up from the bottom edge, and the eyes and the buddy look at each other.
## Sizes follow the strip's width, like the sketch it was made from.

const MonsterScene := preload("res://characters/monster/monster.tscn")
const FONT_PATH := "res://assets/fonts/Baloo2-Variable.ttf"
const TAGLINE := "A Wobbo for every Claude Code session"

## How long the shot lasts, in seconds.
const DURATION_SEC := 6.5

const LEAF := Color("#2e5a27")
const SKIN := Color("#6db045")
const SKIN_SHADE := Color("#5a9638")
const CREAM := Color("#faf9ef")
const PUPIL := Color("#262626")
const TAG := Color("#5c5a4c")

var size := Vector2.ZERO
var _word_font: Font
var _tag_font: Font
var _time := 0.0
var _buddy: Monster
var _buddy_rest_y := 0.0
var _buddy_hidden_y := 0.0
var _pupil := [Vector2.ZERO, Vector2.ZERO] # per eye, -1..1
var _eyes: Array[Vector2] = [] # eye centres, local
var _eye_r := 0.0


func _ready() -> void:
	z_as_relative = false
	z_index = RenderingServer.CANVAS_ITEM_Z_MIN + 2
	var base: Font = load(FONT_PATH)
	_word_font = _weight(base, 800)
	_tag_font = _weight(base, 600)
	_buddy = MonsterScene.instantiate()
	_buddy.height_pt = 1.0 # set in _layout()
	add_child(_buddy)
	_layout()


static func _weight(base: Font, wght: int) -> Font:
	var f := FontVariation.new()
	f.base_font = base
	f.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): wght}
	return f


func _layout() -> void:
	var w := size.x
	_eye_r = 0.26 * _word_size()
	var px_per_pt := Overlay.walkway.px_per_pt if not Overlay.walkway.is_empty() else 1.0
	_buddy.height_pt = 0.085 * w / px_per_pt
	_buddy.position.x = w * 0.5
	_buddy_rest_y = size.y + 0.026 * w # head and eye above the bottom edge
	_buddy_hidden_y = size.y + 0.1 * w
	_buddy.position.y = _buddy_hidden_y


func _word_size() -> int:
	return roundi(0.125 * size.x)


func _process(delta: float) -> void:
	_time += delta
	# The buddy peeks up from 1.0 s, with a little overshoot.
	var peek := _ease_back(clampf((_time - 1.0) / 0.9, 0.0, 1.0))
	_buddy.position.y = lerpf(_buddy_hidden_y, _buddy_rest_y, peek)
	# The word's eyes: look left, then right, then down at the buddy.
	var buddy_eye := _buddy.position + Vector2(0, -0.6 * _buddy.get_local_bounds().size.y)
	for i in _eyes.size():
		var goal := Vector2.ZERO
		if _time >= 2.4:
			goal = (buddy_eye - _eyes[i]).normalized()
		elif _time >= 1.75:
			goal = Vector2(0.9, 0.15)
		elif _time >= 1.0:
			goal = Vector2(-0.9, 0.15)
		_pupil[i] = _pupil[i].lerp(goal, 1.0 - exp(-9.0 * delta))
	if _eyes.size() > 0 and _time >= 2.0:
		_buddy.look_at_point(to_global(_eyes[0].lerp(_eyes[1], 0.5)))
	queue_redraw()


func _draw() -> void:
	var fs := _word_size()
	var em := float(fs)
	var gap := 0.025 * em
	var eye_d := 2.0 * _eye_r
	var w_w := _word_font.get_string_size("W", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var bb_w := _word_font.get_string_size("bb", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var total := w_w + bb_w + 2.0 * (eye_d + 2.0 * gap)
	# Rises 4% of the width into place over 0.8 s, fading in.
	var rise := _ease_back(clampf(_time / 0.8, 0.0, 1.0))
	var alpha := clampf(_time / 0.5, 0.0, 1.0)
	var baseline := size.y * 0.09 + _word_font.get_ascent(fs) * 0.92 + (1.0 - rise) * 0.04 * size.x
	var x := (size.x - total) / 2.0
	var ink := Color(LEAF, alpha)
	draw_string(_word_font, Vector2(x, baseline), "W", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ink)
	x += w_w + gap
	var centres: Array[Vector2] = []
	centres.append(Vector2(x + _eye_r, baseline + 0.02 * em - _eye_r))
	x += eye_d + gap
	draw_string(_word_font, Vector2(x, baseline), "bb", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ink)
	x += bb_w + gap
	centres.append(Vector2(x + _eye_r, baseline + 0.02 * em - _eye_r))
	_eyes = centres
	for i in centres.size():
		_draw_eye(centres[i], _pupil[i], alpha)
	var tag_alpha := clampf((_time - 1.2) / 0.6, 0.0, 1.0)
	if tag_alpha > 0.0:
		var ts := roundi(0.014 * size.x)
		var tw := _tag_font.get_string_size(TAGLINE, HORIZONTAL_ALIGNMENT_LEFT, -1, ts).x
		draw_string(_tag_font, Vector2(size.x * 0.97 - tw, size.y * 0.93), TAGLINE, HORIZONTAL_ALIGNMENT_LEFT, -1, ts,
			Color(TAG, tag_alpha))


## A buddy eye in place of an o: green ring, cream white, pupil with a glint.
func _draw_eye(c: Vector2, look: Vector2, alpha: float) -> void:
	var r := _eye_r
	draw_circle(c, r, Color(SKIN_SHADE, alpha))
	draw_circle(c - Vector2(0, 0.04 * r), r * 0.96, Color(SKIN, alpha))
	var inner := r * 0.72
	var open := _open_amount()
	draw_set_transform(c, 0.0, Vector2(1.0, open))
	draw_circle(Vector2.ZERO, inner, Color(CREAM, alpha))
	var pr := inner * 0.54
	var p := look * (inner - pr) * 0.85
	draw_circle(p, pr, Color(PUPIL, alpha))
	draw_circle(p + Vector2(-0.3, -0.32) * pr, pr * 0.3, Color(CREAM, alpha))
	draw_set_transform(Vector2.ZERO)


## The eyes open at 0.3 s and blink at 3.3 s and 5.4 s.
func _open_amount() -> float:
	var t := _time
	var open := clampf((t - 0.3) / 0.3, 0.05, 1.0)
	for blink in [3.3, 5.4]:
		var d := absf(t - blink)
		if d < 0.09:
			open = minf(open, 0.08 + d / 0.09 * 0.92)
	return open


static func _ease_back(t: float) -> float:
	var c := 1.4
	return 1.0 + (c + 1.0) * pow(t - 1.0, 3.0) + c * pow(t - 1.0, 2.0)
