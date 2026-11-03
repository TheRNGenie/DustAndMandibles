class_name DryGulchFamilies
extends Node
## Story chapter 9, The Dry Gulch Families: the floor job (StoryDirector makes
## one for a "salvage" chapter; same path on every peer, the host decides and
## RPCs). Rules in HomesteadRules, props in HomesteadProps.
##
## What's in the world: four homesteads the 1889 blast emptied, standing on the
## canyon floor away from the rope winches (HomesteadRules.pick_spots: the
## furthest floor from every rope foot, clear of the raid sites; the canyon
## dressing keeps off them), each with the family's tin document box on the
## table inside (a pale light column over it until it's taken). On the
## objective's `ledger_wave` the amber crew's camp is found at the far end: a
## drill derrick over a glowing resin pit, a donkey engine, tents, crates of
## amber and the board's strongbox, the harvest ledger in it.
##
## The job: E on a family's box puts their papers in your backpack (6 weight);
## E on the strongbox takes the ledger (10 weight, and the lid's noise wakes
## anything near). Story items: never unpacked onto the stockpile, left lying
## where you fall if you're downed (E to repack). Each family's papers come up
## out of the canyon and Pearl reads their letter over the wire; the ledger
## comes up and Silas reads the signatures. Done when all four and the ledger
## are up; the last wave cleared without it: a story hold build until it is.
## Sleepers (dust mites, a wolf spider, later a rattler) lie in the ruins each
## build phase; the core's risk clock and hunters run as usual.
##
## Debug (--debug): --ch9view=homestead | box | camp | ledger | overview puts
## you somewhere to look; --ch9camp shows the camp from the start; --ch9take
## takes what you're looking at; --ch9up brings every bundle and the ledger up
## at once (the ending beat).

const P := HomesteadRules.Papers

var director: StoryDirector
var world: Node3D
var cliffs: CliffBuilder

## Synced state: one entry per family (HomesteadRules.Papers), who holds each,
## where a dropped one lies; the ledger likewise; the camp found or not.
var states: Array = []
var holders: Array = []
var dropped_at: Array = []
var ledger := P.HOME
var ledger_holder := 0
var ledger_at := Vector3.ZERO
var camp_found := false

var spots_list: Array[Vector3] = []
var ruins: Array[Ruin] = []
var camp: Camp
var _dropped_nodes: Dictionary = {}
var _have_state := false
var _ask_t := 0.0
var _said_letters: Dictionary = {}


## Every peer: [homestead 0..3, camp] on the floor (deterministic: the same
## floor, rope feet and raid-site zones give the same spots).
static func spots(cl: CliffBuilder) -> Array[Vector3]:
	var tunnels: Array = []
	for i in cl.tunnel_count():
		tunnels.append(cl.tunnel(i))
	SitePlan.reserve_zones(tunnels)
	var feet: Array[Vector3] = []
	for cid in cl.map.count():
		feet.append(cl.plateau_point(cid, 0.0, Buildable.ROPE_ANCHOR_Z))
	var cands: Array[Vector3] = HomesteadRules.canyon_candidates() if cl.map.is_canyon() \
			else HomesteadRules.ring_candidates(cl.map.center, cl.map.ring_radius)
	var blocked := func(p: Vector3) -> bool: return SitePlan.in_site_zone(p, 1.5, false)
	var sep := HomesteadRules.MIN_SEP
	var camp_at := HomesteadRules.pick_spots(cands, feet, 1, sep, [], blocked)
	var homes := HomesteadRules.pick_spots(cands, feet, HomesteadRules.FAMILIES.size(), sep, camp_at, blocked)
	while homes.size() < HomesteadRules.FAMILIES.size() and sep > 6.0:
		# A small basin: squeeze them closer.
		sep -= 2.0
		homes = HomesteadRules.pick_spots(cands, feet, HomesteadRules.FAMILIES.size(), sep, camp_at, blocked)
	var out: Array[Vector3] = []
	for h in homes:
		out.append(Vector3(h.x, cl.floor_height(h.x, h.z), h.z))
	while out.size() < HomesteadRules.FAMILIES.size():
		out.append(out[0] + Vector3(4.0 * out.size(), 0, 0) if not out.is_empty() else Vector3.ZERO)
	var c: Vector3 = camp_at[0] if not camp_at.is_empty() else out[0] + Vector3(10, 0, 10)
	out.append(Vector3(c.x, cl.floor_height(c.x, c.z), c.z))
	return out


