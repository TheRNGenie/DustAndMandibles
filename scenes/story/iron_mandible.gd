class_name IronMandible
extends Node
## Story chapter 10, The Reckoning: the set piece (StoryDirector makes one for a
## "reckoning" chapter; same path on every peer, the host decides and RPCs).
## Rules in ReckoningRules, meshes in TrainMeshes, the boss in hive_mother.gd.
##
## The train night (the chapter's first wave): the Iron Mandible, the board's
## armoured harvest train, rolls in from far down the canyon on its own rails
## in the build phase and waits for dark with its nose at the play area's end.
## When the wave starts its amber furnace is stoked (iron shutters off the
## firebox doors, an amber glow, smoke from the stack) and it crawls up the
## canyon floor toward the main tunnel's rubble; while the furnace burns every
## bug within ReckoningRules.FRENZY_RADIUS of it moves a third faster. The
## thirty-degree law keeps every turret off it: it's a rifleman's job, from the
## rim or down on the floor (shots on the open doors count double). When it
## blows: a fireball, the furnace car burst open, the train stopped dead and
## off its rails at the back, and the swarm turns on it (bugs pour out of the
## nearest tunnel and over Vane's car). Vane climbs out and begs over the wire
## for covering fire nobody can lawfully give, and the wire goes dead.
##
## The boss night (the last wave): a few seconds into its build phase Vane's
## charges go off on their timer (the second blast): the main tunnel's rubble
## is blown away, the lower hive is open and the Hive Mother comes out of it
## (BugManager.boss_tunnel). Her health falling past a half and a quarter are
## Silas's beats (he rides down; he sets his charge); at a tenth she's PINNED
## on the wall (can't move, can't be hurt) while his fuse burns, then his
## charge seals the gallery and kills her: the players' near-kill and his
## blast land together (if they kill her outright first, the blast goes off as
## she dies). Done when the furnace is out and the gallery's sealed.
##
## Debug (--debug): --ch10view=train | furnace | wreck | tunnel | lip | mother
## puts you somewhere to look; --ch10blow=S blows the furnace S s in;
## --ch10go=S starts the wave S s into a build phase; --ch10seal starts the
## Hive Mother at 12% (Silas's charge at once); --ch10fast rolls the train 8x;
## --story=10 --storywave=25 jumps to the Hive Mother (the train's a wreck).

const CANYON_CONSIST: Array[String] = ["loco", "tender", "charges", "furnace", "private"]
const RING_CONSIST: Array[String] = ["loco", "charges", "furnace"]

var director: StoryDirector
var world: Node3D
var cliffs: CliffBuilder

var route := PackedVector3Array()
var route_len := 0.0
var hold_s := 0.0
var stop_s := 0.0
var consist: Array[String] = []
var offsets: Array[float] = []
var cars: Array[Car] = []
var furnace: Furnace
var main := 0
var mouth := Vector3.ZERO
var out := Vector3.BACK

## Synced state.
var s := 0.0
var crawling := false
var lit := false
var hp := 1.0
var hp_max := 1.0
var blown := false
var second := false
var sealed := false

# Host.
var _sync_t := 0.0
var _mother: Bug
var _mother_frac := 1.0
var _seal_started := false
var _look_t := 0.0
var _have_state := false
var _ask_t := 0.0
var _speed_k := 1.0
var _smoke: Array = [] # [mesh, age]
var _smoke_t := 0.0
var _smoke_mat: StandardMaterial3D
var _fire: OmniLight3D


