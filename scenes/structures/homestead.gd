class_name Homestead
extends StaticBody3D
## A player's base core: an enterable log cabin. Breachers chew on it; GameState
## holds the actual HP so both players see both bars, and losing either Homestead
## loses the run. A ledger desk inside sells house upgrades (boarding up the
## windows, reinforcing the walls, a second storey with a balcony, a lookout
## storey with a roof deck); each storey adds two mounts for house turrets.

## Upgrade id -> [name, cost, description]. Floors must be bought in order.
const UPGRADES: Array[Dictionary] = [
	{"id": &"patch", "name": "Patch the walls", "cost": {&"scrap": 25}, "desc": "Repairs 100 HP."},
	{"id": &"board", "name": "Board up the windows", "cost": {&"scrap": 40}, "desc": "Bugs do 30% less damage to the house."},
	{"id": &"reinforce", "name": "Reinforce the walls", "cost": {&"scrap": 80, &"chitin": 10}, "desc": "Iron bands and a stone skirt: +250 max HP."},
	{"id": &"floor2", "name": "Build a second floor", "cost": {&"scrap": 120, &"chitin": 15}, "desc": "Adds a storey and a front balcony with 2 house turret mounts."},
	{"id": &"floor3", "name": "Build a lookout floor", "cost": {&"scrap": 180, &"chitin": 30}, "desc": "Adds a top storey and a railed roof deck with 2 more mounts. A lookout up top spots for your turrets: +8% range for every turret on this cliff."},
	{"id": &"porch", "name": "Build a shaded porch", "cost": {&"scrap": 60}, "desc": "Wider covered wings either side of the porch, with benches. Rest under it and your health comes back three times as fast."},
	{"id": &"workshop", "name": "Build a workshop", "cost": {&"scrap": 100, &"chitin": 12}, "desc": "A lean-to shed on the back of the house with a crafting bench: combine turret parts into new turrets."},
	{"id": &"tower", "name": "Build a zip-line tower", "cost": {&"scrap": 220, &"chitin": 40}, "desc": "A tall lookout tower on the roof deck. Once both houses have one, a zip line joins them across the canyon."},
]
const BOARDED_DAMAGE := 0.7
const REINFORCE_HP := 250.0
const PATCH_HP := 100.0
## House turrets only shoot bugs this close to their house.
const GUARD_RADIUS := 20.0

var cliff_id: int = 0
var radius: float = 4.5
var floors := 1
var boarded := false
var reinforced := false
var tower := false
var workshop := false
var porch := false
## Cliffs whose house has the shaded porch (PlayerVitals heals faster on it).
static var porch_cliffs: Dictionary = {}
## Health regen multiplier while resting under a shaded porch.
const PORCH_REGEN := 3.0
## Cliffs whose house has the lookout floor (turrets there reach further). Kept
## static so Turret.range_multiplier() needn't search for the house every shot.
static var lookout_cliffs: Dictionary = {}
## Turret range from a cliff's lookout floor.
const LOOKOUT_RANGE := 1.08
var _ladder: Area3D
var _handle: ZipHandle
var _hit_cooldown := 0.0
var _mi: MeshInstance3D
var _col: CollisionShape3D
var _lights: Array[OmniLight3D] = []
var _flag: MeshInstance3D
var _flag_t := 0.0
var _flag_acc := 1.0
var _chair: MeshInstance3D
var _smoke_at := Vector3.ZERO
var _smoke_t := 0.0


static func of(cid: int) -> Homestead:
	for n: Node in Engine.get_main_loop().get_nodes_in_group("homesteads"):
		if (n as Homestead).cliff_id == cid:
			return n as Homestead
	return null


func _ready() -> void:
	lookout_cliffs.erase(cliff_id) # a new run: no lookout yet
	porch_cliffs.erase(cliff_id)
	add_to_group("structures")
	add_to_group("homesteads")
	_mi = MeshInstance3D.new()
	_mi.material_override = Materials.toon()
	add_child(_mi)
	_col = CollisionShape3D.new()
	add_child(_col)
	var ledger := HouseLedger.new()
	ledger.name = "Ledger"
	ledger.home = self
	ledger.position = HouseBuilder.ledger_position()
	add_child(ledger)
	var chest := StorageChest.new()
	chest.name = "Chest"
	chest.home = self
	chest.position = HouseBuilder.chest_position()
	chest.rotation.y = -PI * 0.5 # lock faces into the room
	add_child(chest)
	# The shared deposit box, outside against the side wall.
	var box := DepositBox.new()
	box.name = "DepositBox"
	box.home = self
	box.position = HouseBuilder.deposit_box_position()
	box.rotation.y = PI * 0.5
	add_child(box)
	_rebuild()