func _ready() -> void:
	cliffs = world.get("cliffs") as CliffBuilder
	spots_list = spots(cliffs)
	var n := HomesteadRules.FAMILIES.size()
	states.resize(n)
	states.fill(P.HOME)
	holders.resize(n)
	holders.fill(0)
	dropped_at.resize(n)
	dropped_at.fill(Vector3.ZERO)
	var mid := Vector3.ZERO
	for i in n:
		mid += spots_list[i] / float(n)
	for i in n:
		var r := Ruin.new()
		r.name = "Ruin%d" % i
		r.index = i
		r.director = self
		world.add_child(r)
		r.global_position = spots_list[i]
		# Front door toward the middle of the settlement (or across the canyon).
		var to := mid - spots_list[i]
		if to.length() < 1.0:
			to = Vector3.BACK
		r.rotation.y = atan2(to.x, to.z) + (i - 1.5) * 0.35
		r.scale = Vector3.ONE * 1.15
		ruins.append(r)
	Expedition.story_items.append(HomesteadRules.PAPERS)
	Expedition.story_items.append(HomesteadRules.LEDGER)
	GameState.phase_changed.connect(_on_phase)
	if multiplayer.is_server():
		_have_state = true
		if GameState.debug_enabled() and GameState.has_flag("--ch9camp"):
			camp_found = true
		Expedition.story_item_up.connect(_on_item_up)
		Expedition.story_item_dropped.connect(_on_item_dropped)
		Expedition.went_down.connect(_on_went_down)
		NetworkManager.players_changed.connect(_broadcast)
		_apply_state(_state())
	print("[ch9] homesteads at %s, camp at %s" % [str(spots_list.slice(0, n)), str(spots_list[n].snapped(Vector3.ONE * 0.1))])
	_debug_view.call_deferred()


func _exit_tree() -> void:
	if GameState.phase_changed.is_connected(_on_phase):
		GameState.phase_changed.disconnect(_on_phase)
	if Expedition.story_item_up.is_connected(_on_item_up):
		Expedition.story_item_up.disconnect(_on_item_up)
		Expedition.story_item_dropped.disconnect(_on_item_dropped)
		Expedition.went_down.disconnect(_on_went_down)
	if NetworkManager.players_changed.is_connected(_broadcast):
		NetworkManager.players_changed.disconnect(_broadcast)


# ------------------------------------------------------------------ state

func done() -> bool:
	return HomesteadRules.done(states, ledger)


## Host: seconds to hold the win while the ledger beat finishes on the wire.
func win_delay() -> float:
	return minf(director.radio_left() + 1.0, 60.0)


func _state() -> Dictionary:
	return {"states": states.duplicate(), "holders": holders.duplicate(), "dropped": dropped_at.duplicate(),
			"ledger": ledger, "ledger_holder": ledger_holder, "ledger_at": ledger_at, "camp": camp_found}


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
	states = (state.get("states", states) as Array).duplicate()
	holders = (state.get("holders", holders) as Array).duplicate()
	dropped_at = (state.get("dropped", dropped_at) as Array).duplicate()
	ledger = int(state.get("ledger", P.HOME))
	ledger_holder = int(state.get("ledger_holder", 0))
	ledger_at = state.get("ledger_at", Vector3.ZERO)
	camp_found = bool(state.get("camp", false))
	for r in ruins:
		if is_instance_valid(r):
			r.show_box(int(states[r.index]) == P.HOME)
	if camp_found and camp == null:
		_make_camp()
	if camp != null:
		camp.show_ledger(ledger == P.HOME)
	_refresh_drops()
	if director != null and director.tracker != null:
		director.tracker.refresh()