## The train's route for this map (every peer: the same floor gives the same rails).
static func route_for(cl: CliffBuilder) -> PackedVector3Array:
	var m := cl.main_tunnel()
	var tn := cl.tunnel(m)
	var mouth_at: Vector3 = tn[0]
	var fy := func(x: float, z: float) -> float: return cl.floor_height(x, z)
	if cl.map.is_canyon():
		# Up the canyon from far past the play area's end, stopping with the charge
		# car alongside the main tunnel's mouth.
		var sgn := -1.0 if mouth_at.z < 0.0 else 1.0
		var stop_z := mouth_at.z + sgn * (_nose_to("charges", CANYON_CONSIST) - ReckoningRules.STOP_PAST_MOUTH)
		stop_z = clampf(stop_z, -WorldLayout.WORLD_HALF_Z + 4.0, WorldLayout.WORLD_HALF_Z - 4.0)
		var cx := func(z: float) -> float: return cl.center_x(z)
		return ReckoningRules.line_route(-sgn * ReckoningRules.CANYON_START_Z, stop_z, 2.0, cx, fy)
	# A ring map: round the basin, ending beside the main tunnel.
	var c := cl.map.center
	var a_end := atan2(mouth_at.z - c.z, mouth_at.x - c.x)
	var r := cl.map.ring_radius * 0.42
	return ReckoningRules.arc_route(c, r, a_end, PI * 1.25, 1.5, fy)


## Metres from the nose back to the middle of car `kind` in `cars`.
static func _nose_to(kind: String, cars_list: Array[String]) -> float:
	var d := 0.0
	for k in cars_list:
		var l := float(TrainMeshes.LENGTHS[k])
		if k == kind:
			return d + l * 0.5
		d += l + TrainMeshes.GAP
	return d


func _ready() -> void:
	cliffs = world.get("cliffs") as CliffBuilder
	main = cliffs.main_tunnel()
	var tn := cliffs.tunnel(main)
	mouth = tn[0]
	mouth.y = cliffs.floor_height(mouth.x, mouth.z)
	out = tn[1]
	out.y = 0.0
	out = out.normalized()
	route = route_for(cliffs)
	route_len = ReckoningRules.length_of(route)
	stop_s = route_len
	consist = CANYON_CONSIST if cliffs.map.is_canyon() else RING_CONSIST
	var d := 0.0
	for k in consist:
		var l := float(TrainMeshes.LENGTHS[k])
		offsets.append(d + l * 0.5)
		d += l + TrainMeshes.GAP
	if cliffs.map.is_canyon():
		var sgn := signf(route[route.size() - 1].z - route[0].z)
		hold_s = ReckoningRules.s_nearest(route, Vector3(0, 0, -sgn * ReckoningRules.CANYON_HOLD_Z))
	else:
		hold_s = route_len * 0.35
	s = minf(d + 2.0, hold_s)
	var riders := maxi(NetworkManager.players.size(), 1)
	hp_max = ReckoningRules.furnace_hp(riders)
	hp = hp_max
	if GameState.debug_enabled() and GameState.has_flag("--ch10fast"):
		_speed_k = 8.0
	# The rails, from the far end to the stop.
	var track := MeshInstance3D.new()
	track.name = "MandibleRails"
	track.mesh = TrainMeshes.track(route, 0.0, route_len)
	track.material_override = Materials.toon(0.0)
	world.add_child(track)
	for i in consist.size():
		var c := Car.new()
		c.name = "MandibleCar%d" % i
		c.kind = consist[i]
		world.add_child(c)
		cars.append(c)
		if c.kind == "furnace":
			furnace = Furnace.new()
			furnace.name = "Furnace"
			furnace.director = self
			c.add_child(furnace)
	_smoke_mat = StandardMaterial3D.new()
	_smoke_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_smoke_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_smoke_mat.albedo_color = Color(0.16, 0.13, 0.12, 0.55)
	_smoke_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	GameState.phase_changed.connect(_on_phase)
	if multiplayer.is_server():
		_have_state = true
		# Debug: --storywave on the boss night: the train is already a wreck at its stop.
		if director.start_wave() >= director.chapter.last_wave:
			s = stop_s
			crawling = true
			blown = true
			director._said["ch10_vane"] = true
		NetworkManager.players_changed.connect(_broadcast)
		_apply_state(_state())
	_place_cars()
	if blown:
		_wreck_look()
	print("[ch10] route %.0f m (hold %.0f, stop %.0f), main tunnel %d at %s, furnace %.0f hp" % [route_len, hold_s, stop_s, main, str(mouth.snapped(Vector3.ONE * 0.1)), hp_max])
	_debug.call_deferred()