func _process(delta: float) -> void:
	_hit_cooldown = maxf(_hit_cooldown - delta, 0.0)
	_animate_flag(delta)
	if _chair != null:
		# Rocks gently on its own, harder in the wind.
		var w := 2.0 if GameState.weather == Weather.Kind.WINDY else 1.0
		_chair.rotation.x = sin(_flag_t * 1.6) * 0.09 * w
	_smoke_t -= delta
	if _smoke_t <= 0.0:
		_smoke_t = 0.7
		_puff()


## A team flag made of strips so it can ripple.
const FLAG_STRIPS := 8


func _make_flag() -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.material_override = Materials.toon(0.0)
	mi.position = HouseBuilder.flag_anchor()
	return mi


func _animate_flag(delta: float) -> void:
	if _flag == null:
		return
	_flag_t += delta
	# The strips are rebuilt as a new mesh: 30 times a second is smooth enough for cloth.
	_flag_acc += delta
	if _flag_acc < 1.0 / 30.0:
		return
	_flag_acc = 0.0
	var wind := 2.2 if GameState.weather == Weather.Kind.WINDY or GameState.weather == Weather.Kind.DUST_STORM else 1.0
	var st := MeshKit.begin()
	var team := Palette.team_color(cliff_id)
	var w := 1.4
	var h := 0.85
	var prev_top := Vector3.ZERO
	var prev_bot := Vector3(0, -h, 0)
	for i in FLAG_STRIPS:
		var t := float(i + 1) / FLAG_STRIPS
		var wave := sin(_flag_t * 5.0 * wind - t * 5.0) * 0.16 * t * wind
		var droop := -0.15 * t * (1.0 / wind)
		var top := Vector3(t * w, droop, wave)
		var bot := Vector3(t * w, -h + droop, wave + 0.03 * t)
		var c := team if i % 4 != 3 else team.lightened(0.25)
		MeshKit.quad(st, prev_top, top, bot, prev_bot, Vector3.FORWARD, MeshKit.vcol(c))
		MeshKit.quad(st, prev_top, prev_bot, bot, top, Vector3.BACK, MeshKit.vcol(c))
		prev_top = top
		prev_bot = bot
	_flag.mesh = MeshKit.finish(st)


## Chimney smoke: soft grey puffs that drift up and away with the wind.
func _puff() -> void:
	var p := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.25
	sphere.height = 0.5
	sphere.radial_segments = 8
	sphere.rings = 4
	p.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.85, 0.83, 0.82, 0.55)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	p.material_override = mat
	add_child(p)
	p.position = _smoke_at
	var drift := Vector3(randf_range(-0.3, 0.3), 3.0, randf_range(-0.3, 0.3))
	if GameState.weather == Weather.Kind.WINDY:
		drift += Vector3(0, -1.5, WeatherFx.wind_sign() * 3.0)
	var tw := p.create_tween().set_parallel(true)
	tw.tween_property(p, "position", p.position + drift, 3.5)
	tw.tween_property(p, "scale", Vector3.ONE * 3.0, 3.5)
	tw.tween_property(mat, "albedo_color:a", 0.0, 3.5)
	tw.chain().tween_callback(p.queue_free)


func _rebuild() -> void:
	var mesh := HouseBuilder.build(100 + cliff_id, Palette.team_color(cliff_id), floors, boarded, reinforced, false, tower, cliff_id)
	_mi.mesh = mesh
	_col.shape = HouseBuilder.build(100 + cliff_id, Color.WHITE, floors, boarded, reinforced, true, tower, cliff_id).create_trimesh_shape()
	_build_tower_bits()
	if _flag == null:
		_flag = _make_flag()
		add_child(_flag)
		_chair = MeshInstance3D.new()
		_chair.mesh = HouseBuilder.rocking_chair()
		_chair.material_override = Materials.toon(0.02)
		_chair.position = HouseBuilder.chair_spot()
		_chair.rotation.y = 0.5
		add_child(_chair)
	_smoke_at = HouseBuilder.chimney_top(floors)
	while _lights.size() < floors:
		var l := OmniLight3D.new()
		l.light_color = Color("#FFC27A")
		l.light_energy = 1.4
		l.omni_range = 6.0
		l.position = Vector3(0, HouseBuilder.H * _lights.size() + 2.4, 0)
		add_child(l)
		_lights.append(l)