func _make_camp() -> void:
	camp = Camp.new()
	camp.name = "AmberCamp"
	camp.director = self
	world.add_child(camp)
	var at: Vector3 = spots_list[spots_list.size() - 1]
	camp.global_position = at
	var mid := Vector3.ZERO
	for i in ruins.size():
		mid += spots_list[i] / float(ruins.size())
	var to := mid - at
	camp.rotation.y = atan2(to.x, to.z) if to.length() > 1.0 else 0.0


func _refresh_drops() -> void:
	var want: Dictionary = {}
	for i in states.size():
		if int(states[i]) == P.DROPPED:
			want[i] = dropped_at[i]
	if ledger == P.DROPPED:
		want[-1] = ledger_at
	for k: Variant in _dropped_nodes.keys():
		if not want.has(k):
			var n: Node = _dropped_nodes[k]
			if is_instance_valid(n):
				n.queue_free()
			_dropped_nodes.erase(k)
	for k: Variant in want:
		if not _dropped_nodes.has(k):
			var b := DroppedBundle.new()
			b.name = "DroppedBundle%d" % (int(k) + 1)
			b.index = int(k)
			b.director = self
			world.add_child(b)
			b.global_position = want[k]
			_dropped_nodes[k] = b


# ------------------------------------------------------------------ requests

## Any peer: E on a family's box (0..3) or the strongbox (-1), or a dropped bundle.
func request_take(i: int) -> void:
	if multiplayer.is_server():
		_take(multiplayer.get_unique_id(), i)
	else:
		_ask_take.rpc_id(1, i)


@rpc("any_peer", "reliable")
func _ask_take(i: int) -> void:
	if multiplayer.is_server():
		_take(multiplayer.get_remote_sender_id(), i)


func _take(peer: int, i: int) -> void:
	if director.finished:
		return
	if not Expedition.is_down(peer) and not GameState.debug_enabled():
		return
	if i < 0:
		if ledger != P.HOME and ledger != P.DROPPED:
			return
		if not camp_found:
			return
		if Expedition.add_to_backpack(peer, {HomesteadRules.LEDGER: 1}) <= 0:
			Economy.notify(peer, "No room in your backpack for the ledger (%d weight). Ride up and unpack first." % Backpack.weight_of(HomesteadRules.LEDGER))
			return
		var first := ledger == P.HOME
		ledger = P.PACKED
		ledger_holder = peer
		Economy.notify(peer, "The board's harvest ledger is in your backpack. Get it up to Pearl.")
		if first:
			Expedition.make_noise(spots_list[spots_list.size() - 1], HomesteadRules.LEDGER_NOISE)
			_amber_crates(peer)
			_say_once("ledger_taken")
		_broadcast()
		return
	if i >= states.size() or (int(states[i]) != P.HOME and int(states[i]) != P.DROPPED):
		return
	if Expedition.add_to_backpack(peer, {HomesteadRules.PAPERS: 1}) <= 0:
		Economy.notify(peer, "No room in your backpack for the %s papers. Ride up and unpack first." % HomesteadRules.family_name(i))
		return
	states[i] = P.PACKED
	holders[i] = peer
	Economy.notify(peer, "The %s family's deed and letters are in your backpack." % HomesteadRules.family_name(i))
	_say_once("papers")
	_broadcast()


## WIRE TO AMBER AT MERGE (StoryAmber): the crew's crates of amber go in the
## pack of whoever opened the strongbox (nothing on the story branch).
func _amber_crates(peer: int) -> void:
	var n := StoryAmber.pack(peer, 6, "the board's amber crates")
	if n > 0:
		Economy.notify(peer, "And %d chunks of the board's hive amber from the crew's crates. Theirs no longer." % n)


func _say_once(key: String) -> void:
	if director._said.has("ch9_" + key):
		return
	director._said["ch9_" + key] = true
	director._event.rpc(key)


func _on_went_down(_peer: int) -> void:
	_say_once("down")