func _exit_tree() -> void:
	Bug.frenzy_lit = false
	BugManager.boss_tunnel = -1
	if GameState.phase_changed.is_connected(_on_phase):
		GameState.phase_changed.disconnect(_on_phase)
	if NetworkManager.players_changed.is_connected(_broadcast):
		NetworkManager.players_changed.disconnect(_broadcast)


# ------------------------------------------------------------------ state

func done() -> bool:
	return blown and sealed


func _state() -> Dictionary:
	return {"s": s, "crawling": crawling, "lit": lit, "hp": hp, "hp_max": hp_max, "blown": blown, "second": second, "sealed": sealed}


func _broadcast() -> void:
	if multiplayer.is_server():
		_apply_state(_state())
		if not multiplayer.get_peers().is_empty():
			_sync.rpc(_state())


@rpc("any_peer", "reliable")
func _want_state() -> void:
	if multiplayer.is_server():
		_sync.rpc_id(multiplayer.get_remote_sender_id(), _state())


@rpc("authority", "call_remote", "reliable")
func _sync(state: Dictionary) -> void:
	_have_state = true
	_apply_state(state)


func _apply_state(state: Dictionary) -> void:
	var ns := float(state.get("s", s))
	if absf(ns - s) > 2.5 or multiplayer.is_server():
		s = ns
	crawling = bool(state.get("crawling", false))
	lit = bool(state.get("lit", false))
	hp = float(state.get("hp", hp))
	hp_max = float(state.get("hp_max", hp_max))
	var was_blown := blown
	blown = bool(state.get("blown", false))
	second = bool(state.get("second", false))
	sealed = bool(state.get("sealed", false))
	if blown and not was_blown:
		_wreck_look()
	if furnace != null:
		furnace.show_lit(lit and not blown)
	Bug.frenzy_lit = lit and not blown
	if director != null and director.tracker != null:
		director.tracker.refresh()


# ------------------------------------------------------------------ the tick

func _process(delta: float) -> void:
	if not multiplayer.is_server() and not _have_state:
		_ask_t -= delta
		if _ask_t <= 0.0:
			_ask_t = 1.5
			_want_state.rpc_id(1)
	if not blown:
		s = ReckoningRules.advance(s, delta * _speed_k, crawling, hold_s, stop_s)
	_place_cars()
	if furnace != null:
		Bug.frenzy_at = furnace.global_position
	_smoke_tick(delta)
	if not multiplayer.is_server():
		return
	_sync_t -= delta
	if _sync_t <= 0.0:
		_sync_t = 3.0
		_broadcast()
	_host_mother(delta)


func _place_cars() -> void:
	for i in cars.size():
		var c := cars[i]
		if not is_instance_valid(c):
			continue
		var at := s - offsets[i]
		var p := ReckoningRules.point_at(route, at)
		var d := ReckoningRules.dir_at(route, at)
		var b := Basis(Vector3.UP, atan2(d.x, d.z))
		if blown:
			# Off the rails at the back: the furnace car slewed, Vane's car on its side-ish.
			match c.kind:
				"furnace":
					b = b * Basis(Vector3.BACK, 0.12) * Basis(Vector3.UP, 0.08)
				"private":
					b = b * Basis(Vector3.UP, 0.32) * Basis(Vector3.BACK, -0.38)
					p += b.x * 1.2
		c.global_transform = Transform3D(b, p)


func _on_phase(p: GameState.Phase) -> void:
	if not multiplayer.is_server():
		return
	var w := GameState.wave
	match p:
		GameState.Phase.BUILD:
			if w == director.chapter.first_wave and not crawling:
				get_tree().create_timer(5.0).timeout.connect(func() -> void: _say_once("train"))
			if w >= director.chapter.last_wave and not second:
				get_tree().create_timer(ReckoningRules.SECOND_BLAST_AFTER).timeout.connect(_second_blast)
			if GameState.debug_enabled() and GameState.flag_value("--ch10go") != "" and not GameState.story_hold:
				get_tree().create_timer(GameState.flag_value("--ch10go").to_float()).timeout.connect(func() -> void:
					if GameState.phase == GameState.Phase.BUILD:
						GameState.debug_skip())
		GameState.Phase.WAVE:
			if not crawling:
				crawling = true
			if not blown and not lit:
				lit = true
				_broadcast()
			if w >= director.chapter.last_wave:
				if not second:
					_second_blast() # (a debug skip straight into the wave)
				get_tree().create_timer(28.0).timeout.connect(func() -> void: _say_once("ezra"))
			_broadcast()


