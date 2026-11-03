class_name DownTheHole
extends Node
## Story chapter 7, Down the Hole: the dynamite job at the main tunnel
## (StoryDirector makes one for a "blast" chapter; same path on every peer, the
## host decides and RPCs). The rules are in BlastRules.
##
## What's in the world: a pile of dynamite crates by every rope winch's foot;
## the main tunnel's mouth (CliffBuilder.main_tunnel: the one nearest a rope
## foot, drawn as the biggest) shored up as a mine portal with a fuse spool
## beside it; the tunnel's inside (MineTunnel), entered through the portal.
##
## The job: take a crate from a pile (E; 35 weight, two to a pack, you walk
## slow), carry it into the tunnel and set it at a chalk mark (E). Crates that
## come back up go back on the pile; a downed carrier's crates lie where they
## fell. Once every mark has a charge the spool by the portal takes a light
## (E): BlastRules.FUSE seconds, then the tunnel blows. Anyone still inside, or
## near the mouth, is buried (downed); further out on the floor it still hurts.
## The blast seals the tunnel (no bugs come out of it again; The Queen keeps it
## sealed, see seal_main) and leaves a heap of rubble in the mouth.
##
## Hunters: while anyone's down, wolf spiders, dust mites and rattlers pour out
## of the main tunnel at whoever's on the floor (faster with every charge set,
## fastest once the fuse burns), and out of the hive hole at whoever's inside.
## Expedition's own risk-clock hunters are off for the chapter.
##
## Debug (--debug): --ch7view=portal | interior | charge | fuse | blast |
## sealed | hunt puts you somewhere to look (screenshots); --ch7fuse=S sets the
## fuse; --ch7crates=N the job's size.

const PILE_SIDE := 2.4

var director: StoryDirector
var world: Node3D
var cliffs: CliffBuilder

## Synced state.
var needed := 0
var charges: Array = []
var fuse_left := -1.0
var blown := false
var dropped: Dictionary = {} # id -> Vector3

var main := 0
var mouth := Vector3.ZERO
var out := Vector3.BACK
var portal: MinePortal
var tunnel: MineTunnel
var piles: Array[CratePile] = []
var _dropped_nodes: Dictionary = {}
var _next_drop := 0
var _fuse_total := BlastRules.FUSE

# Host.
var _hunt_t := 0.0
var _retarget_t := 0.0
var _hunters: Array[Bug] = []
var _inside_hunters: Array[Bug] = []
var _ask_t := 0.0
var _have_state := false
var _fade: ColorRect
# Local: underground the sky's ambient light fades down (the lanterns light the way).
var _env: Environment
var _ambient0 := -1.0
var _dark := 0.0


func _ready() -> void:
	cliffs = world.get("cliffs") as CliffBuilder
	main = cliffs.main_tunnel()
	var tn := cliffs.tunnel(main)
	mouth = tn[0]
	out = (tn[1] as Vector3)
	out.y = 0.0
	out = out.normalized()
	mouth.y = cliffs.floor_height(mouth.x, mouth.z)
	_fuse_total = director.chapter.fuse()
	if GameState.debug_enabled() and GameState.flag_value("--ch7fuse") != "":
		_fuse_total = maxf(GameState.flag_value("--ch7fuse").to_float(), 1.0)
	var yaw := atan2(out.x, out.z)
	portal = MinePortal.new()
	portal.name = "MinePortal"
	portal.director = self
	world.add_child(portal)
	portal.global_transform = Transform3D(Basis(Vector3.UP, yaw), mouth)
	tunnel = MineTunnel.new()
	tunnel.name = "MineTunnel"
	tunnel.director = self
	world.add_child(tunnel)
	tunnel.global_transform = Transform3D(Basis(Vector3.UP, yaw), mouth + Vector3.DOWN * BlastRules.SET_DROP)
	for a in RopeAnchor.all():
		var pile := CratePile.new()
		pile.name = "CratePile%d" % a.cliff_id
		pile.director = self
		world.add_child(pile)
		var side := a.inward.cross(Vector3.UP).normalized()
		var at := a.foot_stand + side * PILE_SIDE
		pile.global_position = Vector3(at.x, cliffs.floor_height(at.x, at.z), at.z)
		pile.rotation.y = atan2(a.inward.x, a.inward.z)
		piles.append(pile)
	Expedition.story_items.append(BlastRules.ITEM)
	Expedition.risk_enabled = false
	Expedition.drop_point_hook = _drop_point
	Expedition.backpack_changed.connect(_on_pack_changed)
	if multiplayer.is_server():
		var riders := maxi(NetworkManager.players.size(), 1)
		needed = director.chapter.crates_for(riders)
		if GameState.debug_enabled() and GameState.flag_value("--ch7crates") != "":
			needed = clampi(int(GameState.flag_value("--ch7crates")), 1, 8)
		charges.resize(needed)
		charges.fill(false)
		_have_state = true
		Expedition.story_item_up.connect(_on_item_up)
		Expedition.story_item_dropped.connect(_on_item_dropped)
		Expedition.went_down.connect(_on_went_down)
		NetworkManager.players_changed.connect(_broadcast)
		_apply_state(_state())
	print("[ch7] main tunnel %d at %s, out %s, %d crates" % [main, str(mouth.snapped(Vector3.ONE * 0.1)), str(out.snapped(Vector3.ONE * 0.01)), needed])
	_debug_view.call_deferred()


func _exit_tree() -> void:
	if _env != null and _ambient0 >= 0.0:
		_env.ambient_light_energy = _ambient0
	Expedition.risk_enabled = true
	Expedition.drop_point_hook = Callable()
	if Expedition.backpack_changed.is_connected(_on_pack_changed):
		Expedition.backpack_changed.disconnect(_on_pack_changed)
	if Expedition.story_item_up.is_connected(_on_item_up):
		Expedition.story_item_up.disconnect(_on_item_up)
		Expedition.story_item_dropped.disconnect(_on_item_dropped)
		Expedition.went_down.disconnect(_on_went_down)
	if NetworkManager.players_changed.is_connected(_broadcast):
		NetworkManager.players_changed.disconnect(_broadcast)


