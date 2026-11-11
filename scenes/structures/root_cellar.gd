class_name RootCellar
extends Node3D
## The root cellar, the homestead's ammo storage (every house has one from the
## start, Nov 11). Slanted cellar doors in a stone surround beside the house: E
## on them takes you down the stairs into a lantern-lit room dug under the
## plateau, where a rack holds one bin for every kind of turret ammo sack
## (CellarBin, AmmoStore.CELLAR_CAP each) and the ammo workbench
## (CropWorkbench) turns the crops you carry into sacks. E on the stairs climbs
## back out.

## The room, local to the doors: floor height and centre.
const ROOM := Vector3(0, -4.6, 0) # (above Player fall detection, WorldLayout.CANYON_FALL_Y)
const ROOM_SIZE := Vector3(4.4, 2.7, 5.2)

var home: Homestead
var _bins: Array[CellarBin] = []
var _lamp: OmniLight3D
var _look_t := 0.0


func _ready() -> void:
	var doors := CellarDoor.new()
	doors.cellar = self
	add_child(doors)
	_build_room()


## The room: earth walls shored with planks, a beamed ceiling, a lantern, the
## stairs up, and the bin rack along the far wall.
func _build_room() -> void:
	var room := Node3D.new()
	room.name = "Room"
	room.position = ROOM
	add_child(room)
	var mi := MeshInstance3D.new()
	mi.mesh = _room_mesh()
	mi.material_override = Materials.toon_house(0.02)
	room.add_child(mi)
	var body := StaticBody3D.new()
	body.collision_layer = WorldLayout.LAYER_WORLD
	room.add_child(body)
	var s := ROOM_SIZE
	for box: Array in [[Vector3(0, -0.1, 0), Vector3(s.x + 0.4, 0.2, s.z + 0.4)], [Vector3(0, s.y + 0.1, 0), Vector3(s.x + 0.4, 0.2, s.z + 0.4)],
			[Vector3(-s.x * 0.5 - 0.1, s.y * 0.5, 0), Vector3(0.2, s.y, s.z)], [Vector3(s.x * 0.5 + 0.1, s.y * 0.5, 0), Vector3(0.2, s.y, s.z)],
			[Vector3(0, s.y * 0.5, -s.z * 0.5 - 0.1), Vector3(s.x, s.y, 0.2)], [Vector3(0, s.y * 0.5, s.z * 0.5 + 0.1), Vector3(s.x, s.y, 0.2)]]:
		var col := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = box[1]
		col.shape = shape
		col.position = box[0]
		body.add_child(col)
	var lamp := OmniLight3D.new()
	lamp.light_color = Color("#FFC27A")
	lamp.light_energy = 1.6
	lamp.omni_range = 7.0
	lamp.position = Vector3(1.3, s.y - 0.5, -0.4)
	room.add_child(lamp)
	_lamp = lamp
	lamp.visible = false # (lit only while you're down here: _process)
	var hang := MeshInstance3D.new()
	hang.mesh = StructureBuilder.lantern()
	hang.material_override = Materials.toon(0.01)
	hang.scale = Vector3.ONE * 0.35
	hang.position = Vector3(1.3, s.y - 0.45, -0.4)
	room.add_child(hang)
	var stairs := CellarStairs.new()
	stairs.cellar = self
	stairs.position = Vector3(0, 0, -s.z * 0.5 + 0.7)
	room.add_child(stairs)
	# The rack against the far wall, bins facing the stairs.
	var rack := Node3D.new()
	rack.position = Vector3(2.08, 0, s.z * 0.5 - 0.45)
	rack.rotation.y = -PI * 0.5
	room.add_child(rack)
	var crops := AmmoStore.crops()
	for i in crops.size():
		var b := CellarBin.new()
		b.crop_id = crops[i]
		b.cliff_id = home.cliff_id if home != null else 0
		b.position = Vector3(0.0, 0.05 + (i / 3) * 0.62, 1.4 + (i % 3) * 0.68)
		rack.add_child(b)
		_bins.append(b)
	var rack_mi := MeshInstance3D.new()
	rack_mi.mesh = _rack_mesh()
	rack_mi.material_override = Materials.toon_house(0.02)
	rack.add_child(rack_mi)
	# The ammo workbench against the left wall (Nov 11 playtest fixes): crops in, sacks out.
	var bench := CropWorkbench.new()
	bench.name = "Workbench"
	bench.cellar = self
	bench.position = Vector3(-s.x * 0.5 + 0.45, 0, 0.6)
	bench.rotation.y = PI * 0.5 # its long side along the wall, front to the room
	room.add_child(bench)


## The lantern is unshadowed and sits only 2 m under the yard, so lit all the
## time it would glow on the ground and the house wall above. It's lit only
## while this screen's camera is down in the room (from there the yard can't be
## seen, and from the yard the room can't): the room looks just the same.
func _process(delta: float) -> void:
	_look_t -= delta
	if _lamp == null or _look_t > 0.0:
		return
	_look_t = 0.05
	var cam := get_viewport().get_camera_3d()
	var inside := false
	if cam != null:
		var p := to_local(cam.global_position) - ROOM
		var h := ROOM_SIZE * 0.5 + Vector3(0.6, 0.0, 0.6)
		inside = absf(p.x) < h.x and absf(p.z) < h.z and p.y > -0.5 and p.y < ROOM_SIZE.y + 0.5
	_lamp.visible = inside
	var me := _local_player()
	if me != null and home != null and me.cliff_id == home.cliff_id:
		me.in_cellar = inside # (the HUD keeps the carried-crops strip up down here)