func _say_once(key: String) -> void:
	if director.finished or director._said.has("ch10_" + key):
		return
	director._said["ch10_" + key] = true
	director._event.rpc(key)


# ------------------------------------------------------------------ the furnace

## Host (Furnace.apply_hit): a shot into the furnace.
func furnace_hit(dmg: float, at: Vector3, source: String) -> void:
	if blown or director.finished:
		return
	if not lit:
		return # the shutters are bolted down: nothing gets in
	var mult := 1.0
	for dp in TrainMeshes.DOORS:
		if furnace.to_global(dp).distance_to(at) < 0.9:
			mult = ReckoningRules.DOOR_MULT
	var before := hp
	hp = maxf(hp - dmg * mult, 0.0)
	_say_once("furnace_hit")
	if before > hp_max * 0.5 and hp <= hp_max * 0.5:
		_say_once("furnace_half")
	if hp <= 0.0:
		_blow_furnace(source)
	elif _sync_t > 0.4:
		_sync_t = 0.4 # the tracker's furnace number follows the shots


func _blow_furnace(source: String) -> void:
	blown = true
	lit = false
	print("[ch10] furnace blown by %s at s %.1f" % [source, s])
	for cid in WorldLayout.cliff_count():
		Economy.notify_cliff(cid, "%s blew the Iron Mandible's amber furnace!" % (source if source != "" else "Someone"))
	_blow_fx.rpc()
	_broadcast()
	_say_once("furnace_down")
	get_tree().create_timer(3.0).timeout.connect(_wreck_swarm)
	get_tree().create_timer(7.0).timeout.connect(func() -> void: _say_once("vane"))
	get_tree().create_timer(40.0).timeout.connect(func() -> void: _say_once("crane"))
	if director.holding and done():
		director.piece_done(director.radio_left() + 3.0)


@rpc("authority", "call_local", "reliable")
func _blow_fx() -> void:
	blown = true
	if furnace == null:
		return
	var at := furnace.global_position + Vector3.UP * 3.0
	var side := furnace.global_transform.basis.x
	BlastFx.play(world, at - Vector3.UP * 2.5, side)
	BlastFx.play(world, at - Vector3.UP * 2.5, -side)
	Audio.play_at(&"dynamite", at, 8.0, 0.6)
	Audio.play_at(&"thunder", at, 4.0, 0.8)
	var p := world.call("local_player") as Player
	if p != null:
		p.add_shake(clampf(1.4 - p.global_position.distance_to(at) / 90.0, 0.2, 1.2))
	_wreck_look()


func _wreck_look() -> void:
	for c in cars:
		if is_instance_valid(c) and c.kind == "furnace":
			c.set_kind("furnace_wreck")
	if furnace != null:
		furnace.show_lit(false)
	Bug.frenzy_lit = false
	if _fire == null and furnace != null:
		_fire = OmniLight3D.new()
		_fire.light_color = Color("#FF7A2B")
		_fire.omni_range = 16.0
		_fire.position = Vector3(0, 3.0, 0)
		furnace.get_parent().add_child(_fire)