# ------------------------------------------------------------------ state

func set_count() -> int:
	var n := 0
	for c: Variant in charges:
		if bool(c):
			n += 1
	return n


func armed() -> bool:
	return needed > 0 and set_count() >= needed


func lit() -> bool:
	return fuse_left >= 0.0


## Crates in anyone's backpack (every peer; packs are synced).
func carried() -> int:
	var n := 0
	for peer: Variant in Expedition.packs:
		n += Expedition.pack_count(int(peer), BlastRules.ITEM)
	return n


func on_pile() -> int:
	return BlastRules.on_pile(needed, set_count(), carried(), dropped.size())


func _state() -> Dictionary:
	return {"needed": needed, "charges": charges.duplicate(), "fuse": fuse_left, "blown": blown, "dropped": dropped.duplicate()}


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
	needed = int(state.get("needed", 0))
	charges = (state.get("charges", []) as Array).duplicate()
	var was_lit := lit()
	fuse_left = float(state.get("fuse", -1.0))
	if not was_lit and lit() and portal != null:
		portal.light_fuse(_fuse_total)
	dropped = (state.get("dropped", {}) as Dictionary).duplicate()
	if tunnel != null and is_instance_valid(tunnel):
		tunnel.lay_spots(needed)
		tunnel.show_set(charges)
	_refresh_drops()
	_refresh_piles()
	if director != null and director.tracker != null:
		director.tracker.refresh()


func _refresh_piles() -> void:
	for p in piles:
		if is_instance_valid(p):
			p.show_count(0 if blown else on_pile())


func _on_pack_changed(_peer: int) -> void:
	_refresh_piles()


func _refresh_drops() -> void:
	for id: Variant in _dropped_nodes.keys():
		if not dropped.has(id):
			var n: Node = _dropped_nodes[id]
			if is_instance_valid(n):
				n.queue_free()
			_dropped_nodes.erase(id)
	for id: Variant in dropped:
		if not _dropped_nodes.has(id):
			var c := DroppedCrate.new()
			c.name = "DroppedCrate%d" % int(id)
			c.crate_id = int(id)
			c.director = self
			world.add_child(c)
			c.global_position = dropped[id]
			_dropped_nodes[id] = c


# ------------------------------------------------------------------ requests (any peer -> host)

func request_take() -> void:
	_request("take", 0)


func request_set(i: int) -> void:
	_request("set", i)


func request_light() -> void:
	_request("light", 0)


func request_pick(id: int) -> void:
	_request("pick", id)


func _request(what: String, arg: int) -> void:
	if multiplayer.is_server():
		_do(multiplayer.get_unique_id(), what, arg)
	else:
		_ask.rpc_id(1, what, arg)


@rpc("any_peer", "reliable")
func _ask(what: String, arg: int) -> void:
	if multiplayer.is_server():
		_do(multiplayer.get_remote_sender_id(), what, arg)


func _do(peer: int, what: String, arg: int) -> void:
	if blown or director.finished:
		return
	if not Expedition.is_down(peer) and not GameState.debug_enabled():
		return
	match what:
		"take":
			if on_pile() <= 0:
				Economy.notify(peer, "That's every crate the job needs. The rest are out already.")
				return
			if Expedition.add_to_backpack(peer, {BlastRules.ITEM: 1}) <= 0:
				Economy.notify(peer, "No room in your backpack for a dynamite crate (%d weight). Ride up and unpack first." % Backpack.weight_of(BlastRules.ITEM))
				return
			Economy.notify(peer, "A crate of dynamite in your backpack. Gently now: into the main tunnel with it.")
			_say_once("crate")
		"pick":
			if not dropped.has(arg):
				return
			if Expedition.add_to_backpack(peer, {BlastRules.ITEM: 1}) <= 0:
				Economy.notify(peer, "No room in your backpack for the crate.")
				return
			dropped.erase(arg)
		"set":
			if arg < 0 or arg >= needed or bool(charges[arg]):
				return
			if not Expedition.take_from_backpack(peer, {BlastRules.ITEM: 1}):
				Economy.notify(peer, "You need a dynamite crate in your backpack.")
				return
			charges[arg] = true
			_charge_fx.rpc(arg)
			if armed():
				_say_once("armed")
			else:
				_say_once("charge")
		"light":
			if not armed() or lit():
				return
			fuse_left = _fuse_total
			_say_once("lit")
	_broadcast()


func _say_once(key: String) -> void:
	if director._said.has("ch7_" + key):
		return
	director._said["ch7_" + key] = true
	director._event.rpc(key)


@rpc("authority", "call_local", "reliable")
func _charge_fx(i: int) -> void:
	if tunnel != null and is_instance_valid(tunnel) and i < tunnel.spots.size():
		var at := tunnel.spots[i].global_position
		Audio.play_at(&"hammer_hit", at, -2.0)
		Audio.play_at(&"rustle", at, -4.0)


# ------------------------------------------------------------------ host: items

func _on_item_up(peer: int, item: StringName, units: int) -> void:
	if item != BlastRules.ITEM:
		return
	Economy.notify(peer, "You brought %d dynamite %s back up: back on the pile at the rope foot." % [units, "crate" if units == 1 else "crates"])
	_broadcast()


func _on_item_dropped(_peer: int, item: StringName, units: int, pos: Vector3) -> void:
	if item != BlastRules.ITEM or blown:
		return
	for k in units:
		_next_drop += 1
		var p := pos + Vector3(0.7 * k, 0, 0.5 * k)
		dropped[_next_drop] = Vector3(p.x, cliffs.floor_height(p.x, p.z), p.z)
	_broadcast()


