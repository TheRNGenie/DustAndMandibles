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
	{"id": &"floor3", "name": "Build a lookout floor", "cost": {&"scrap": 180, &"chitin": 30}, "desc": "Adds a top storey and a railed roof deck with 2 more mounts."},
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
var _hit_cooldown := 0.0
var _mi: MeshInstance3D
var _col: CollisionShape3D
var _lights: Array[OmniLight3D] = []
var _flag: MeshInstance3D
var _flag_t := 0.0
var _chair: MeshInstance3D
var _smoke_at := Vector3.ZERO
var _smoke_t := 0.0


static func of(cid: int) -> Homestead:
	for n: Node in Engine.get_main_loop().get_nodes_in_group("homesteads"):
		if (n as Homestead).cliff_id == cid:
			return n as Homestead
	return null


func _ready() -> void:
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
	var mesh := HouseBuilder.build(100 + cliff_id, Palette.team_color(cliff_id), floors, boarded, reinforced)
	_mi.mesh = mesh
	_col.shape = HouseBuilder.build(100 + cliff_id, Color.WHITE, floors, boarded, reinforced, true).create_trimesh_shape()
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
	if not Economy.spend(cliff_id, u["cost"]):
		Economy.notify(peer_id, "Not enough for %s (%s)." % [str(u["name"]).to_lower(), cost_text(u["cost"])])
		return
	match u["id"]:
		&"patch":
			GameState.heal_homestead(cliff_id, PATCH_HP)
		&"board":
			boarded = true
		&"reinforce":
			reinforced = true
			GameState.raise_homestead_max(cliff_id, REINFORCE_HP)
		&"floor2":
			floors = 2
		&"floor3":
			floors = 3
	_set_state.rpc(floors, boarded, reinforced)
	Economy.notify_cliff(cliff_id, "Homestead: %s done." % str(u["name"]).to_lower())


@rpc("authority", "call_local", "reliable")
func _set_state(f: int, b: bool, r: bool) -> void:
	var changed := f != floors or b != boarded or r != reinforced
	floors = f
	boarded = b
	reinforced = r
	if changed:
		_rebuild()
	var ledger := get_node_or_null("Ledger") as HouseLedger
	if ledger != null:
		ledger.notify_changed()
	Audio.play_at(&"build", global_position + Vector3.UP * 2.0)


static func cost_text(cost: Dictionary) -> String:
	var parts: PackedStringArray = []
	for k: StringName in cost:
		parts.append("%d %s" % [int(cost[k]), String(k)])
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