## Host: the swarm turns on the wreck: bugs out of the nearest open tunnel run
## for Vane's car and over it; a few stay lying on the wreck.
func _wreck_swarm() -> void:
	var bm := BugManager.instance
	if bm == null or not is_instance_valid(bm) or director.finished:
		return
	var target := _car("private")
	if target == null:
		target = _car("furnace")
	if target == null:
		return
	var at := target.global_position
	var best := -1
	var best_d := INF
	for i in cliffs.tunnel_count():
		if cliffs.sealed.has(i):
			continue
		var dd := (cliffs.tunnel(i)[0] as Vector3).distance_to(at)
		if dd < best_d:
			best_d = dd
			best = i
	if best < 0:
		return
	var tn := cliffs.tunnel(best)
	bm.rpc("_rumble", tn[0], tn[1], 1.2)
	var kinds: Array[StringName] = [&"wolf_spider", &"dust_mite", &"rattler_beetle"]
	for k in ReckoningRules.WRECK_SWARM:
		var pos := (tn[0] as Vector3) + (tn[1] as Vector3) * (1.0 + k * 0.6) + (tn[1] as Vector3).cross(Vector3.UP) * randf_range(-2.0, 2.0)
		var b := bm.spawn_at(kinds[k % kinds.size()], 0, 0, pos.z, 0.0, Bug.State.CROSSING, pos) as Bug
		if b != null:
			b.hunt_peer = -1
			b.hunt_home = at + target.global_transform.basis.z * randf_range(-4.0, 4.0)
	for k in 5:
		var lie := target.to_global(Vector3(randf_range(-2.4, 2.4), 0.0, randf_range(-4.5, 4.5)))
		lie.y = cliffs.floor_height(lie.x, lie.z)
		bm.spawn_site_bug(kinds[k % 2], 0, lie, 60, randf() * TAU)


func _car(kind: String) -> Car:
	for c in cars:
		if is_instance_valid(c) and (c.kind == kind or c.kind == kind + "_wreck"):
			return c
	return null


# ------------------------------------------------------------------ the second blast

## Host: Vane's charges go off on their timer: the main tunnel's rubble is
## blown away and the lower hive is open. The boss comes out of it.
func _second_blast() -> void:
	if second or director.finished:
		return
	second = true
	BugManager.boss_tunnel = main
	_second_fx.rpc()
	_broadcast()
	_say_once("second")


@rpc("authority", "call_local", "reliable")
func _second_fx() -> void:
	second = true
	if cliffs.sealed.has(main):
		cliffs.sealed.erase(main)
	BugManager.boss_tunnel = main
	for n in world.get_children():
		if n is DownTheHole.Rubble:
			n.queue_free()
	BlastFx.play(world, mouth, out)
	Audio.play_at(&"dynamite", mouth, 8.0, 0.5)
	Audio.play_at(&"ground_rumble", mouth, 8.0, 0.6)
	var p := world.call("local_player") as Player
	if p != null:
		p.add_shake(clampf(1.2 - p.global_position.distance_to(mouth) / 100.0, 0.25, 1.0))


# ------------------------------------------------------------------ the Hive Mother and Silas

func _host_mother(delta: float) -> void:
	if sealed or director.finished:
		return
	if _mother == null or not is_instance_valid(_mother):
		_look_t -= delta
		if _look_t > 0.0:
			return
		_look_t = 0.5
		_mother = _find_mother()
		if _mother == null:
			return
		_mother_frac = 1.0
		_mother.died.connect(func(_b: Bug, _src: String, _c: int) -> void: _on_mother_died(), CONNECT_ONE_SHOT)
		if GameState.debug_enabled() and GameState.has_flag("--ch10seal"):
			_mother.health.hp = _mother.health.max_hp * 0.12
	if not _mother.is_alive():
		return
	var frac := _mother.health.hp / maxf(_mother.health.max_hp, 1.0)
	var beat := ReckoningRules.mother_beat(_mother_frac, frac)
	_mother_frac = frac
	if beat != "":
		_say_once(beat)
	if not _seal_started and ReckoningRules.seal_due(frac):
		_seal_started = true
		var brain := _mother.boss
		if brain != null and brain.has_method("set_pinned"):
			brain.call("set_pinned", true)
		_say_once("mother_set")
		_say_once("mother_seal")
		get_tree().create_timer(ReckoningRules.SEAL_FUSE).timeout.connect(_seal)


func _find_mother() -> Bug:
	var bm := BugManager.instance
	if bm == null:
		return null
	var want := StringName(str(director.chapter.objective.get("boss", "hive_mother")))
	for c in bm.get_children():
		var b := c as Bug
		if b != null and b.def != null and b.def.id == want and b.is_alive():
			return b
	return null


## Host: she died before the fuse ran out (one big shot): the charge goes as she falls.
func _on_mother_died() -> void:
	if sealed:
		return
	_say_once("mother_seal")
	_seal()