func _on_went_down(_peer: int) -> void:
	if not blown:
		_say_once("down")


## A sack or crate dropped inside the tunnel set lands in front of the portal.
func _drop_point(pos: Vector3) -> Vector3:
	if pos.y < Bug.UNDERGROUND_Y:
		return mouth + out * 4.0
	return pos


# ------------------------------------------------------------------ walking in and out

## Owner: E at the portal: fade in to the tunnel set.
func enter_tunnel() -> void:
	var p := _me()
	if p == null or blown or tunnel == null:
		return
	if not Expedition.is_down(multiplayer.get_unique_id()) and not GameState.debug_enabled():
		return
	_fade_move(p, tunnel.entrance_stand(), atan2(out.x, out.z))
	if not director._said.has("ch7_inside"):
		director._said["ch7_inside"] = true
		if multiplayer.is_server():
			director._event.rpc("inside")
		else:
			_tell_inside.rpc_id(1)


@rpc("any_peer", "reliable")
func _tell_inside() -> void:
	if multiplayer.is_server():
		_say_once("inside")


## Owner: E at the daylight: fade back out onto the floor in front of the portal.
func leave_tunnel() -> void:
	var p := _me()
	if p != null:
		_fade_move(p, outside_stand(), atan2(-out.x, -out.z))


func outside_stand() -> Vector3:
	var at := mouth + out * 3.2
	return Vector3(at.x, cliffs.floor_height(at.x, at.z) + 0.1, at.z)


func _fade_move(p: Player, to: Vector3, yaw: float) -> void:
	if _fade == null:
		var layer := CanvasLayer.new()
		layer.layer = 50
		add_child(layer)
		_fade = ColorRect.new()
		_fade.color = Color(0, 0, 0, 0)
		_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
		layer.add_child(_fade)
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, 0.18)
	tw.tween_callback(func() -> void:
		if not is_instance_valid(p):
			return
		p.global_position = to
		p.velocity = Vector3.ZERO
		p.rotation.y = yaw
		p.head.rotation.x = 0.0
		Audio.play_at(&"step_dirt", to, -4.0))
	tw.tween_property(_fade, "color:a", 0.0, 0.35)


func _me() -> Player:
	return world.call("local_player") as Player


func is_inside(p: Node3D) -> bool:
	return p != null and p.global_position.y < Bug.UNDERGROUND_Y


# ------------------------------------------------------------------ host tick

func _process(delta: float) -> void:
	_underground_light(delta)
	if not multiplayer.is_server():
		if not _have_state:
			_ask_t -= delta
			if _ask_t <= 0.0:
				_ask_t = 1.5
				_want_state.rpc_id(1)
		return
	if blown:
		return
	if lit():
		fuse_left = maxf(fuse_left - delta, 0.0)
		if fuse_left <= 0.0:
			_detonate()
			return
	_hunt(delta)


func _underground_light(delta: float) -> void:
	if _env == null:
		_env = world.get("_env") as Environment
		if _env == null:
			return
		_ambient0 = _env.ambient_light_energy
	var want := 1.0 if is_inside(_me()) else 0.0
	if is_equal_approx(want, _dark):
		return
	_dark = move_toward(_dark, want, delta * 4.0)
	_env.ambient_light_energy = lerpf(_ambient0, 0.22, _dark)


# ------------------------------------------------------------------ hunters (host)

func _hunt(delta: float) -> void:
	var bm := BugManager.instance
	if bm == null or not is_instance_valid(bm) or GameState.phase != GameState.Phase.BUILD:
		return
	_hunters = _hunters.filter(func(b: Bug) -> bool: return is_instance_valid(b) and b.is_alive())
	_inside_hunters = _inside_hunters.filter(func(b: Bug) -> bool: return is_instance_valid(b) and b.is_alive())
	var outside: Array[int] = []
	var inside: Array[int] = []
	for peer: int in Expedition.down:
		var pl := Expedition.player_node(peer)
		if pl == null or pl.is_downed():
			continue
		if is_inside(pl):
			inside.append(peer)
		else:
			outside.append(peer)
	_retarget_t -= delta
	if _retarget_t <= 0.0:
		_retarget_t = 0.5
		_retarget(_hunters, outside)
		_retarget(_inside_hunters, inside)
	if outside.is_empty() and inside.is_empty():
		_hunt_t = 0.0
		return
	_hunt_t += delta
	if _hunt_t < BlastRules.hunt_gap(set_count(), lit()):
		return
	_hunt_t = 0.0
	var riders := maxi(NetworkManager.players.size(), 1)
	var room := BlastRules.max_hunters(riders) - _hunters.size() - _inside_hunters.size()
	var cid := _nearest_cliff()
	var k := randi()
	if not outside.is_empty():
		var n := mini(BlastRules.hunt_pack(outside.size(), lit()), room)
		for i in n:
			var kind: StringName = BlastRules.HUNTERS[(k + i) % BlastRules.HUNTERS.size()]
			var pos := mouth + out * (0.8 + i * 1.2) + out.cross(Vector3.UP) * randf_range(-1.5, 1.5)
			var b := bm.spawn_at(kind, cid, 0, mouth.z, 0.0, Bug.State.CROSSING, pos) as Bug
			if b == null:
				continue
			b.hunt_peer = outside[(k + i) % outside.size()]
			b.hunt_home = mouth
			b.floor_bug = true
			_hunters.append(b)
			room -= 1
		if n > 0:
			bm.rpc("_rumble", mouth, out, 0.8)
			_say_once("hunters")
	if not inside.is_empty() and room > 0 and tunnel != null:
		var hole := tunnel.hive_hole()
		var into := -out
		for i in mini(1 + (1 if lit() else 0), room):
			var kind: StringName = BlastRules.HUNTERS[(k + i + 1) % 2]
			var pos := hole - into * (0.6 + i * 1.0)
			var b := bm.spawn_at(kind, cid, 0, mouth.z, 0.0, Bug.State.CROSSING, pos) as Bug
			if b == null:
				continue
			b.hunt_peer = inside[(k + i) % inside.size()]
			b.hunt_home = hole
			_inside_hunters.append(b)