## Host: papers or the ledger came up out of the canyon in a pack.
func _on_item_up(peer: int, item: StringName, units: int) -> void:
	if item == HomesteadRules.PAPERS:
		var mine := HomesteadRules.carried_by(states, holders, peer)
		for k in mini(units, mine.size()):
			var i: int = mine[k]
			states[i] = P.UP
			if not _said_letters.has(i):
				_said_letters[i] = true
				director._event.rpc("letter_" + HomesteadRules.family_id(i))
		Economy.notify(peer, "Pearl has the papers in Doc's rail car. %d of %d families." % [HomesteadRules.papers_up(states), states.size()])
	elif item == HomesteadRules.LEDGER and ledger == P.PACKED:
		ledger = P.UP
		director._event.rpc("ledger")
	else:
		return
	_broadcast()
	if done():
		director.piece_done(director.radio_left() + 3.0)


## Host: a carrier went down on the floor: what they carried lies where they fell.
func _on_item_dropped(peer: int, item: StringName, units: int, pos: Vector3) -> void:
	var at := Vector3(pos.x, cliffs.floor_height(pos.x, pos.z), pos.z)
	if item == HomesteadRules.PAPERS:
		var mine := HomesteadRules.carried_by(states, holders, peer)
		for k in mini(units, mine.size()):
			var i: int = mine[k]
			states[i] = P.DROPPED
			holders[i] = 0
			dropped_at[i] = at + Vector3(0.6 * k, 0, 0.4 * k)
	elif item == HomesteadRules.LEDGER and ledger == P.PACKED:
		ledger = P.DROPPED
		ledger_holder = 0
		ledger_at = at + Vector3(-0.6, 0, 0.3)
	else:
		return
	_broadcast()


# ------------------------------------------------------------------ phases and the tick

func _on_phase(p: GameState.Phase) -> void:
	if p != GameState.Phase.BUILD or not multiplayer.is_server():
		return
	if not camp_found and GameState.wave >= int(director.chapter.objective.get("ledger_wave", director.chapter.last_wave)):
		camp_found = true
		_broadcast()
		_say_once("camp")
	# Sleepers in the ruins (after the raid sites have put theirs down).
	get_tree().create_timer(2.0).timeout.connect(_lay_sleepers)


func _lay_sleepers() -> void:
	var bm := BugManager.instance
	if bm == null or not is_instance_valid(bm) or GameState.phase != GameState.Phase.BUILD or director.finished:
		return
	if GameState.debug_enabled() and (GameState.flag_value("--ch9view") != "" or GameState.has_flag("--ch9nosleep")):
		return # (screenshots: nobody bites the camera)
	var kinds: Array[StringName] = [&"dust_mite", &"wolf_spider", &"dust_mite", &"rattler_beetle"]
	for i in ruins.size():
		if int(states[i]) == P.UP:
			continue
		var r := ruins[i]
		for k in (2 if i % 2 == 0 else 1):
			var at := r.to_global(Vector3(3.2 - k * 6.0, 0, 3.4 - k * 1.5))
			at.y = cliffs.floor_height(at.x, at.z)
			bm.spawn_site_bug(kinds[(i + k) % kinds.size()], 0, at, 40 + i, randf() * TAU)
	if camp_found and ledger == P.HOME:
		for k in 2:
			var at: Vector3 = spots_list[spots_list.size() - 1] + Vector3(-3.0 + k * 6.0, 0, 3.0)
			at.y = cliffs.floor_height(at.x, at.z)
			bm.spawn_site_bug(&"wolf_spider" if k == 0 else &"spitter_scorpion", 0, at, 45, randf() * TAU)


func _process(delta: float) -> void:
	if multiplayer.is_server() or _have_state:
		return
	_ask_t -= delta
	if _ask_t <= 0.0:
		_ask_t = 1.5
		_want_state.rpc_id(1)


# ------------------------------------------------------------------ tracker