## Host: Silas's charge goes off under her gallery: sealed, and she's dead.
func _seal() -> void:
	if sealed or director.finished:
		return
	sealed = true
	BugManager.boss_tunnel = -1
	_seal_fx.rpc()
	if _mother != null and is_instance_valid(_mother) and _mother.is_alive():
		var brain := _mother.boss
		if brain != null and brain.has_method("set_pinned"):
			brain.call("set_pinned", false)
		_mother.receive_hit(9999999.0, _mother.global_position, Vector3.UP, true, 1.0, "Silas Kettle's last charge", -1)
	_broadcast()
	get_tree().create_timer(5.0).timeout.connect(func() -> void: _say_once("sealed"))
	if director.holding and done():
		director.piece_done(director.radio_left() + 6.0)


@rpc("authority", "call_local", "reliable")
func _seal_fx() -> void:
	sealed = true
	if not cliffs.sealed.has(main):
		cliffs.sealed.append(main)
	BlastFx.play(world, mouth, out)
	Audio.play_at(&"dynamite", mouth, 8.0, 0.55)
	Audio.play_at(&"thunder", mouth, 6.0, 0.7)
	var rubble := DownTheHole.Rubble.new()
	rubble.name = "SealRubble"
	rubble.settle = true
	world.add_child(rubble)
	rubble.global_transform = Transform3D(Basis(Vector3.UP, atan2(out.x, out.z)), mouth)
	var p := world.call("local_player") as Player
	if p != null:
		p.add_shake(clampf(1.3 - p.global_position.distance_to(mouth) / 90.0, 0.3, 1.1))


# ------------------------------------------------------------------ tracker

func status() -> Array:
	if director.chapter == null:
		return ["", "info"]
	var w := GameState.wave
	if not blown:
		if not lit:
			return ["The Iron Mandible is %s  ·  its furnace is shuttered till dark" % ("in the canyon" if s >= hold_s - 1.0 else "rolling in"), "warn"]
		return ["SHOOT OUT THE AMBER FURNACE: %d%%  ·  the swarm near it is maddened" % int(ceilf(hp / maxf(hp_max, 1.0) * 100.0)), "bad"]
	if w < director.chapter.last_wave and not second:
		return ["Furnace out. The Iron Mandible is a wreck  ·  Night 1 of 2", "good"]
	if not sealed:
		if _seal_started:
			return ["SILAS'S FUSE IS BURNING  ·  keep her on the wall!", "bad"]
		return ["The lower hive is open  ·  bring down the Hive Mother", "warn"]
	return ["The gallery is sealed. Silas didn't come up.", "good"]


# ------------------------------------------------------------------ smoke

func _smoke_tick(delta: float) -> void:
	var source: Vector3
	var every := 0.0
	var fc := _car("furnace")
	if fc == null:
		return
	if lit and not blown:
		source = fc.to_global(TrainMeshes.STACK_TOP)
		every = 0.35
	elif blown:
		source = fc.to_global(Vector3(0, 2.6, 0))
		every = 0.5
		if _fire != null:
			_fire.light_energy = 2.4 + randf() * 1.6
	if every > 0.0:
		_smoke_t -= delta
		if _smoke_t <= 0.0 and _smoke.size() < 40:
			_smoke_t = every
			var mi := MeshInstance3D.new()
			var sph := SphereMesh.new()
			sph.radius = 0.6
			sph.height = 1.2
			sph.radial_segments = 8
			sph.rings = 4
			mi.mesh = sph
			mi.material_override = _smoke_mat
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mi.top_level = true
			add_child(mi)
			mi.global_position = source + Vector3(randf_range(-0.3, 0.3), 0, randf_range(-0.3, 0.3))
			_smoke.append([mi, 0.0])
	for i in range(_smoke.size() - 1, -1, -1):
		var e: Array = _smoke[i]
		var mi: MeshInstance3D = e[0]
		e[1] = float(e[1]) + delta
		var t := float(e[1]) / 7.0
		if t >= 1.0 or not is_instance_valid(mi):
			if is_instance_valid(mi):
				mi.queue_free()
			_smoke.remove_at(i)
			continue
		mi.global_position += Vector3(0.6, 2.2 * (1.0 - t * 0.5), 0.3) * delta
		mi.scale = Vector3.ONE * (1.0 + t * 4.0)
		mi.transparency = t