## Point hunters at someone where they are; nobody left there: home they go.
func _retarget(list: Array[Bug], peers: Array[int]) -> void:
	for b in list:
		if peers.has(b.hunt_peer):
			continue
		b.hunt_peer = peers[randi() % peers.size()] if not peers.is_empty() else -1


func _nearest_cliff() -> int:
	var best := 0
	var best_d := INF
	for a in RopeAnchor.all():
		var d := a.bottom.distance_to(mouth)
		if d < best_d:
			best_d = d
			best = a.cliff_id
	return best


# ------------------------------------------------------------------ the blast

func _detonate() -> void:
	# Who's caught, from where everyone is right now.
	var hits: Array = []
	for peer: int in Expedition.down:
		var pl := Expedition.player_node(peer)
		if pl == null:
			continue
		var inside := is_inside(pl)
		var d := Vector2(pl.global_position.x - mouth.x, pl.global_position.z - mouth.z).length()
		var dmg := BlastRules.blast_damage(d, inside)
		if dmg > 0.0:
			hits.append([pl, dmg])
	for b in _hunters:
		if is_instance_valid(b) and b.is_alive() and b.global_position.distance_to(mouth) < BlastRules.HURT_RADIUS:
			b.health.take_damage(999999.0, "dynamite", -1)
	for b in _inside_hunters:
		if is_instance_valid(b):
			b.queue_free()
	_hunters.clear()
	_inside_hunters.clear()
	blown = true
	fuse_left = -1.0
	dropped.clear()
	_blow.rpc()
	_broadcast()
	var buried := false
	for h: Array in hits:
		buried = buried or float(h[1]) > 1000.0
		var pl: Player = h[0]
		get_tree().create_timer(0.6).timeout.connect(func() -> void:
			if is_instance_valid(pl):
				pl.net.server_damage(float(h[1])))
	director._event.rpc("blast")
	if buried:
		get_tree().create_timer(4.0).timeout.connect(func() -> void: director._event.rpc("buried"))
	Expedition.risk_enabled = true
	director.blast_done()


## Every peer: the tunnel goes up. Out of the set first if you're in it, then
## the flash, the fireball out of the mouth, rock and timber everywhere, a wall
## of dust, the shake; the portal and the set are gone and rubble fills the mouth.
@rpc("authority", "call_local", "reliable")
func _blow() -> void:
	blown = true
	print("[ch7] BOOM at %s" % str(mouth.snapped(Vector3.ONE * 0.1)))
	var p := _me()
	if p != null and is_inside(p):
		p.global_position = outside_stand()
		p.velocity = Vector3.ZERO
	if not cliffs.sealed.has(main):
		cliffs.sealed.append(main)
	BlastFx.play(world, mouth, out)
	if p != null:
		var d := p.global_position.distance_to(mouth)
		p.add_shake(BlastRules.blast_shake(d))
		get_tree().create_timer(0.5).timeout.connect(func() -> void:
			if is_instance_valid(p):
				p.add_shake(BlastRules.blast_shake(d) * 0.8))
	get_tree().create_timer(0.3).timeout.connect(func() -> void:
		if portal != null and is_instance_valid(portal):
			portal.queue_free()
		if tunnel != null and is_instance_valid(tunnel):
			tunnel.queue_free()
		var rubble := Rubble.new()
		rubble.name = "TunnelRubble"
		rubble.settle = true
		world.add_child(rubble)
		rubble.global_transform = Transform3D(Basis(Vector3.UP, atan2(out.x, out.z)), mouth))
	_refresh_piles()
	for id: Variant in _dropped_nodes:
		var n: Node = _dropped_nodes[id]
		if is_instance_valid(n):
			n.queue_free()
	_dropped_nodes.clear()


## Every peer: a chapter after Down the Hole: the main tunnel stays blown shut.
static func seal_main(w: Node3D) -> void:
	var cl := w.get("cliffs") as CliffBuilder
	if cl == null:
		return
	var m := cl.main_tunnel()
	if not cl.sealed.has(m):
		cl.sealed.append(m)
	var tn := cl.tunnel(m)
	var o: Vector3 = tn[1]
	o.y = 0.0
	var at: Vector3 = tn[0]
	at.y = cl.floor_height(at.x, at.z)
	var rubble := Rubble.new()
	rubble.name = "TunnelRubble"
	w.add_child(rubble)
	rubble.global_transform = Transform3D(Basis(Vector3.UP, atan2(o.x, o.z)), at)


# ------------------------------------------------------------------ tracker

## [status text, kind] for the StoryTracker.
func status() -> Array:
	if blown:
		return ["Main tunnel blown shut", "good"]
	if lit():
		return ["FUSE LIT: %s  ·  get above the lip!" % BlastRules.fuse_text(fuse_left), "bad"]
	if armed():
		return ["All %d charges set: light the fuse at the tunnel mouth!" % needed, "warn"]
	var c := carried()
	var text := "Charges set: %d / %d" % [set_count(), needed]
	if c > 0:
		text += "  ·  %d crate%s on the way" % [c, "" if c == 1 else "s"]
	elif set_count() == 0:
		text += "  ·  dynamite at the rope foot"
	return [text, "warn" if set_count() > 0 or c > 0 else "info"]


# ------------------------------------------------------------------ meshes

