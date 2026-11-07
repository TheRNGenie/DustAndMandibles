extends Node
## Host only: plans each wave when the build phase starts (so players can see
## what's coming), releases it pulse by pulse on the wave's own schedule (its
## shape: steady stream, one rush, two pushes...), and ends the wave when every
## bug is dead. Also tallies kills per (bug type, kill method) and unlocks
## kill-method variants once a type keeps dying the same way.

const KillMethod := preload("res://scenes/bugs/kill_method.gd")
const KillTally := preload("res://scenes/bugs/kill_tally.gd")

signal wave_announced(heavy_cliff: int, west_share: float, lane_counts: Array)
## The coming wave's bug mix ([[bug id, count], ...], most first), sent while building.
signal wave_previewed(mix: Array)
## Host and clients: a kill-method variant just showed up for the first time this run.
signal variant_unlocked(variant_id: StringName)

## The last preview, for HUDs that open after it was sent.
var preview: Array = []
## The coming wave's shape (WavePlanner.STEADY, RUSH, ...), sent with the preview.
var preview_shape: StringName = &""

var bug_manager: BugManager
var tally := KillTally.new()
var _planner: WavePlanner
var _plan: Dictionary = {}
var _pulse := 0
var _clock := 0.0
var _active := false
var _last_wave := 0
## Boss ids met this run, oldest first (BossRotation never repeats one early).
var boss_seen: Array = []
## Story: edits each planned wave (StoryDirector: the chapter's boss and extra bugs).
var plan_hook: Callable
## Canyon, this wave on: the deep tunnels' bugs trickle out a chunk every
## 2-3 seconds (WavePlanner.trickle_chunks) instead of coming with the pulses.
const TRICKLE_WAVE := 15
var _trickle: Array = []
var _trickle_at := 0.0


func _ready() -> void:
	var defs: Array[BugDef] = []
	for id: StringName in Defs.active_bug_ids():
		defs.append(Defs.bug(id))
	_planner = WavePlanner.new(Defs.WAVE_CONFIG, defs, int(Time.get_unix_time_from_system()))
	tally.threshold = Defs.WAVE_CONFIG.variant_kills
	# Testing: --variantkills=N makes variants show up after N kills.
	if GameState.flag_value("--variantkills") != "":
		tally.threshold = maxi(int(GameState.flag_value("--variantkills")), 1)
	GameState.phase_changed.connect(_on_phase_changed)


func _on_phase_changed(p: GameState.Phase) -> void:
	if not multiplayer.is_server():
		return
	match p:
		GameState.Phase.LOBBY:
			tally.reset()
			boss_seen.clear()
			_last_wave = 0
		GameState.Phase.BUILD:
			# A new run (wave count went back): forget last run's kills.
			if GameState.wave <= 1 or GameState.wave < _last_wave:
				tally.reset()
				boss_seen.clear()
			_last_wave = GameState.wave
			# Plan the coming wave now, so both players can see what's coming while they build.
			_plan = _make_plan()
			_preview.rpc(_mix(), _plan["shape"])
			_tell_next_boss()
		GameState.Phase.WARNING:
			if _plan.is_empty():
				_plan = _make_plan()
			_weather_bosses()
			var extra := Weather.extra_bugs(GameState.weather)
			if extra > 0.0:
				# Blood moon: fold part of a second wave's worth of bugs into this one
				# (never a second boss).
				var more: Array = (_make_plan()["groups"] as Array).filter(func(g: Dictionary) -> bool:
					return Defs.bug(StringName(g["bug"])).behavior != BugDef.Behavior.BOSS)
				var groups: Array = _plan["groups"]
				for i in int(more.size() * extra):
					var g: Dictionary = more[i]
					g["pulse"] = int(g["pulse"]) % int(_plan["pulses"])
					groups.append(g)
			# Maps: on bigger maps the share sent is the heaviest cliff's own.
			var shares: Array = _plan.get("shares", [])
			if shares.size() > 2:
				var hc := WavePlanner.heaviest(shares)
				_announce.rpc(hc, float(shares[maxi(hc, 0)]), _lane_counts())
			else:
				_announce.rpc(WavePlanner.heavier_cliff(float(_plan["west_share"])), float(_plan["west_share"]), _lane_counts())
		GameState.Phase.WAVE:
			if _plan.is_empty():
				_plan = _make_plan()
			_pulse = 0
			_clock = 0.0
			_active = true
			_trickle = []
			_queue = []
			overflow_hp = 1.0
			_feed_budget = 0.0
			_wave_total = 0
			for g: Dictionary in _plan["groups"]:
				_wave_total += int(g["count"])
			_feed_rate = _release_rate()
			if trickling():
				var times: Array = _plan["pulse_times"]
				var span := maxf(float(times[times.size() - 1]) + 10.0 if not times.is_empty() else 0.0, 30.0)
				_trickle = WavePlanner.trickle_chunks(_plan["groups"], span)
				_trickle_at = 0.0
			for id: StringName in _plan_bosses():
				boss_seen.append(id)
		_:
			_active = false
			_trickle = []
			_queue = []


