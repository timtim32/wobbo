extends RefCounted
## Who is on screen, where and in which colour (session-avatars design D1, D2,
## D6). Pure: sessions and avatars come in as plain data, actions come out.
##
## sessions: [{id, name, state, updated_msec, away}] (ended sessions included
##           until the registry drops them; away: sent home, send-home D1)
## avatars:  [{id, slot, hue, leaving}] (everything still drawn, leaving included)
## actions:  {kind: "enter", id, slot, hue} or {kind: "leave", id, wave}

const Protocol := preload("res://scripts/bridge/protocol.gd")

const MAX_AVATARS := 5
const HYSTERESIS_MS := 2000
const SLOT_MARGIN_PT := 16.0
## Curated skin hues (session-avatars D6, spike S2): readable, clearly different.
const HUES: Array[float] = [97.6, 205.0, 265.0, 330.0, 180.0, 355.0, 235.0, 25.0]
## Names of HUES, in the same order, for the Colour menu (pick-wobbo-colour D5).
const HUE_NAMES: PackedStringArray = ["Green", "Blue", "Purple", "Pink", "Teal", "Red", "Indigo", "Orange"]
## Wobbo's own buddy (the welcome, standalone-app D10) always wears the
## original green, even when a session already has it.
const OWN_HUE := 97.6
const OWN_PREFIX := "wobbo:"

## States that mean the session is being used (send-home D2).
const IN_USE := [Protocol.STATE_THINKING, Protocol.STATE_WORKING, Protocol.STATE_WAITING]


## How many slots fit on a segment of `width_pt` for bodies `body_width_pt` wide.
static func slot_count(width_pt: float, body_width_pt: float) -> int:
	return clampi(int(floor(width_pt / (body_width_pt + SLOT_MARGIN_PT))), 1, MAX_AVATARS)


## Slot indices from the edges inwards, left first (edges-first-slots D1):
## 5 -> [0, 4, 1, 3, 2]; the middle slot fills last.
static func slot_order(count: int) -> Array[int]:
	var order: Array[int] = []
	var lo := 0
	var hi := count - 1
	while lo <= hi:
		order.append(lo)
		if hi != lo:
			order.append(hi)
		lo += 1
		hi -= 1
	return order


## Walkway x of a slot's centre on a segment.
static func slot_center(seg_start: float, seg_width: float, count: int, slot: int) -> float:
	return seg_start + seg_width * (slot + 0.5) / count


## The slot whose centre is nearest to walkway x on a segment (buddy-drag D5).
static func drop_slot(x: float, seg_start: float, seg_width: float, count: int) -> int:
	return clampi(int(floor((x - seg_start) / seg_width * count)), 0, count - 1)


## Half the room a body may stroll around its slot centre.
static func stroll_range(seg_width: float, count: int, half_body: float) -> float:
	return maxf(0.0, seg_width / count * 0.5 - half_body - SLOT_MARGIN_PT * 0.5)


## Preferred hue for a display name, avoiding hues in `taken`.
static func pick_hue(name: String, taken: Array) -> float:
	var start := absi(name.hash()) % HUES.size()
	for k in HUES.size():
		var h: float = HUES[(start + k) % HUES.size()]
		if not h in taken:
			return h
	return HUES[start]


## Ranking: waiting for the user first, then most recently active.
static func _ranks_above(a: Dictionary, b: Dictionary) -> bool:
	var aw: bool = a.state == Protocol.STATE_WAITING
	var bw: bool = b.state == Protocol.STATE_WAITING
	if aw != bw:
		return aw
	return int(a.updated_msec) > int(b.updated_msec)


## True when `newcomer` may push out the avatar of session `victim`.
static func _displaces(newcomer: Dictionary, victim: Dictionary) -> bool:
	if victim.state == Protocol.STATE_WAITING:
		return false
	if newcomer.state == Protocol.STATE_WAITING:
		return true
	return int(newcomer.updated_msec) - int(victim.updated_msec) >= HYSTERESIS_MS