## One crate of railroad dynamite: pale boards, a red band, black stencil.
static func crate_mesh(st: SurfaceTool, xf: Transform3D) -> void:
	var wood := Color("#C79A62")
	MeshKit.add_box(st, xf * Transform3D(Basis(), Vector3(0, 0.3, 0)), Vector3(0.9, 0.6, 0.6), wood)
	for x: float in [-0.43, 0.43]:
		MeshKit.add_box(st, xf * Transform3D(Basis(), Vector3(x, 0.3, 0)), Vector3(0.06, 0.62, 0.62), Palette.WOOD_DARK)
	MeshKit.add_box(st, xf * Transform3D(Basis(), Vector3(0, 0.36, 0)), Vector3(0.8, 0.16, 0.615), Color("#B8352A"))
	MeshKit.add_box(st, xf * Transform3D(Basis(), Vector3(0, 0.36, 0)), Vector3(0.5, 0.05, 0.62), Color("#1E1412"))
	MeshKit.add_box(st, xf * Transform3D(Basis(), Vector3(0, 0.61, 0)), Vector3(0.92, 0.04, 0.5), wood.darkened(0.15))


## A charge on the wall: six red sticks strapped together, a cap and a cord.
static func charge_mesh() -> ArrayMesh:
	var st := MeshKit.begin()
	for i in 6:
		var x := -0.15 + (i % 3) * 0.15
		var z := -0.32 if i < 3 else -0.2
		MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(x, 0.75, z)), 0.07, 0.07, 0.55, 8, Color("#C8352A"))
	for y: float in [0.6, 0.9]:
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, y, -0.26)), Vector3(0.5, 0.05, 0.3), Color("#3A2A1E"))
	MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, 1.07, -0.26)), 0.04, 0.04, 0.12, 6, Palette.METAL)
	MeshKit.add_limb(st, Vector3(0, 1.1, -0.26), Vector3(0.05, 0.55, 0.15), 0.018, Color("#2B1B17"), 3)
	return MeshKit.finish(st)


## A chalk X and a red-flag peg marking where a charge goes.
static func chalk_mark_mesh() -> ArrayMesh:
	var st := MeshKit.begin()
	for a: float in [0.7, -0.7]:
		MeshKit.add_box(st, Transform3D(Basis(Vector3.BACK, a), Vector3(0, 1.25, -0.42)), Vector3(0.75, 0.07, 0.03), Color("#F4EEDC"), 0.0, null, 0.45)
	MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0.0, 0.3, 0.1)), 0.02, 0.02, 0.6, 5, Palette.WOOD)
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(0.12, 0.52, 0.1)), Vector3(0.22, 0.14, 0.01), Color("#E0483C"))
	return MeshKit.finish(st)


# ------------------------------------------------------------------ debug views

func _debug_view() -> void:
	if not GameState.debug_enabled() or GameState.flag_value("--ch7view") == "":
		return
	var view := GameState.flag_value("--ch7view")
	var p: Player = null
	var until := Time.get_ticks_msec() + 20000
	while p == null and Time.get_ticks_msec() < until:
		await get_tree().process_frame
		p = _me()
	if p == null:
		return
	for i in 40:
		await get_tree().process_frame
	var me := multiplayer.get_unique_id()
	var side := out.cross(Vector3.UP).normalized()
	p.set("_trip", true)
	match view:
		"portal", "hunt":
			var at := mouth + out * 13.0 + side * 5.0
			_place(p, Vector3(at.x, cliffs.floor_height(at.x, at.z) + 0.1, at.z), mouth + Vector3.UP * 2.5)
			if view == "hunt" and multiplayer.is_server():
				Expedition.add_to_backpack(me, {BlastRules.ITEM: 1})
				_hunt_t = 99.0
		"pile":
			var a := RopeAnchor.of(p.cliff_id)
			if a != null:
				var pile_at := piles[0].global_position
				for pl in piles:
					if pl.name == "CratePile%d" % p.cliff_id:
						pile_at = pl.global_position
				_place(p, pile_at + (a.foot_stand - pile_at).normalized() * 3.0 + Vector3.UP * 0.1 + a.inward * 1.5, pile_at + Vector3.UP * 0.4)
		"interior":
			_place(p, tunnel.entrance_stand() + Vector3.UP * 0.05, tunnel.to_global(MineTunnel.local_at(30.0, 0.0, 1.4)))
			if multiplayer.is_server():
				for i in mini(2, needed):
					charges[i] = true
				_broadcast()
		"chamber":
			_place(p, tunnel.to_global(MineTunnel.local_at(27.0, 0.6, 0.1)), tunnel.to_global(MineTunnel.local_at(41.0, 0.0, 1.0)))
			if multiplayer.is_server():
				_hunt_t = 99.0
				Expedition.add_to_backpack(me, {BlastRules.ITEM: 1})
		"charge":
			if multiplayer.is_server():
				charges[0] = true
				Expedition.add_to_backpack(me, {BlastRules.ITEM: 1})
				_broadcast()
			await get_tree().create_timer(0.3).timeout
			var s := tunnel.spots[mini(1, tunnel.spots.size() - 1)]
			var look := s.to_global(Vector3(0, 0.95, -0.2))
			var stand := s.to_global(Vector3(-0.9, 0.0, 2.1))
			_place(p, stand + Vector3.UP * 0.1, look)
		"fuse":
			if multiplayer.is_server():
				charges.fill(true)
				_broadcast()
			var at := mouth + out * 7.5 - side * 1.5
			_place(p, Vector3(at.x, cliffs.floor_height(at.x, at.z) + 0.1, at.z), portal.fuse_box.global_position + Vector3.UP * 0.5)
			await get_tree().create_timer(1.0).timeout
			if GameState.has_flag("--ch7light"):
				request_light()
		"blast", "sealed":
			if multiplayer.is_server():
				charges.fill(true)
				_broadcast()
			p.set("_trip", false)
			# Up on the opposite lip (or your own), looking down at the mouth.
			var cid := p.cliff_id
			for a in RopeAnchor.all():
				if a.cliff_id != _nearest_cliff():
					cid = a.cliff_id
			var lip := cliffs.plateau_point(cid, 1.5, mouth.z + 22.0)
			_place(p, lip + Vector3.UP * 0.2, mouth + Vector3.UP * 3.0)
			if multiplayer.is_server():
				fuse_left = _fuse_total
				_broadcast()
	print("[ch7] view %s at %s" % [view, str(p.global_position.snapped(Vector3.ONE * 0.1))])