func status() -> Array:
	var up := HomesteadRules.papers_up(states)
	var packed := 0
	var lying := 0
	for s: Variant in states:
		packed += 1 if int(s) == P.PACKED else 0
		lying += 1 if int(s) == P.DROPPED else 0
	var text := "Families' papers: %d / %d up" % [up, states.size()]
	if packed > 0:
		text += "  ·  %d in a pack" % packed
	if lying > 0:
		text += "  ·  %d dropped!" % lying
	match ledger:
		P.HOME:
			text += "  ·  Ledger: %s" % ("in the crew's strongbox" if camp_found else "not found yet")
		P.PACKED:
			text += "  ·  Ledger: in a pack"
		P.DROPPED:
			text += "  ·  Ledger: dropped!"
		P.UP:
			text += "  ·  Ledger: with Pearl"
	var kind := "good" if done() else ("bad" if lying > 0 or ledger == P.DROPPED else ("warn" if up > 0 or packed > 0 else "info"))
	return [text, kind]


# ------------------------------------------------------------------ debug views

func _debug_view() -> void:
	if not GameState.debug_enabled():
		return
	if GameState.has_flag("--ch9up") and multiplayer.is_server():
		await get_tree().create_timer(4.0).timeout
		camp_found = true
		for i in states.size():
			states[i] = P.UP
			director._event.rpc("letter_" + HomesteadRules.family_id(i))
		ledger = P.UP
		director._event.rpc("ledger")
		_broadcast()
	var view := GameState.flag_value("--ch9view")
	if view == "":
		return
	GameState.god_mode = true # (screenshots: nothing on the floor ends the view early)
	var p: Player = null
	var until := Time.get_ticks_msec() + 20000
	while p == null and Time.get_ticks_msec() < until:
		await get_tree().process_frame
		p = world.call("local_player") as Player
	if p == null:
		return
	for i in 40:
		await get_tree().process_frame
	if view in ["camp", "ledger"] and multiplayer.is_server() and not camp_found:
		camp_found = true
		_broadcast()
		await get_tree().process_frame
	var k := clampi(int(GameState.flag_value("--ch9ruin")), 0, ruins.size() - 1)
	match view:
		"homestead":
			var r := ruins[k]
			_place(p, r.to_global(Vector3(5.5, 0.0, 11.0)), r.to_global(Vector3(0, 1.6, 0)))
		"box":
			var r := ruins[k]
			_place(p, r.to_global(Vector3(0.4, 0.3, 1.2)), r.to_global(HomesteadProps.BOX_SPOT + Vector3(0, 0.1, 0)))
		"camp":
			_place(p, camp.to_global(Vector3(7.0, 0.0, 12.0)), camp.to_global(Vector3(0, 3.5, -3.0)))
		"ledger":
			_place(p, camp.to_global(Camp.BOX_AT + Vector3(0.6, 0.0, 2.2)), camp.to_global(Camp.BOX_AT + Vector3(0, 0.4, 0)))
		"overview":
			var c: Vector3 = spots_list[spots_list.size() - 1]
			var mid := Vector3.ZERO
			for i in ruins.size():
				mid += spots_list[i] / float(ruins.size())
			_place(p, mid + (mid - c).normalized() * 16.0 + Vector3(4, 0, 0), mid.lerp(c, 0.3))
	if GameState.has_flag("--ch9take"):
		await get_tree().create_timer(1.5).timeout
		request_take(-1 if view in ["camp", "ledger"] else k)
	print("[ch9] view %s at %s" % [view, str(p.global_position.snapped(Vector3.ONE * 0.1))])


func _place(p: Player, at: Vector3, look: Vector3) -> void:
	at.y = cliffs.floor_height(at.x, at.z) + 0.1 if at.y < WorldLayout.CANYON_FALL_Y else at.y
	p.set("_trip", true)
	p.global_position = at
	p.velocity = Vector3.ZERO
	var d := look - (at + Vector3.UP * 1.6)
	p.rotation.y = atan2(-d.x, -d.z)
	p.head.rotation.x = atan2(d.y, Vector2(d.x, d.z).length())


# ------------------------------------------------------------------ nodes