## This wave's deep-tunnel bugs come as a trickle (canyon, wave 15 on).
func trickling() -> bool:
	return GameState.wave >= TRICKLE_WAVE and WorldLayout.map().is_canyon() and not GameState.tutorial


func _make_plan() -> Dictionary:
	# Tutorial: the first wave is a handful of slow Dust Mites (TutorialRun).
	if GameState.tutorial and GameState.wave <= 1:
		return TutorialRun.wave_plan()
	_planner.variants = tally.unlocked
	_planner.boss_seen = boss_seen
	_planner.cliff_count = WorldLayout.cliff_count() # Maps: this run's map
	_planner.weights = _live_weights()
	var plan := _planner.plan(GameState.wave)
	if plan_hook.is_valid():
		plan = plan_hook.call(plan)
	return plan


## The bosses in the current plan (ids, in group order).
func _plan_bosses() -> Array[StringName]:
	var out: Array[StringName] = []
	if _plan.is_empty():
		return out
	for g: Dictionary in _plan["groups"]:
		if Defs.bug(StringName(g["bug"])).behavior == BugDef.Behavior.BOSS:
			out.append(StringName(g["bug"]))
	return out


## Host, read by GameState's weather roll: is the Mirage Mantis due this wave?
func mantis_due() -> bool:
	return multiplayer.is_server() and _plan_bosses().has(BossRotation.MANTIS)


## Host, once the weather is known: the Mantis only hunts in dust storms (a
## stand-in takes her place otherwise), and a dust-storm boss wave brings her.
func _weather_bosses() -> void:
	var bosses := _plan_bosses()
	if bosses.is_empty():
		return
	# Story: a chapter that names its bosses keeps them whatever the weather.
	var ch := Story.chapter()
	if ch != null and not ch.bosses.is_empty():
		return
	var swapped := BossRotation.apply_weather(_planner._seed, GameState.wave, _planner.bug_defs, boss_seen, bosses,
			GameState.weather == Weather.Kind.DUST_STORM)
	if swapped == bosses:
		return
	var k := 0
	for g: Dictionary in _plan["groups"]:
		if Defs.bug(StringName(g["bug"])).behavior == BugDef.Behavior.BOSS and k < swapped.size():
			g["bug"] = swapped[k]
			k += 1
	_preview.rpc(_mix(), _plan["shape"])


func _process(delta: float) -> void:
	if not _active or not multiplayer.is_server() or bug_manager == null:
		return
	var times: Array = _plan["pulse_times"]
	_clock += delta
	while _pulse < times.size() and _clock >= float(times[_pulse]):
		_release(_pulse)
		_pulse += 1
	_feed()
	if GameState.has_flag("--mixlog"):
		_mix_log(delta)
	while not _trickle.is_empty() and _clock >= _trickle_at:
		var c: Array = _trickle.pop_front()
		bug_manager.spawn_group(c[0], int(c[1]), int(c[2]), int(c[3]), 0.0, 2)
		_trickle_at += randf_range(2.0, 3.0)
	if _pulse >= times.size() and _trickle.is_empty() and _queue.is_empty() and bug_manager.alive_count() == 0 and bug_manager.pending_count() == 0:
		_active = false
		_plan = {}
		GameState.end_wave()


## Host: chunks waiting to come out ([bug, count, cliff, lane, tier]), kinds
## interleaved (ReleaseQueue), fed out a few a frame while there's room.
var _queue: Array = []


var _mix_t := 0.0


## Debug (--mixlog): every 5 s of a wave, what's out (full bugs and floor walkers) by kind.
func _mix_log(delta: float) -> void:
	_mix_t += delta
	if _mix_t < 5.0:
		return
	_mix_t = 0.0
	var real := {}
	for c: Node in bug_manager.get_children():
		if c is Bug and (c as Bug).is_alive():
			real[(c as Bug).def.id] = int(real.get((c as Bug).def.id, 0)) + 1
	print("[mix] t %.0f  queued chunks %d  full %s  walkers %s" % [_clock, _queue.size(), str(real), str(bug_manager.swarm.kinds())])