func _place(p: Player, at: Vector3, look: Vector3) -> void:
	p.global_position = at
	p.velocity = Vector3.ZERO
	var d := look - (at + Vector3.UP * 1.6)
	p.rotation.y = atan2(-d.x, -d.z)
	p.head.rotation.x = atan2(d.y, Vector2(d.x, d.z).length())


# ------------------------------------------------------------------ props

## The main tunnel's mouth, shored up: a heavy timber portal with a header
## board, rails running out onto the floor, a lantern on a post, a rock hump
## behind it (on the fissure maps the adit goes into it), and the fuse spool
## on its stake beside it. E in the dark opening takes you in.
class MinePortal extends StaticBody3D:
	var director: DownTheHole
	var fuse_box: FuseBox
	var _beacon: MeshInstance3D

	func _ready() -> void:
		collision_layer = WorldLayout.LAYER_WORLD
		collision_mask = 0
		var mi := MeshInstance3D.new()
		mi.mesh = _mesh()
		mi.material_override = Materials.toon(0.03)
		add_child(mi)
		var label := Label3D.new()
		label.text = "C.R.R. SURVEY ADIT No. 3\nKEEP OUT"
		label.font_size = 64
		label.pixel_size = 0.006
		label.modulate = Color("#F2E3C2")
		label.outline_size = 10
		label.outline_modulate = Color("#2B1B17")
		label.position = Vector3(0, 4.62, 1.04)
		add_child(label)
		var col := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(4.4, 3.9, 0.5)
		col.shape = bs
		col.position = Vector3(0, 1.95, 0.6)
		add_child(col)
		var lamp := OmniLight3D.new()
		lamp.light_color = Color("#FFC27A")
		lamp.light_energy = 1.6
		lamp.omni_range = 7.0
		lamp.position = Vector3(3.4, 2.4, 2.6)
		add_child(lamp)
		_beacon = MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.25
		cyl.bottom_radius = 0.5
		cyl.height = 40.0
		cyl.radial_segments = 10
		cyl.cap_top = false
		cyl.cap_bottom = false
		_beacon.mesh = cyl
		var bm := StandardMaterial3D.new()
		bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		bm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		bm.cull_mode = BaseMaterial3D.CULL_DISABLED
		bm.albedo_color = Color(Color("#E0483C"), 0.18)
		_beacon.material_override = bm
		_beacon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_beacon.position = Vector3(-3.4, 20.0, 3.0)
		add_child(_beacon)
		fuse_box = FuseBox.new()
		fuse_box.name = "FuseBox"
		fuse_box.director = director
		add_child(fuse_box)
		fuse_box.position = Vector3(3.6, 0.0, 3.4)

	func light_fuse(total: float) -> void:
		fuse_box.burn(total, to_global(Vector3(0, 0.05, 0.9)))

	func interact_prompt() -> String:
		if director == null or director.blown:
			return ""
		if director.lit():
			return "Main Tunnel  -  THE FUSE IS LIT\nGet away from here!"
		return "Main Tunnel  -  charges set %d / %d\nE: go in" % [director.set_count(), director.needed]

	func local_interact(holding: bool) -> void:
		if not holding and director != null and not director.lit():
			director.enter_tunnel()

	func _mesh() -> ArrayMesh:
		var st := MeshKit.begin()
		var rng := RandomNumberGenerator.new()
		rng.seed = 33
		var wood := Palette.WOOD.darkened(0.05)
		var dark := Palette.WOOD_DARK
		var iron := Palette.METAL.darkened(0.3)
		# The hump of rock the adit is cut into.
		MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(0, 0.6, -4.3)), Vector3(6.2, 5.6, 4.0), 7, 14, Palette.ROCK_B.darkened(0.15), 0.12, rng)
		# The black inside.
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 2.0, 0.42)), Vector3(4.3, 4.0, 0.05), Color("#0A0605"))
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 2.0, -0.4)), Vector3(4.3, 4.0, 1.6), Color("#0A0605"))
		# Posts, cap, header board, knee braces.
		for sx: float in [-2.35, 2.35]:
			MeshKit.add_box(st, Transform3D(Basis(Vector3.FORWARD, sx * 0.012), Vector3(sx, 2.1, 0.75)), Vector3(0.42, 4.2, 0.42), wood, 0.03, rng)
			MeshKit.add_box(st, Transform3D(Basis(), Vector3(sx, 0.15, 0.75)), Vector3(0.62, 0.3, 0.62), Palette.ROCK_B, 0.05, rng)
			MeshKit.add_limb(st, Vector3(sx, 3.2, 0.95), Vector3(sx * 0.62, 4.05, 0.95), 0.09, dark, 5)
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 4.3, 0.75)), Vector3(5.6, 0.46, 0.5), wood.lightened(0.05), 0.03, rng)
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 4.62, 0.98)), Vector3(3.6, 0.62, 0.06), Color("#3A2418"))
		# Old lagging nailed across the top of the opening, one board hanging.
		MeshKit.add_box(st, Transform3D(Basis(Vector3.BACK, 0.05), Vector3(-0.6, 3.8, 0.98)), Vector3(2.6, 0.2, 0.05), dark, 0.02, rng)
		MeshKit.add_box(st, Transform3D(Basis(Vector3.BACK, 0.9), Vector3(1.4, 3.3, 1.0)), Vector3(1.6, 0.2, 0.05), dark, 0.02, rng)
		# Rails out of the mouth onto the floor.
		var z := -0.4
		while z < 7.0:
			MeshKit.add_box(st, Transform3D(Basis(Vector3.UP, rng.randf_range(-0.06, 0.06)), Vector3(0, 0.05, z)), Vector3(1.5, 0.1, 0.22), dark, 0.02, rng)
			z += 0.75
		for sx: float in [-0.55, 0.55]:
			MeshKit.add_box(st, Transform3D(Basis(), Vector3(sx, 0.15, 3.3)), Vector3(0.07, 0.1, 7.4), iron)
		# Lantern post.
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(3.4, 1.4, 2.6)), Vector3(0.16, 2.8, 0.16), wood)
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(3.15, 2.75, 2.6)), Vector3(0.6, 0.1, 0.1), wood)
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(2.9, 2.45, 2.6)), Vector3(0.22, 0.3, 0.22), iron)
		MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(2.9, 2.45, 2.6)), Vector3(0.12, 0.13, 0.12), 3, 6, Palette.GLOW_YELLOW, 0.0, null, 1.0)
		# A danger board on a stake, and a couple of empty crates.
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(-3.4, 0.7, 2.2)), Vector3(0.1, 1.4, 0.1), wood)
		MeshKit.add_box(st, Transform3D(Basis(Vector3.BACK, 0.08), Vector3(-3.4, 1.35, 2.25)), Vector3(1.0, 0.5, 0.04), Color("#B8352A"))
		DownTheHole.crate_mesh(st, Transform3D(Basis(Vector3.UP, 0.4), Vector3(-3.0, 0.0, 0.9)))
		return MeshKit.finish(st)