## One ruined homestead (HomesteadProps.ruin_mesh), its name on the gate and the
## family's tin box on the table inside.
class Ruin extends StaticBody3D:
	var index := 0
	var director: DryGulchFamilies
	var box: PapersBox
	var _beam: MeshInstance3D

	func _ready() -> void:
		collision_layer = WorldLayout.LAYER_WORLD
		collision_mask = 0
		var boxes: Array = []
		var mi := MeshInstance3D.new()
		mi.mesh = HomesteadProps.ruin_mesh(1889 + index * 37, boxes)
		mi.material_override = Materials.toon(0.03)
		add_child(mi)
		for b: Array in boxes:
			var col := CollisionShape3D.new()
			var bs := BoxShape3D.new()
			bs.size = b[1]
			col.shape = bs
			col.transform = b[0]
			add_child(col)
		var sign := Label3D.new()
		sign.text = HomesteadRules.family_name(index).to_upper()
		sign.font_size = 72
		sign.pixel_size = 0.005
		sign.modulate = Color("#3A2418")
		sign.outline_size = 0
		sign.position = Vector3(-1.6, 1.55, 2.5 + 3.73)
		add_child(sign)
		var back := sign.duplicate() as Label3D
		back.rotation.y = PI
		back.position.z -= 0.08
		add_child(back)
		var notice := Label3D.new()
		notice.text = "CLAIM VOID\nW.P.&P. R.R."
		notice.font_size = 28
		notice.pixel_size = 0.004
		notice.modulate = Color("#2B1B17")
		notice.position = Vector3(-0.78, 1.62, 2.5 + 0.13)
		add_child(notice)
		box = PapersBox.new()
		box.index = index
		box.director = director
		add_child(box)
		box.position = HomesteadProps.BOX_SPOT
		var lamp := OmniLight3D.new()
		lamp.light_color = Color("#FFD9A0")
		lamp.light_energy = 0.8
		lamp.omni_range = 4.0
		lamp.position = HomesteadProps.BOX_SPOT + Vector3(0, 0.8, 0.3)
		box.add_child(lamp)
		_beam = MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.2
		cyl.bottom_radius = 0.4
		cyl.height = 34.0
		cyl.radial_segments = 10
		cyl.cap_top = false
		cyl.cap_bottom = false
		_beam.mesh = cyl
		var bm := StandardMaterial3D.new()
		bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		bm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		bm.cull_mode = BaseMaterial3D.CULL_DISABLED
		bm.albedo_color = Color(Color("#FFE2A8"), 0.13)
		_beam.material_override = bm
		_beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_beam.position = HomesteadProps.BOX_SPOT + Vector3(0, 17.0, 0)
		add_child(_beam)

	func show_box(home: bool) -> void:
		if box != null:
			box.set_home(home)
		if _beam != null:
			_beam.visible = home


## The family's tin box on the table: E puts their papers in your backpack.
class PapersBox extends StaticBody3D:
	var index := 0
	var director: DryGulchFamilies
	var _mi: MeshInstance3D
	var _home := true

	func _ready() -> void:
		collision_layer = WorldLayout.LAYER_TRAP
		collision_mask = 0
		_mi = MeshInstance3D.new()
		_mi.mesh = HomesteadProps.tin_box_mesh(true)
		_mi.material_override = Materials.toon(0.015)
		add_child(_mi)
		var col := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(0.9, 0.6, 0.7)
		col.shape = bs
		col.position = Vector3(0, 0.2, 0)
		add_child(col)

	func set_home(home: bool) -> void:
		if home == _home:
			return
		_home = home
		_mi.mesh = HomesteadProps.tin_box_mesh(home)

	func interact_prompt() -> String:
		var fam := HomesteadRules.family_name(index)
		if not _home:
			return "The %s Box  -  empty" % fam
		return "The %s Family's Papers  -  deed and letters  ·  weight %d\nE: into your backpack" % [fam, Backpack.weight_of(HomesteadRules.PAPERS)]

	func local_interact(holding: bool) -> void:
		if not holding and _home and director != null:
			director.request_take(index)


