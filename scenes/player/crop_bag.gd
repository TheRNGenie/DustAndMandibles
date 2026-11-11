class_name CropBag
extends Node3D
## The crop bag (playtest fixes, Nov 2026): replaces the Zippo on key 9. Every
## player carries one. Hold right click for the crop wheel and flick to a crop
## to set the bag; left click a crop-fed turret on your own cliff up to
## CropBagUI.REACH (15 m) away to load (or, in the build phase, swap) it with a
## sack of that crop from the cellar. CropBagUI has the rules (feed), the turret
## card and the wheel; the load is the turret's own server-checked one
## (UniversalTurret.request_load, the same as E / Q).
##
## Held at the hip as the cellar's burlap sack with the set crop's patch.

## Where the set crop is kept between runs (per --profile).
const SAVE_PATH := "user://crop_bag.cfg"

var player: Player
## The crop a left click loads (&"" = none set yet). Local; saved per profile.
var set_crop: StringName = &""
var _was_out := false
var _sway := 0.0
## Turret highlights while the bag is out (Logan, Nov 11): your crop-fed turrets
## red when empty and green when loaded, your other turrets orange.
const EMPTY_COLOR := Color("#FF3B2E")
const LOADED_COLOR := Color("#4CE05A")
const OTHER_COLOR := Color("#FF9A2E")
const MARK_POLL := 0.25
## How tall the glowing wall round a turret rises.
const HALO_H := 2.4
var _marks: Dictionary = {} ## turret instance id -> its highlight node
var _mark_t := 0.0
static var _mats: Dictionary = {}


func _ready() -> void:
	if player != null and player.is_multiplayer_authority():
		set_crop = _load_crop()


## Is the bag in hand?
func is_out() -> bool:
	return player != null and player.gun != null and player.gun.holding == CropBagUI.ITEM


## Sacks of `c` in your cliff's cellar (what a load takes from).
func sacks_of(c: StringName) -> int:
	var item := CropEffects.sack_of(c)
	if item == &"" or player == null:
		return 0
	return Economy.amount(Economy.payer_cliff(multiplayer.get_unique_id(), player.cliff_id), item)


## The wheel picked `c`: set the bag (and the sack in hand shows its patch).
func set_bag_crop(c: StringName) -> void:
	if c == set_crop:
		return
	set_crop = c
	_save_crop(c)
	if is_out():
		player.gun.hold_item(CropBagUI.ITEM) # redraw the sack with the new patch
	Audio.play_at(&"rustle", global_position, -10.0, 1.3)
	var hb := player.get_node_or_null("Hotbar") as Hotbar
	if hb != null:
		hb.changed.emit() # slot 9's sack and count


func _process(delta: float) -> void:
	if player == null or not player.is_multiplayer_authority():
		return
	var out := is_out() and not player.is_downed()
	if out != _was_out:
		_was_out = out
		CropBagUI.held = out
		if not out:
			_clear_marks()
	if not out:
		return
	_mark_t -= delta
	if _mark_t <= 0.0:
		_mark_t = MARK_POLL
		_update_marks()
	# A slow sway at the hip.
	_sway += delta
	player.gun.item_pos = Vector3(0.02, -0.06 + sin(_sway * 1.7) * 0.006, 0.04)
	player.gun.item_rot = Vector3(0.0, 0.25 + sin(_sway * 1.1) * 0.03, 0.05)
	if GameState.menu_open or player.build_mode.active:
		return
	if not (Input.mouse_mode == Input.MOUSE_MODE_CAPTURED or player.grapple.test_mode):
		return
	if Input.is_action_just_pressed("alt_fire"):
		CropWheel.open_for(CropBagUI.Wheel.new(self), &"alt_fire")
	elif Input.is_action_just_pressed("fire"):
		var t := target()
		if t != null and CropBagUI.feed(t, set_crop) in [CropBagUI.Feed.LOAD, CropBagUI.Feed.SWAP]:
			t.call("request_load", set_crop)
			Audio.play_at(&"rustle", global_position, -4.0, 1.1)


func _exit_tree() -> void:
	if _was_out:
		CropBagUI.held = false
	_clear_marks()


## Which colour turret `t` shows with the bag out.
static func mark_color(t: Object) -> Color:
	if t == null or not t.has_method("request_load"):
		return OTHER_COLOR
	return LOADED_COLOR if StringName(t.get("crop")) != &"" else EMPTY_COLOR