## The fuse spool on its stake by the portal: once every charge is set, E
## lights it, and a spark runs down the cord into the tunnel.
class FuseBox extends StaticBody3D:
	var director: DownTheHole
	var _spark: MeshInstance3D
	var _light: OmniLight3D
	var _tw: Tween

	func _ready() -> void:
		collision_layer = WorldLayout.LAYER_STRUCTURE
		collision_mask = 0
		var st := MeshKit.begin()
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.5, 0)), Vector3(0.12, 1.0, 0.12), Palette.WOOD)
		MeshKit.add_cylinder(st, Transform3D(Basis(Vector3.FORWARD, PI * 0.5), Vector3(0, 0.75, 0.12)), 0.26, 0.26, 0.22, 12, Color("#3A2418"))
		MeshKit.add_cylinder(st, Transform3D(Basis(Vector3.FORWARD, PI * 0.5), Vector3(0, 0.75, 0.12)), 0.32, 0.32, 0.04, 12, Palette.WOOD_DARK)
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(0.0, 0.05, 0.3)), Vector3(0.5, 0.1, 0.4), Color("#C79A62"))
		var mi := MeshInstance3D.new()
		mi.mesh = MeshKit.finish(st)
		mi.material_override = Materials.toon(0.02)
		add_child(mi)
		var col := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(0.8, 1.2, 0.8)
		col.shape = bs
		col.position = Vector3(0, 0.6, 0.1)
		add_child(col)
		_spark = MeshInstance3D.new()
		var sph := SphereMesh.new()
		sph.radius = 0.09
		sph.height = 0.18
		_spark.mesh = sph
		var sm := StandardMaterial3D.new()
		sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		sm.albedo_color = Color("#FFE36A")
		_spark.material_override = sm
		_spark.visible = false
		_spark.top_level = true
		add_child(_spark)
		_light = OmniLight3D.new()
		_light.light_color = Color("#FFB040")
		_light.light_energy = 0.0
		_light.omni_range = 3.5
		_spark.add_child(_light)

	func burn(total: float, to: Vector3) -> void:
		_spark.visible = true
		_spark.global_position = global_position + Vector3(0, 0.75, 0.12)
		_light.light_energy = 2.5
		Audio.play_at(&"zippo_strike", global_position, 0.0)
		Audio.play_at(&"cig_light", global_position, -2.0)
		_tw = create_tween()
		_tw.tween_property(_spark, "global_position", to, total)

	func _process(_delta: float) -> void:
		if _spark != null and _spark.visible:
			var f := 0.7 + randf() * 0.6
			_spark.scale = Vector3.ONE * f
			_light.light_energy = 1.8 + randf() * 1.6

	func interact_prompt() -> String:
		if director == null or director.blown:
			return ""
		if director.lit():
			return "Fuse  -  %s left\nRUN!" % BlastRules.fuse_text(director.fuse_left)
		if not director.armed():
			return "Fuse Spool  -  set every charge first (%d / %d)" % [director.set_count(), director.needed]
		return "Fuse Spool  -  every charge set\nE: light the fuse (%d s)" % int(director._fuse_total)

	func local_interact(holding: bool) -> void:
		if not holding and director != null and director.armed() and not director.lit():
			director.request_light()


