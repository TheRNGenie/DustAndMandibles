class_name WaterTower
extends StaticBody3D
## A homestead's water tower (Waterworks). While the generator runs, the well
## pump fills it at Waterworks.FILL_PER_MIN up to Waterworks.TANK_MAX; its tap
## (TowerTap) fills a bucket from what's stored. A sight glass on the tank and a
## painted board by the tap show the level. Every cliff's tower is its own
## design (WaterworksBuilder.tower). The host owns the level and syncs it.

static var _by_cliff: Dictionary = {}

var cliff_id := 0
var style: StringName = &"timber"
## Water in the tank (host-owned; mirrored on clients).
var stored := 0.0

var _level_mi: MeshInstance3D
var _glass_h := 2.0
var _glass_base := 0.0
var _label: Label3D
var _shown := -1


static func of(cid: int) -> WaterTower:
	var t: Variant = _by_cliff.get(cid)
	return t as WaterTower if t != null and is_instance_valid(t) else null


func _ready() -> void:
	Materials.paint_live(self, Materials.RUSTIC, Materials.MAP_YARD) # painted wood, iron, rock (assets/rustic)
	add_to_group("water_towers")
	_by_cliff[cliff_id] = self
	collision_layer = WorldLayout.LAYER_WORLD
	var info := WaterworksBuilder.tower(style, 200 + cliff_id)
	var mi := MeshInstance3D.new()
	mi.name = "Tower"
	mi.mesh = info["mesh"]
	mi.material_override = Materials.toon()
	add_child(mi)
	for s: Array in info["shapes"]:
		var col := CollisionShape3D.new()
		col.shape = s[0]
		col.transform = s[1]
		add_child(col)
	# Sight glass up the tank's front: a dark tube with the water column in it.
	var bottom: float = info["tank_bottom"]
	var top: float = info["tank_top"]
	var gz: float = info["glass_z"] + 0.09
	_glass_h = top - bottom - 0.3
	_glass_base = bottom + 0.15
	var glass := MeshInstance3D.new()
	var tube := BoxMesh.new()
	tube.size = Vector3(0.16, _glass_h + 0.12, 0.06)
	glass.mesh = tube
	var glass_mat := StandardMaterial3D.new()
	glass_mat.albedo_color = Color("#1E2A30")
	glass.material_override = glass_mat
	glass.position = Vector3(0.45, bottom + 0.15 + _glass_h * 0.5, gz)
	add_child(glass)
	_level_mi = MeshInstance3D.new()
	var col_mesh := BoxMesh.new()
	col_mesh.size = Vector3(0.1, 1.0, 0.04)
	_level_mi.mesh = col_mesh
	var water_mat := StandardMaterial3D.new()
	water_mat.albedo_color = Color("#56B4E8")
	water_mat.emission_enabled = true
	water_mat.emission = Color("#2E7FB0")
	water_mat.emission_energy_multiplier = 0.4
	_level_mi.material_override = water_mat
	_level_mi.position = Vector3(0.45, bottom + 0.15, gz + 0.03)
	add_child(_level_mi)
	# A painted board by the tap with the level in big numbers.
	_label = Label3D.new()
	_label.font_size = 64
	_label.pixel_size = 0.004
	_label.outline_size = 10
	_label.modulate = Palette.BONE
	_label.outline_modulate = Palette.OUTLINE
	_label.position = WaterworksBuilder.TAP_POS + Vector3(0, 0.62, 0.02)
	add_child(_label)
	var tap := TowerTap.new()
	tap.name = "Tap"
	tap.tower = self
	tap.position = WaterworksBuilder.TAP_POS
	add_child(tap)
	_show_level()


func _exit_tree() -> void:
	if _by_cliff.get(cliff_id) == self:
		_by_cliff.erase(cliff_id)


func _process(delta: float) -> void:
	if not multiplayer.is_server():
		return
	var before := int(stored)
	# One stream of water: the pump fills the well's trough first, and only once
	# the trough is full does the flow go on up to the tower.
	stored = Waterworks.fill(stored, delta, GameState.pumps_on() and _trough_full(), GameState.growth_scale())
	if int(stored) != before:
		_sync.rpc(stored)


## Host: fill a bucket for `peer_id` from the tank. Returns how much it got.
func draw(peer_id: int) -> int:
	if not multiplayer.is_server():
		return 0
	var n := Waterworks.tap_amount(stored)
	if n <= 0:
		return 0
	stored -= float(n)
	Economy.earn(Economy.payer_cliff(peer_id, cliff_id), {&"water": n})
	_sync.rpc(stored)
	_fx.rpc()
	return n


## Is this yard's pump jack trough full (so the pump's flow comes to the tower)?
## True when there's no pump jack (old layouts): the tower fills as before.
func _trough_full() -> bool:
	for n: Node in get_tree().get_nodes_in_group("water_sources"):
		var w := n as WaterSource
		if w != null and w.overflows_to_tower and w.cliff_id == cliff_id:
			return w.trough_full()
	return true


## Host: set the level outright (resuming a saved run).
func set_level(value: float) -> void:
	if multiplayer.is_server():
		_sync.rpc(clampf(value, 0.0, Waterworks.TANK_MAX))


@rpc("authority", "call_local", "reliable")
func _sync(value: float) -> void:
	stored = value
	_show_level()


@rpc("authority", "call_local", "unreliable")
func _fx() -> void:
	Audio.play_at(&"water_pour", to_global(WaterworksBuilder.TAP_POS), -4.0)


func _show_level() -> void:
	var f := clampf(stored / Waterworks.TANK_MAX, 0.0, 1.0)
	_level_mi.visible = f > 0.005
	_level_mi.scale = Vector3(1, maxf(f * _glass_h, 0.01), 1)
	_level_mi.position.y = _glass_base + f * _glass_h * 0.5
	var shown := int(stored)
	if shown != _shown:
		_shown = shown
		_label.text = "%d / %d" % [shown, int(Waterworks.TANK_MAX)]

