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


func _rebuild() -> void:
	var mesh := HouseBuilder.build(100 + cliff_id, Palette.team_color(cliff_id), floors, boarded, reinforced)
	_mi.mesh = mesh
	_col.shape = HouseBuilder.build(100 + cliff_id, Color.WHITE, floors, boarded, reinforced, true).create_trimesh_shape()
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