## A wave past the field's cap (full bugs plus floor walkers) sends what fits,
## each this much tougher, so its threat still follows the curve.
var overflow_hp := 1.0
## Bugs come out of the tunnels at this many a second (the wave spread over
## RELEASE_SECONDS; a rush over RUSH_SECONDS), so they trickle in and up the
## wall instead of piling up at its foot.
const RELEASE_SECONDS := 50.0
const RUSH_SECONDS := 22.0
const RELEASE_MIN_RATE := 4.0
var _feed_rate := 1000.0
## Bugs the whole wave was planned with (all pulses).
var _wave_total := 0
var _feed_budget := 0.0


func _release_rate() -> float:
	if _plan.is_empty():
		return 1000.0
	var total := 0
	for g: Dictionary in _plan["groups"]:
		total += int(g["count"])
	total = mini(total, Defs.WAVE_CONFIG.max_wave_bugs)
	var spread := RUSH_SECONDS if _plan.get("shape", &"") == WavePlanner.RUSH else RELEASE_SECONDS
	return maxf(RELEASE_MIN_RATE, float(total) / spread)


func _feed() -> void:
	_feed_budget = minf(_feed_budget + _feed_rate * get_process_delta_time(), _feed_rate * 2.0 + 8.0)
	# Room on the field: as bugs die, more come out (up to the live cap).
	var room := Defs.WAVE_CONFIG.max_active_bugs - bug_manager.alive_count()
	# Fliers can't wait on the floor as walkers: cap their share of the full
	# bugs so they don't take every slot; their chunks wait at the back.
	var fliers := -1
	var n := 0
	var looked := 0
	while not _queue.is_empty() and n < ReleaseQueue.PER_TICK and room > 0 and looked < _queue.size():
		var c: Array = _queue.pop_front()
		if Defs.bug(c[0]).behavior == BugDef.Behavior.FLIER:
			if fliers < 0:
				fliers = _fliers_out()
			if fliers + int(c[1]) > roundi(Defs.WAVE_CONFIG.max_active_bugs * ReleaseQueue.FLIER_SHARE):
				_queue.append(c)
				looked += 1
				continue
			fliers += int(c[1])
		var boss := Defs.bug(c[0]).behavior == BugDef.Behavior.BOSS
		if not boss and _feed_budget < float(c[1]):
			_queue.push_front(c) # (the next chunk waits for its turn)
			break
		if not boss:
			_feed_budget -= float(c[1])
		bug_manager.spawn_group(c[0], int(c[1]), int(c[2]), int(c[3]), 0.0, int(c[4]))
		room -= int(c[1])
		n += 1


func _fliers_out() -> int:
	var f := 0
	for c: Node in bug_manager.get_children():
		var b := c as Bug
		if b != null and b.is_alive() and b.def.behavior == BugDef.Behavior.FLIER:
			f += 1
	return f


func _release(pulse: int) -> void:
	if GameState.has_flag("--netlog"):
		print("[wave] %s: releasing pulse %d of %d, %d groups planned" % [_plan["shape"], pulse, int(_plan["pulses"]), (_plan["groups"] as Array).size()])
	var trickle := trickling()
	var groups: Array = []
	var total := 0
	for g: Dictionary in _plan["groups"]:
		if int(g["pulse"]) == pulse:
			var tier := int(g.get("tier", 0))
			if trickle and tier == 2:
				continue # (out of the deep tunnels in the trickle instead)
			if GameState.has_flag("--netlog") and String(g["bug"]).contains("@"):
				print("[wave]   variant group: %d x %s" % [int(g["count"]), Defs.bug(StringName(g["bug"])).display_name])
			groups.append(g)
			total += int(g["count"])
	# More than one wave may send (max_wave_bugs, shared across its pulses): every
	# kind shrinks by the same share, and the overflow becomes toughness.
	var room := Defs.WAVE_CONFIG.max_wave_bugs * total / maxi(_wave_total, 1) if _wave_total > Defs.WAVE_CONFIG.max_wave_bugs else total
	var k := minf(1.0, float(room) / float(total)) if total > 0 else 1.0
	if k < 1.0 and k > 0.0:
		overflow_hp = maxf(overflow_hp, 1.0 / k)
		if GameState.has_flag("--netlog") or GameState.has_flag("--cpusim"):
			print("[wave] %d planned, %d fit: each bug x%.2f HP" % [total, room, overflow_hp])
	var chunks: Array = []
	for g: Dictionary in groups:
		var n := int(g["count"]) if Defs.bug(StringName(g["bug"])).behavior == BugDef.Behavior.BOSS else maxi(ceili(int(g["count"]) * k), 1)
		chunks.append(ReleaseQueue.chunks(StringName(g["bug"]), n, int(g["cliff"]), int(g["lane"]), int(g.get("tier", 0))))
	_queue.append_array(ReleaseQueue.interleave(chunks))