## The amber crew's camp (HomesteadProps.camp_mesh) and the board's strongbox.
class Camp extends StaticBody3D:
	const BOX_AT := Vector3(-1.8, 0.0, 1.2)
	var director: DryGulchFamilies
	var strongbox: LedgerBox
	var _glow: OmniLight3D

	func _ready() -> void:
		collision_layer = WorldLayout.LAYER_WORLD
		collision_mask = 0
		var boxes: Array = []
		var mi := MeshInstance3D.new()
		mi.mesh = HomesteadProps.camp_mesh(91, boxes)
		mi.material_override = Materials.toon(0.03)
		add_child(mi)
		for e: Array in HomesteadProps.camp_extras(91):
			var ex := MeshInstance3D.new()
			ex.mesh = e[0]
			ex.transform = e[1]
			ex.material_override = Materials.toon(0.03)
			add_child(ex)
		for b: Array in boxes:
			var col := CollisionShape3D.new()
			var bs := BoxShape3D.new()
			bs.size = b[1]
			col.shape = bs
			col.transform = b[0]
			add_child(col)
		_glow = OmniLight3D.new()
		_glow.light_color = Color("#FFA62B")
		_glow.light_energy = 2.2
		_glow.omni_range = 9.0
		_glow.position = Vector3(0, 1.2, -3.0)
		add_child(_glow)
		var flag := Label3D.new()
		flag.text = "W.P.&P. AMBER CO."
		flag.font_size = 40
		flag.pixel_size = 0.006
		flag.modulate = Color("#F2E3C2")
		flag.position = Vector3(1.15, 10.95, -2.98)
		add_child(flag)
		strongbox = LedgerBox.new()
		strongbox.director = director
		add_child(strongbox)
		strongbox.position = BOX_AT
		strongbox.rotation.y = PI # lock plate toward the homesteads

	func show_ledger(in_box: bool) -> void:
		strongbox.set_full(in_box)

	func _process(_delta: float) -> void:
		_glow.light_energy = 2.0 + sin(Time.get_ticks_msec() * 0.003) * 0.4


## The board's strongbox: E takes the harvest ledger (loud).
class LedgerBox extends StaticBody3D:
	var director: DryGulchFamilies
	var _book: MeshInstance3D
	var _full := true

	func _ready() -> void:
		collision_layer = WorldLayout.LAYER_TRAP
		collision_mask = 0
		var mi := MeshInstance3D.new()
		mi.mesh = StoryStrongbox.box_mesh()
		mi.material_override = Materials.toon(0.02)
		add_child(mi)
		_book = MeshInstance3D.new()
		_book.mesh = HomesteadProps.ledger_mesh()
		_book.material_override = Materials.toon(0.015)
		_book.position = Vector3(0.0, 0.78, -0.05)
		_book.rotation.y = 0.3
		add_child(_book)
		var col := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(1.0, 0.8, 0.7)
		col.shape = bs
		col.position = Vector3(0, 0.4, 0)
		add_child(col)

	func set_full(full: bool) -> void:
		_full = full
		_book.visible = full

	func interact_prompt() -> String:
		if not _full:
			return "The Board's Strongbox  -  empty"
		return "The Board's Strongbox  -  the harvest ledger  ·  weight %d\nE: take it (the lid is loud)" % Backpack.weight_of(HomesteadRules.LEDGER)

	func local_interact(holding: bool) -> void:
		if not holding and _full and director != null:
			director.request_take(-1)


## Papers (or the ledger, index -1) a downed carrier dropped: E to repack.
class DroppedBundle extends StaticBody3D:
	var index := 0
	var director: DryGulchFamilies

	func _ready() -> void:
		collision_layer = WorldLayout.LAYER_TRAP
		collision_mask = 0
		var mi := MeshInstance3D.new()
		mi.mesh = HomesteadProps.ledger_mesh() if index < 0 else HomesteadProps.bundle_mesh()
		mi.material_override = Materials.toon(0.015)
		mi.rotation.y = 0.7
		add_child(mi)
		var col := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(0.7, 0.4, 0.7)
		col.shape = bs
		col.position = Vector3(0, 0.15, 0)
		add_child(col)

	func interact_prompt() -> String:
		if index < 0:
			return "The Board's Harvest Ledger (dropped)\nE: into your backpack"
		return "The %s Papers (dropped)\nE: into your backpack" % HomesteadRules.family_name(index)

	func local_interact(holding: bool) -> void:
		if not holding and director != null:
			director.request_take(index)