# ------------------------------------------------------------------ debug

func _debug() -> void:
	if not GameState.debug_enabled():
		return
	if GameState.flag_value("--ch10blow") != "" and multiplayer.is_server():
		get_tree().create_timer(GameState.flag_value("--ch10blow").to_float()).timeout.connect(func() -> void:
			if not blown:
				if not lit:
					lit = true
				furnace_hit(hp + 1.0, furnace.global_position, "Debug"))
	var view := GameState.flag_value("--ch10view")
	if view == "":
		return
	var p: Player = null
	var until := Time.get_ticks_msec() + 20000
	while p == null and Time.get_ticks_msec() < until:
		await get_tree().process_frame
		p = world.call("local_player") as Player
	if p == null:
		return
	for i in 40:
		await get_tree().process_frame
	if view in ["furnace", "wreck"] and multiplayer.is_server():
		# Somewhere in the play area so it can be seen from the floor and the rim.
		s = clampf(hold_s + (stop_s - hold_s) * 0.45, 0.0, stop_s)
		crawling = false
		if view == "furnace":
			lit = true
		_broadcast()
		_place_cars()
	var fc := _car("furnace")
	var loco := _car("loco")
	match view:
		"train":
			var at := loco.to_global(Vector3(9.0, 0.0, 14.0))
			_place(p, at, loco.to_global(Vector3(0, 2.5, -14.0)))
		"furnace":
			_place(p, fc.to_global(Vector3(9.5, 0.0, 6.0)), fc.to_global(Vector3(0, 3.5, 0)))
		"wreck":
			if multiplayer.is_server() and not blown:
				lit = true
				furnace_hit(hp + 1.0, fc.global_position, "Debug")
			await get_tree().create_timer(0.2).timeout
			_place(p, fc.to_global(Vector3(14.0, 0.0, -10.0)), fc.to_global(Vector3(0, 2.5, -4.0)))
		"tunnel":
			var at := mouth + out * 16.0 + out.cross(Vector3.UP) * 6.0
			_place(p, at, mouth + Vector3.UP * 3.0)
		"lip", "mother":
			# Up on the far lip, looking down the canyon at the train / the tunnel.
			p.set("_trip", false)
			var cid := 0
			for c in WorldLayout.cliff_count():
				if (cliffs.plateau_point(c, 0.0, 0.0) - mouth).length() > (cliffs.plateau_point(cid, 0.0, 0.0) - mouth).length():
					cid = c
			var lip := cliffs.plateau_point(cid, 1.0, clampf(mouth.z * 0.3, -17.0, 17.0))
			var look := fc.global_position + Vector3.UP * 3.0 if view == "lip" else mouth + Vector3.UP * 12.0
			p.global_position = lip + Vector3.UP * 0.2
			p.velocity = Vector3.ZERO
			var dd := look - (p.global_position + Vector3.UP * 1.6)
			p.rotation.y = atan2(-dd.x, -dd.z)
			p.head.rotation.x = atan2(dd.y, Vector2(dd.x, dd.z).length())
	print("[ch10] view %s at %s (train nose s %.1f)" % [view, str(p.global_position.snapped(Vector3.ONE * 0.1)), s])


func _place(p: Player, at: Vector3, look: Vector3) -> void:
	at.y = cliffs.floor_height(at.x, at.z) + 0.1
	p.set("_trip", true)
	p.global_position = at
	p.velocity = Vector3.ZERO
	var d := look - (at + Vector3.UP * 1.6)
	p.rotation.y = atan2(-d.x, -d.z)
	p.head.rotation.x = atan2(d.y, Vector2(d.x, d.z).length())


# ------------------------------------------------------------------ nodes