## Host: BugManager reports every kill; enough kills of one type the same way
## unlocks its variant for the coming waves.
func note_kill(def: BugDef, source: String) -> void:
	var v := tally.note(def, KillMethod.of(source))
	if v != &"":
		if GameState.has_flag("--netlog"):
			print("[wave] variant unlocked: %s (%d kills by %s)" % [v, tally.count(def.base_id(), KillMethod.of(source)), KillMethod.of(source)])
		_variant_unlocked.rpc(v)


## Maps: the map's spawn weights, minus any cliff nobody holds (a lobby that
## started short without CPU teammates). Solo play holds every cliff.
func _live_weights() -> Array[float]:
	var w := WorldLayout.map().spawn_weights()
	if GameState.is_solo() or not NetworkManager.is_online():
		return w
	var total := 0.0
	for cid in w.size():
		if not NetworkManager.cliff_held(cid):
			w[cid] = 0.0
		total += w[cid]
	if total <= 0.0:
		return WorldLayout.map().spawn_weights()
	for cid in w.size():
		w[cid] /= total
	return w


## Bugs per [cliff][lane], so the warning HUD can show the busiest lanes.
func _lane_counts() -> Array:
	var counts := []
	for cid in WorldLayout.cliff_count(): # Maps: one row per cliff
		counts.append([0, 0, 0, 0, 0])
	for g: Dictionary in _plan["groups"]:
		var row: Array = counts[int(g["cliff"])]
		row[int(g["lane"])] = int(row[int(g["lane"])]) + int(g["count"])
	return counts


## Bugs per type in the plan: kill-method variants first (so the HUD never hides
## them under "+N more"), then most numerous first.
func _mix() -> Array:
	return mix_of(_plan["groups"])


static func mix_of(groups: Array) -> Array:
	var by: Dictionary = {}
	for g: Dictionary in groups:
		by[String(g["bug"])] = int(by.get(String(g["bug"]), 0)) + int(g["count"])
	var out: Array = []
	for id: String in by:
		out.append([id, by[id]])
	out.sort_custom(func(a: Array, b: Array) -> bool:
		var va := String(a[0]).contains("@")
		var vb := String(b[0]).contains("@")
		if va != vb:
			return va
		return int(a[1]) > int(b[1]))
	return out


## Host: re-sends the preview to a player who just joined.
func send_preview_to(peer: int) -> void:
	if multiplayer.is_server() and not preview.is_empty():
		_preview.rpc_id(peer, preview, preview_shape)


## The boss the wave after this one brings (ids; empty unless it's a boss
## wave): shown on the wave card a build phase early, so you can build for it.
var next_boss: Array = []


## Host: works out next wave's boss the way the planner will (BossRotation,
## same seed; the Mirage Mantis can still swap with the weather).
func _tell_next_boss() -> void:
	var w := GameState.wave + 1
	var cfg := Defs.WAVE_CONFIG
	var out: Array = []
	if cfg.boss_every > 0 and w % cfg.boss_every == 0 and not GameState.tutorial:
		var seen: Array = boss_seen.duplicate()
		seen.append_array(_plan_bosses())
		for id: StringName in BossRotation.pick(_planner._seed, w, _planner.bug_defs, seen, cfg.boss_every, cfg.last_wave):
			out.append(id)
	_next_boss.rpc(out)


@rpc("authority", "call_local", "reliable")
func _next_boss(ids: Array) -> void:
	next_boss = ids
	wave_previewed.emit(preview)


@rpc("authority", "call_local", "reliable")
func _preview(mix: Array, shape: StringName) -> void:
	preview = mix
	preview_shape = shape
	wave_previewed.emit(mix)


@rpc("authority", "call_local", "reliable")
func _announce(heavy_cliff: int, west_share: float, lane_counts: Array) -> void:
	wave_announced.emit(heavy_cliff, west_share, lane_counts)


@rpc("authority", "call_local", "reliable")
func _variant_unlocked(variant_id: StringName) -> void:
	variant_unlocked.emit(variant_id)
	var d := Defs.bug(variant_id)
	if d == null or bug_manager == null:
		return
	var base := Defs.bug(d.variant_of)
	var method := String(variant_id).get_slice("@", 1)
	# One line in the kill feed (every peer adds its own copy).
	bug_manager.bug_killed.emit("The %ss are adapting to %s: %ss are coming. %s" % [
			base.display_name, KillMethod.WORDS.get(StringName(method), method), d.display_name, d.counter], -1, "", -2, {})