## The dynamite at a rope winch's foot: a pallet with what's left of the job's
## crates stacked on it. E puts one in your backpack.
class CratePile extends StaticBody3D:
	var director: DownTheHole
	var _mi: MeshInstance3D
	var _shown := -1

	func _ready() -> void:
		collision_layer = WorldLayout.LAYER_STRUCTURE
		collision_mask = 0
		_mi = MeshInstance3D.new()
		_mi.material_override = Materials.toon(0.02)
		add_child(_mi)
		var col := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(2.0, 1.4, 1.4)
		col.shape = bs
		col.position = Vector3(0, 0.7, 0)
		add_child(col)
		show_count(0)

	func show_count(n: int) -> void:
		if n == _shown:
			return
		_shown = n
		var st := MeshKit.begin()
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.06, 0)), Vector3(2.0, 0.12, 1.4), Palette.WOOD_DARK)
		var spots: Array[Vector3] = [Vector3(-0.48, 0.12, -0.32), Vector3(0.48, 0.12, -0.32), Vector3(-0.48, 0.12, 0.34),
				Vector3(0.48, 0.12, 0.34), Vector3(0.0, 0.72, -0.32), Vector3(0.0, 0.72, 0.34)]
		for i in mini(n, spots.size()):
			DownTheHole.crate_mesh(st, Transform3D(Basis(Vector3.UP, 0.05 * float(i % 3 - 1)), spots[i]))
		# A painted sign on a stake.
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(1.2, 0.7, 0.0)), Vector3(0.08, 1.4, 0.08), Palette.WOOD)
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(1.2, 1.25, 0.05)), Vector3(0.7, 0.35, 0.04), Color("#B8352A"))
		_mi.mesh = MeshKit.finish(st)

	func interact_prompt() -> String:
		if director == null or director.blown:
			return "Dynamite Pallet  -  empty"
		var n := director.on_pile()
		if n <= 0:
			return "Dynamite Pallet  -  every crate's out (%d / %d set)" % [director.set_count(), director.needed]
		return "Dynamite Crates  -  %d left  ·  weight %d each\nE: into your backpack" % [n, Backpack.weight_of(BlastRules.ITEM)]

	func local_interact(holding: bool) -> void:
		if not holding and director != null:
			director.request_take()


## A crate a downed carrier dropped on the floor.
class DroppedCrate extends StaticBody3D:
	var crate_id := 0
	var director: DownTheHole

	func _ready() -> void:
		collision_layer = WorldLayout.LAYER_TRAP
		collision_mask = 0
		var st := MeshKit.begin()
		DownTheHole.crate_mesh(st, Transform3D(Basis(Vector3.FORWARD, 0.12) * Basis(Vector3.UP, 0.6), Vector3.ZERO))
		var mi := MeshInstance3D.new()
		mi.mesh = MeshKit.finish(st)
		mi.material_override = Materials.toon(0.02)
		add_child(mi)
		var col := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(1.0, 0.8, 0.8)
		col.shape = bs
		col.position = Vector3(0, 0.4, 0)
		add_child(col)

	func interact_prompt() -> String:
		return "Dropped Dynamite Crate\nE: into your backpack"

	func local_interact(holding: bool) -> void:
		if not holding and director != null:
			director.request_pick(crate_id)


## The collapsed mouth: boulders, split timbers and a slope of rock and dust
## heaped against the wall (collidable). `settle`: it drops in with the blast.
class Rubble extends StaticBody3D:
	var settle := false

	func _ready() -> void:
		collision_layer = WorldLayout.LAYER_WORLD
		collision_mask = 0
		var mi := MeshInstance3D.new()
		mi.mesh = mesh()
		mi.material_override = Materials.toon(0.03)
		add_child(mi)
		for b: Array in [[Vector3(0, 1.2, 0.6), Vector3(7.0, 2.4, 3.2)], [Vector3(0, 2.6, -0.4), Vector3(5.2, 2.0, 2.0)]]:
			var col := CollisionShape3D.new()
			var bs := BoxShape3D.new()
			bs.size = b[1]
			col.shape = bs
			col.position = b[0]
			add_child(col)
		if settle:
			mi.position.y = 3.5
			var tw := create_tween()
			tw.tween_property(mi, "position:y", 0.0, 0.9).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)

	static func mesh() -> ArrayMesh:
		var st := MeshKit.begin()
		var rng := RandomNumberGenerator.new()
		rng.seed = 1907
		var cols := [Palette.ROCK_B, Palette.ROCK_A.darkened(0.1), Color("#7E4434"), Palette.ROCK_B.darkened(0.2)]
		# The slope.
		MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(0, 0.2, 0.4)), Vector3(4.6, 3.4, 3.4), 6, 14, Color("#8A5A3E"), 0.15, rng)
		for k in 26:
			var a := rng.randf_range(-1.0, 1.0)
			var p := Vector3(a * 3.8, rng.randf_range(0.4, 3.6) * (1.0 - absf(a) * 0.5), rng.randf_range(-0.6, 2.8))
			var s := rng.randf_range(0.45, 1.25)
			MeshKit.add_ellipsoid(st, Transform3D(Basis(Vector3.UP, rng.randf() * TAU), p), Vector3(s, s * 0.75, s * 0.9), 4, 7,
					cols[rng.randi() % cols.size()], 0.25, rng)
		# Split timbers sticking out.
		for k in 5:
			var p := Vector3(rng.randf_range(-2.6, 2.6), rng.randf_range(0.6, 2.4), rng.randf_range(0.8, 2.2))
			var q := p + Vector3(rng.randf_range(-1.2, 1.2), rng.randf_range(-0.6, 0.9), rng.randf_range(0.6, 1.6))
			MeshKit.add_limb(st, p, q, rng.randf_range(0.1, 0.17), Palette.WOOD_DARK.darkened(0.25), 5)
		# A rail bent up out of it.
		MeshKit.add_limb(st, Vector3(0.55, 0.15, 4.0), Vector3(0.7, 0.9, 2.6), 0.05, Palette.METAL.darkened(0.3), 4)
		MeshKit.add_limb(st, Vector3(0.7, 0.9, 2.6), Vector3(1.1, 2.1, 2.0), 0.05, Palette.METAL.darkened(0.3), 4)
		# Scorching on the floor.
		MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(0, 0.0, 4.0)), Vector3(6.0, 0.03, 4.5), 3, 14, Color("#2E2420"))
		return MeshKit.finish(st)