## One car of the train (TrainMeshes.car), moved along the rails every frame;
## solid (players can't walk through it; the wreck stays put).
class Car extends AnimatableBody3D:
	var kind := "loco"
	var _mi: MeshInstance3D

	func _ready() -> void:
		collision_layer = WorldLayout.LAYER_WORLD
		collision_mask = 0
		sync_to_physics = false
		_mi = MeshInstance3D.new()
		_mi.material_override = Materials.toon(0.04)
		add_child(_mi)
		set_kind(kind)
		var l := float(TrainMeshes.LENGTHS.get(kind, 8.0))
		var col := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(2.8, 3.0 if kind != "furnace" else 1.6, l)
		col.shape = bs
		col.position = Vector3(0, 1.0 + bs.size.y * 0.5, 0)
		add_child(col)
		if kind == "loco" or kind == "private":
			var label := Label3D.new()
			label.text = "IRON MANDIBLE" if kind == "loco" else "WESTERN PLAINS & PACIFIC"
			label.font_size = 96
			label.pixel_size = 0.006
			label.modulate = TrainMeshes.GOLD
			label.outline_size = 12
			label.outline_modulate = Color("#1A1012")
			for side: float in [-1.0, 1.0]:
				var l3 := label.duplicate() as Label3D
				l3.rotation.y = side * PI * 0.5
				l3.position = Vector3(side * 1.46, 2.4 if kind == "loco" else 3.62, 0.4 if kind == "loco" else -0.4)
				add_child(l3)
			label.free()
		if kind == "loco":
			var lamp := SpotLight3D.new()
			lamp.light_color = Color("#FFE7A0")
			lamp.light_energy = 6.0
			lamp.spot_range = 45.0
			lamp.spot_angle = 22.0
			lamp.position = Vector3(0, 4.45, 5.2)
			lamp.rotation.x = -0.08
			lamp.rotation.y = PI
			add_child(lamp)

	func set_kind(k: String) -> void:
		if k == kind and _mi.mesh != null:
			return
		kind = k
		_mi.mesh = TrainMeshes.car(kind)


## The amber furnace on its car: the kiln and stack as a target (player shots
## land here: Gun.apply_hit_result calls apply_hit on the host), the glowing
## doors and their shutters, and its light.
class Furnace extends StaticBody3D:
	var director: IronMandible
	var _glow: MeshInstance3D
	var _shutters: MeshInstance3D
	var _light: OmniLight3D

	func _ready() -> void:
		collision_layer = WorldLayout.LAYER_STRUCTURE
		collision_mask = 0
		for b: Array in [[TrainMeshes.KILN + Vector3(0, 0.4, 0), Vector3(3.3, 4.6, 3.4)], [Vector3(0, 8.1, -1.2), Vector3(1.1, 4.8, 1.1)]]:
			var col := CollisionShape3D.new()
			var bs := BoxShape3D.new()
			bs.size = b[1]
			col.shape = bs
			col.position = b[0]
			add_child(col)
		_glow = MeshInstance3D.new()
		_glow.mesh = TrainMeshes.door_glow()
		_glow.material_override = Materials.toon(0.0)
		_glow.visible = false
		add_child(_glow)
		_shutters = MeshInstance3D.new()
		_shutters.mesh = TrainMeshes.shutters()
		_shutters.material_override = Materials.toon(0.02)
		add_child(_shutters)
		_light = OmniLight3D.new()
		_light.light_color = Color("#FFA62B")
		_light.light_energy = 0.0
		_light.omni_range = 18.0
		_light.position = Vector3(0, 3.0, 0)
		add_child(_light)

	func show_lit(on: bool) -> void:
		_glow.visible = on
		_shutters.visible = not on and not (director != null and director.blown)
		_light.light_energy = 3.5 if on else 0.0

	func _process(_delta: float) -> void:
		if _glow.visible:
			_light.light_energy = 3.0 + sin(Time.get_ticks_msec() * 0.008) * 0.8 + randf() * 0.4

	## Host: a shot hit the furnace (Gun.apply_hit_result).
	func apply_hit(dmg: float, at: Vector3, _dir: Vector3, _pierce: bool, source: String, _source_cliff: int) -> void:
		if director != null:
			director.furnace_hit(dmg, at, source)