## `chosen`: hues the user chose per session name (pick-wobbo-colour D3).
static func plan(sessions: Array, avatars: Array, slots: int, chosen := {}) -> Array[Dictionary]:
	var actions: Array[Dictionary] = []
	var by_id := {}
	for s in sessions:
		by_id[s.id] = s
	var shown := {} # session id -> avatar, not leaving
	var used_slots := {}
	var taken_hues := []
	var leaving := 0
	for a in avatars:
		used_slots[int(a.slot)] = true
		taken_hues.append(float(a.hue))
		if a.leaving:
			leaving += 1
			continue
		var s = by_id.get(a.id)
		if s == null:
			actions.append({"kind": "leave", "id": a.id, "wave": false})
			leaving += 1
		elif s.state == Protocol.STATE_ENDED:
			actions.append({"kind": "leave", "id": a.id, "wave": true})
			leaving += 1
		elif s.get("away", false):
			actions.append({"kind": "leave", "id": a.id, "wave": false}) # sent home (send-home D1)
			leaving += 1
		elif int(a.slot) >= slots:
			actions.append({"kind": "leave", "id": a.id, "wave": false}) # display got narrower
			leaving += 1
		else:
			shown[a.id] = a
	# Too many shown for the slots (narrower display): the lowest ranked go.
	var shown_sessions: Array = shown.keys().map(func(id): return by_id[id])
	shown_sessions.sort_custom(_ranks_above)
	while shown_sessions.size() > slots:
		var gone = shown_sessions.pop_back()
		actions.append({"kind": "leave", "id": gone.id, "wave": false})
		shown.erase(gone.id)
		leaving += 1
	# Newcomers: live sessions without an avatar, best first.
	var live: Array = sessions.filter(func(s): return s.state != Protocol.STATE_ENDED and not s.get("away", false))
	live.sort_custom(_ranks_above)
	var newcomers: Array = live.slice(0, slots).filter(func(s): return not _has_avatar(avatars, s.id))
	var free: Array[int] = []
	for s in slot_order(slots):
		if not used_slots.has(s):
			free.append(s)
	var pending := leaving # slots that free up once a leaving avatar is gone
	for n in newcomers:
		if not free.is_empty():
			var slot: int = free.pop_front()
			var hue := hue_for(n, taken_hues + chosen_hues(live, chosen), chosen)
			taken_hues.append(hue)
			actions.append({"kind": "enter", "id": n.id, "slot": slot, "hue": hue})
		elif pending > 0:
			pending -= 1 # waits for a slot that is about to free up
		else:
			shown_sessions.sort_custom(_ranks_above)
			var victim = shown_sessions.back() if not shown_sessions.is_empty() else null
			if victim != null and _displaces(n, victim):
				actions.append({"kind": "leave", "id": victim.id, "wave": false})
				shown_sessions.pop_back()
	return actions


## The hue a newcomer gets: green for Wobbo's own buddy, the folder's chosen
## hue (even when taken), or else one picked from its name avoiding `avoid`.
static func hue_for(session: Dictionary, avoid: Array, chosen: Dictionary) -> float:
	if String(session.id).begins_with(OWN_PREFIX):
		return OWN_HUE
	var name := String(session.name)
	if chosen.has(name):
		return float(chosen[name])
	return pick_hue(name, avoid)


## Hues chosen for the folders of `sessions`.
static func chosen_hues(sessions: Array, chosen: Dictionary) -> Array:
	var out := []
	for s in sessions:
		if chosen.has(String(s.name)) and not String(s.id).begins_with(OWN_PREFIX):
			out.append(float(chosen[String(s.name)]))
	return out


## New hues after the user chose `hue` for folder `name` (negative: back to
## automatic). `chosen` holds the choices already including this one. Returns
## [{id, hue}] for every avatar that changes: all of the folder's avatars, and
## an avatar of another folder without a choice that wore the new hue takes the
## old one (pick-wobbo-colour D3). Leaving avatars are left alone.
static func recolour(avatars: Array, sessions: Array, name: String, hue: float, chosen: Dictionary) -> Array[Dictionary]:
	var names := {}
	for s in sessions:
		names[s.id] = String(s.name)
	var targets := []
	var others := []
	for a in avatars:
		if a.leaving or String(a.id).begins_with(OWN_PREFIX):
			continue
		if names.get(a.id, "") == name:
			targets.append(a)
		else:
			others.append(a)
	var out: Array[Dictionary] = []
	if targets.is_empty():
		return out
	var old: float = float(targets[0].hue)
	var new_hue := hue
	if new_hue < 0.0:
		var avoid := others.map(func(a): return float(a.hue))
		var live := sessions.filter(func(s): return String(s.name) != name)
		new_hue = pick_hue(name, avoid + chosen_hues(live, chosen))
	for a in targets:
		if float(a.hue) != new_hue:
			out.append({"id": a.id, "hue": new_hue})
	if old != new_hue:
		for a in others:
			if float(a.hue) == new_hue and not chosen.has(names.get(a.id, "")):
				out.append({"id": a.id, "hue": old})
	return out


static func _has_avatar(avatars: Array, id: String) -> bool:
	for a in avatars:
		if a.id == id:
			return true
	return false


## What an away session looked like when it was sent home (send-home D2).
static func away_mark(session) -> Dictionary:
	return {"last_ts": int(session.last_ts), "pending": Array(session.pending).duplicate()}


## True when an away session is used again: a new state event into thinking,
## working or waiting, or a new request. Notifications never set last_ts.
static func comes_back(mark: Dictionary, session) -> bool:
	if int(session.last_ts) > int(mark.last_ts) and session.state in IN_USE:
		return true
	for id in session.pending:
		if not id in mark.pending:
			return true
	return false