## Can `peer_id` use this cellar? (Your own house only: the cross-canyon rule.)
func may_use(peer_id: int) -> bool:
	return GameState.is_solo() or home == null or NetworkManager.cliff_of(peer_id) == home.cliff_id


## Local: fade out, move the player, fade in.
func move_player(to: Vector3, look_yaw: float) -> void:
	var p := _local_player()
	if p == null:
		return
	var layer := CanvasLayer.new()
	layer.layer = 50
	get_tree().current_scene.add_child(layer)
	var fade := ColorRect.new()
	fade.color = Color(0, 0, 0, 0)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(fade)
	var tw := create_tween()
	tw.tween_property(fade, "color:a", 1.0, 0.18)
	tw.tween_callback(func() -> void:
		if is_instance_valid(p):
			p.global_position = to
			p.velocity = Vector3.ZERO
			p.rotation.y = look_yaw
			p.head.rotation.x = 0.0
			Audio.play_at(&"land_wood", to, -6.0))
	tw.tween_property(fade, "color:a", 0.0, 0.35)
	tw.tween_callback(layer.queue_free)


## Where you stand at the foot of the stairs, facing the bins.
func bottom() -> Vector3:
	return to_global(ROOM + Vector3(0, 0.1, -ROOM_SIZE.z * 0.5 + 2.1))


## Where you come out, beside the doors.
func top() -> Vector3:
	return to_global(Vector3(-1.4, 0.2, 0))


func facing_bins_yaw() -> float:
	var d := to_global(ROOM + Vector3(0, 0, 1)) - to_global(ROOM)
	return atan2(-d.x, -d.z)


func _local_player() -> Player:
	for n: Node in get_tree().get_nodes_in_group("players"):
		if n.is_multiplayer_authority() and not bool(n.get("bot")):
			return n as Player
	return null


## The room's walls, floor, ceiling beams and stairs (local to the room's floor centre).
static func _room_mesh() -> ArrayMesh:
	var st := MeshKit.begin()
	var s := ROOM_SIZE
	var earth := Color("#6A4A32")
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	# Packed-earth floor and walls.
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, -0.05, 0)), Vector3(s.x, 0.1, s.z), earth.darkened(0.15))
	for side: float in [-1.0, 1.0]:
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(side * s.x * 0.5, s.y * 0.5, 0)), Vector3(0.1, s.y, s.z), earth)
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, s.y * 0.5, side * s.z * 0.5)), Vector3(s.x, s.y, 0.1), earth)
	# Ceiling planks on beams.
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, s.y + 0.05, 0)), Vector3(s.x, 0.1, s.z), Palette.WOOD_DARK)
	for k in 5:
		var z := -s.z * 0.5 + 0.4 + k * (s.z - 0.8) / 4.0
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, s.y - 0.08, z)), Vector3(s.x, 0.16, 0.18), Palette.WOOD)
	# Shoring: upright posts and planks along the side walls.
	for side: float in [-1.0, 1.0]:
		for k in 4:
			var z := -s.z * 0.5 + 0.3 + k * (s.z - 0.6) / 3.0
			MeshKit.add_box(st, Transform3D(Basis(), Vector3(side * (s.x * 0.5 - 0.1), s.y * 0.5, z)), Vector3(0.14, s.y, 0.14), Palette.WOOD)
		for k in 3:
			MeshKit.add_box(st, Transform3D(Basis(), Vector3(side * (s.x * 0.5 - 0.06), 0.4 + k * 0.8, 0)), Vector3(0.04, 0.22, s.z - 0.2), Palette.WOOD_DARK)
	# The stairs climbing to the hatch at the near end.
	for k in 8:
		var z := -s.z * 0.5 + 0.15 + k * 0.2
		var y := s.y - 0.15 - k * 0.33
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, y, z)), Vector3(1.0, 0.06, 0.28), Palette.WOOD)
	for side: float in [-1.0, 1.0]:
		var a := Vector3(side * 0.52, s.y, -s.z * 0.5 + 0.1)
		var b := Vector3(side * 0.52, 0.0, -s.z * 0.5 + 1.75)
		var axis := (b - a).normalized()
		var bb := Basis(axis.cross(Vector3.RIGHT).normalized(), axis, Vector3.RIGHT)
		MeshKit.add_box(st, Transform3D(bb.orthonormalized(), (a + b) * 0.5), Vector3(0.06, (b - a).length(), 0.22), Palette.WOOD_DARK)
	# A few roots poking through the walls, and sacks of old stores in a corner.
	for k in 6:
		var at := Vector3(rng.randf_range(-1.8, 1.8), rng.randf_range(1.2, s.y - 0.3), (1.0 if k % 2 else -1.0) * (s.z * 0.5 - 0.06))
		MeshKit.add_limb(st, at, at + Vector3(rng.randf_range(-0.3, 0.3), -rng.randf_range(0.2, 0.5), -signf(at.z) * 0.15), 0.02, Color("#8A6440"), 4)
	return MeshKit.finish(st)


## The bin rack: posts, shelves and a top board.
static func _rack_mesh() -> ArrayMesh:
	var st := MeshKit.begin()
	var z0 := 1.4 - 0.36
	var z1 := 1.4 + 2 * 0.68 + 0.36
	for z: float in [z0, z1]:
		for x: float in [-0.32, 0.32]:
			MeshKit.add_box(st, Transform3D(Basis(), Vector3(x, 1.0, z)), Vector3(0.08, 2.0, 0.08), Palette.WOOD_DARK)
	for row in 4:
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.03 + row * 0.62, (z0 + z1) * 0.5)), Vector3(0.66, 0.05, z1 - z0 + 0.08), Palette.WOOD)
	return MeshKit.finish(st)