## The tower's ladder zone and the zip-line handle (only once the tower is up).
## Is this world point under this house's shaded porch (front, -Z local)?
func under_porch(world_pos: Vector3) -> bool:
	if not porch:
		return false
	var p := to_local(world_pos)
	return absf(p.x) < HouseBuilder.W * 0.5 + 2.6 and p.z < -HouseBuilder.D * 0.5 + 0.3 and p.z > -HouseBuilder.D * 0.5 - 3.4 and p.y < 3.0


## The shaded porch wings, once bought: decks, posts, a plank awning and benches
## either side of the front porch.
func _build_porch() -> void:
	if not porch or get_node_or_null("PorchWings") != null:
		return
	var st := MeshKit.begin()
	var wood := Palette.WOOD
	var dark := Palette.WOOD_DARK
	var front := -HouseBuilder.D * 0.5
	for side: float in [-1.0, 1.0]:
		var cx := side * (HouseBuilder.W * 0.5 + 1.1)
		# Deck.
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(cx, 0.22, front - 1.5)), Vector3(2.4, 0.12, 3.0), wood.darkened(0.15))
		for i in 6:
			MeshKit.add_box(st, Transform3D(Basis(), Vector3(cx - 1.0 + i * 0.4, 0.29, front - 1.5)), Vector3(0.03, 0.02, 3.0), dark)
		# Posts and awning.
		for z: float in [front - 2.9, front - 0.1]:
			MeshKit.add_box(st, Transform3D(Basis(), Vector3(cx + side * 1.1, 1.45, z)), Vector3(0.14, 2.5, 0.14), dark)
		MeshKit.add_box(st, Transform3D(Basis(Vector3.RIGHT, 0.12), Vector3(cx, 2.75, front - 1.5)), Vector3(2.6, 0.08, 3.3), wood.lightened(0.05))
		for i in 5:
			MeshKit.add_box(st, Transform3D(Basis(Vector3.RIGHT, 0.12), Vector3(cx - 1.1 + i * 0.55, 2.8, front - 1.5)), Vector3(0.05, 0.03, 3.3), dark)
		# A bench.
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(cx, 0.68, front - 0.45)), Vector3(1.6, 0.08, 0.4), wood.lightened(0.1))
		for x: float in [-0.65, 0.65]:
			MeshKit.add_box(st, Transform3D(Basis(), Vector3(cx + x, 0.47, front - 0.45)), Vector3(0.08, 0.36, 0.34), dark)
	var mi := MeshInstance3D.new()
	mi.name = "PorchWings"
	mi.mesh = MeshKit.finish(st)
	mi.material_override = Materials.toon(0.02)
	add_child(mi)


## The Workshop shed on the back wall (+Z local), once it's bought.
func _build_workshop() -> void:
	if not workshop or get_node_or_null("Workshop") != null:
		return
	var w := Workshop.new()
	w.name = "Workshop"
	w.home = self
	# The shed's +Z end (its back) sits against the house's back wall; its open front faces out.
	w.position = Vector3(0, 0, HouseBuilder.D * 0.5 + 1.35)
	w.rotation.y = PI
	add_child(w)


func _build_tower_bits() -> void:
	if not tower or _ladder != null:
		return
	_ladder = Area3D.new()
	_ladder.collision_layer = 0
	_ladder.collision_mask = 0xFFFF
	var box := HouseBuilder.tower_ladder_box()
	var lcol := CollisionShape3D.new()
	var lshape := BoxShape3D.new()
	lshape.size = box.size
	lcol.shape = lshape
	lcol.position = box.get_center()
	_ladder.add_child(lcol)
	add_child(_ladder)
	_ladder.body_entered.connect(func(b: Node3D) -> void:
		if b is Player:
			(b as Player).ladder_count += 1
			(b as Player).ladder_top_y = to_global(HouseBuilder.zip_arrival()).y)
	_ladder.body_exited.connect(func(b: Node3D) -> void:
		if b is Player:
			(b as Player).ladder_count = maxi((b as Player).ladder_count - 1, 0))
	_handle = ZipHandle.new()
	_handle.home = self
	# Beside the ladder gap on the front rail, not in the way of climbers.
	_handle.position = HouseBuilder.zip_anchor() + Vector3(0.05, -1.5, 0.55)
	add_child(_handle)


## Global points for the zip line: the cable tie and the landing spot.
func zip_anchor_global() -> Vector3:
	return to_global(HouseBuilder.zip_anchor())