## Rings at the feet of every turret on your cliff, coloured by mark_color (local only).
func _update_marks() -> void:
	var seen := {}
	for n: Node in get_tree().get_nodes_in_group("turrets"):
		var t := n as Node3D
		if t == null or not is_instance_valid(t) or t.is_queued_for_deletion() or int(t.get("cliff_id")) != player.cliff_id:
			continue
		var key := t.get_instance_id()
		seen[key] = true
		var m := _marks.get(key) as MeshInstance3D
		if m == null or not is_instance_valid(m):
			m = MeshInstance3D.new()
			m.name = "BagMark"
			m.mesh = _ring_mesh()
			m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			m.position.y = 0.06
			t.add_child(m)
			_marks[key] = m
		m.material_override = _mat(mark_color(t))
	for key: int in _marks.keys():
		if not seen.has(key):
			var m := _marks[key] as Node
			if m != null and is_instance_valid(m):
				m.queue_free()
			_marks.erase(key)


func _clear_marks() -> void:
	for key: int in _marks:
		var m := _marks[key] as Node
		if m != null and is_instance_valid(m):
			m.queue_free()
	_marks.clear()


## A glowing ring that shows through scaffolds (drawn on top, a little see-through).
static func _mat(c: Color) -> StandardMaterial3D:
	var key := c.to_html()
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(c, 0.9)
	m.vertex_color_use_as_albedo = true # (white, fading up the wall: the colour comes from albedo)
	m.no_depth_test = true
	m.render_priority = 2
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mats[key] = m
	return m


static var _ring: ArrayMesh


static func _ring_mesh() -> ArrayMesh:
	if _ring != null:
		return _ring
	# A ring at the turret's feet and a glowing wall rising from it that fades
	# out by HALO_H, so the colour reads from any angle (white: the material tints it).
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var seg := 40
	var r := 1.15
	for i in seg:
		var a0 := TAU * i / seg
		var a1 := TAU * (i + 1) / seg
		var d0 := Vector3(cos(a0), 0, sin(a0))
		var d1 := Vector3(cos(a1), 0, sin(a1))
		var solid := Color(1, 1, 1, 1)
		for v: Vector3 in [d0 * (r - 0.15), d0 * r, d1 * r, d0 * (r - 0.15), d1 * r, d1 * (r - 0.15)]:
			st.set_color(solid)
			st.add_vertex(v)
		var top := Vector3.UP * HALO_H
		var lo := Color(1, 1, 1, 0.45)
		var hi := Color(1, 1, 1, 0.0)
		for pair: Array in [[d0 * r, lo], [d1 * r, lo], [d1 * r + top, hi], [d0 * r, lo], [d1 * r + top, hi], [d0 * r + top, hi]]:
			st.set_color(pair[1])
			st.add_vertex(pair[0])
	_ring = st.commit()
	return _ring


## The crop-fed turret on your own cliff under the crosshair within the bag's
## reach (null if none).
func target() -> Node:
	var cam := player.camera
	var from := cam.global_position
	var q := PhysicsRayQueryParameters3D.create(from, from - cam.global_transform.basis.z * CropBagUI.REACH,
			WorldLayout.LAYER_WORLD | WorldLayout.LAYER_STRUCTURE | WorldLayout.LAYER_TRAP)
	q.exclude = [player.get_rid()]
	var hit := player.get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return null
	var c := hit["collider"] as Node
	return c if feedable(c, player.cliff_id) else null


## A crop-fed turret on cliff `cliff` (the bag never reaches the partner's turrets).
static func feedable(c: Object, cliff: int) -> bool:
	return c != null and is_instance_valid(c) and c.has_method("request_load") and c.has_method("sacks_of") \
			and int(c.get("cliff_id")) == cliff


static func _load_crop() -> StringName:
	var cf := ConfigFile.new()
	if cf.load(SAVE_PATH) != OK:
		return &""
	return StringName(str(cf.get_value("bag", _key(), "")))


static func _save_crop(c: StringName) -> void:
	var cf := ConfigFile.new()
	cf.load(SAVE_PATH)
	cf.set_value("bag", _key(), String(c))
	cf.save(SAVE_PATH)


static func _key() -> String:
	var p := GameState.flag_value("--profile")
	return p if p != "" else "default"