func zip_arrival_global() -> Vector3:
	return to_global(HouseBuilder.zip_arrival())


func mount_count() -> int:
	return HouseBuilder.mount_count(floors)


func mount_global(i: int) -> Vector3:
	return global_transform * HouseBuilder.MOUNTS[i]


## Is this upgrade still for sale (and unlocked)?
func can_offer(id: StringName) -> String:
	match id:
		&"patch":
			if GameState.homestead_hp[cliff_id] >= GameState.homestead_max[cliff_id] - 1.0:
				return "The house is in good shape."
		&"board":
			if boarded:
				return "Already boarded up."
		&"reinforce":
			if reinforced:
				return "Already reinforced."
		&"floor2":
			if floors >= 2:
				return "Already built."
		&"floor3":
			if floors >= 3:
				return "Already built."
			if floors < 2:
				return "Build the second floor first."
		&"tower":
			if tower:
				return "Already built."
			if floors < 3:
				return "Build the lookout floor first."
		&"workshop":
			if workshop:
				return "Already built."
		&"porch":
			if porch:
				return "Already built."
	return ""


## Host: someone bought an upgrade at the ledger.
func buy(peer_id: int, index: int) -> void:
	if not multiplayer.is_server() or index < 0 or index >= UPGRADES.size():
		return
	if not GameState.is_solo() and NetworkManager.cliff_of(peer_id) != cliff_id:
		Economy.notify(peer_id, "That's your partner's house. Spend on your own.")
		return
	var u: Dictionary = UPGRADES[index]
	var why := can_offer(u["id"])
	if why != "":
		Economy.notify(peer_id, why)
		return
	var cost := Perks.discount_cost(peer_id, &"carpenter", u["cost"]) # Perk: Carpenter
	if not Economy.spend(cliff_id, cost):
		Economy.notify(peer_id, "Not enough for %s (%s)." % [str(u["name"]).to_lower(), cost_text(cost)])
		return
	# Work out the new state and let _set_state apply it everywhere (the host
	# included), so every peer sees the change and rebuilds the house.
	var f := floors
	var b := boarded
	var r := reinforced
	var tw := tower
	var ws := workshop
	var pr := porch
	match u["id"]:
		&"patch":
			GameState.heal_homestead(cliff_id, PATCH_HP)
		&"board":
			b = true
		&"reinforce":
			r = true
			GameState.raise_homestead_max(cliff_id, REINFORCE_HP)
		&"floor2":
			f = 2
		&"floor3":
			f = 3
		&"tower":
			tw = true
		&"workshop":
			ws = true
		&"porch":
			pr = true
	_set_state.rpc(f, b, r, tw, ws, pr)
	Economy.notify_cliff(cliff_id, "Homestead: %s done." % str(u["name"]).to_lower())


@rpc("authority", "call_local", "reliable")
func _set_state(f: int, b: bool, r: bool, tw: bool = false, ws: bool = false, pr: bool = false) -> void:
	var changed := f != floors or b != boarded or r != reinforced or tw != tower or ws != workshop or pr != porch
	floors = f
	boarded = b
	reinforced = r
	tower = tw
	workshop = ws
	porch = pr
	if porch:
		porch_cliffs[cliff_id] = true
	else:
		porch_cliffs.erase(cliff_id)
	_build_porch()
	if floors >= 3:
		lookout_cliffs[cliff_id] = true
	else:
		lookout_cliffs.erase(cliff_id)
	_build_workshop()
	if changed:
		_rebuild()
		ZipLine.refresh(get_tree())
	var ledger := get_node_or_null("Ledger") as HouseLedger
	if ledger != null:
		ledger.notify_changed()
	Audio.play_at(&"build", global_position + Vector3.UP * 2.0)


static func cost_text(cost: Dictionary) -> String:
	var parts: PackedStringArray = []
	for k: StringName in cost:
		parts.append(UiStyle.cost(int(cost[k]), String(k)))
	return " + ".join(parts)


## Host: breacher damage.
func structure_damage(amount: float, _source: String) -> void:
	if not multiplayer.is_server():
		return
	GameState.damage_homestead(cliff_id, amount * (BOARDED_DAMAGE if boarded else 1.0))
	if _hit_cooldown <= 0.0:
		_hit_cooldown = 0.6
		_hit_fx.rpc()


@rpc("authority", "call_local", "unreliable")
func _hit_fx() -> void:
	Audio.play_at(&"homestead_hit", global_position + Vector3.UP * 2.0)
