class_name Wardrobe
extends RefCounted
## Dress your dummy: a turning preview on the left, a row of choices per slot
## (hat, hair, facial hair, outfit, neck, extras, paint) on the right. Opens on
## the MenuScreen from the pause menu or the wardrobe in your house. Changes are
## saved and your partner sees them straight away.

signal menu_changed

static var _preview: SubViewport
static var _rig: DummyRig
static var _turn: Node3D


static func open() -> void:
	if MenuScreen.instance != null:
		MenuScreen.instance.open(Wardrobe.new())


func _init() -> void:
	Settings.look_changed.connect(func() -> void: menu_changed.emit())


func menu_title() -> String:
	return "Wardrobe"


func menu_tagline() -> String:
	return "Dress your crash-test dummy for the frontier. Your partner sees it too."


## The header shows your Notches (what locked looks cost), not scrap and chitin.
func menu_stock() -> Array:
	return [[&"notches", Perks.profile.brands]]


func menu_build_body(body: Control, _screen: MenuScreen) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	body.add_child(row)
	# Turning preview.
	var frame := UiStyle.panel("WellPanel") # Theme: a recessed well behind the dummy
	frame.custom_minimum_size = Vector2(260, 400)
	row.add_child(frame)
	var tex := TextureRect.new()
	tex.texture = _preview_texture(MenuScreen.instance)
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	frame.add_child(tex)
	# Choices.
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 6)
	row.add_child(col)
	for slot: String in DummyLook.SLOTS:
		var info: Array = DummyLook.SLOTS[slot]
		col.add_child(UiStyle.section(str(info[0])))
		var labels: Array = []
		var selected := 0
		for i in (info[1] as Array).size():
			var opt: Array = info[1][i]
			labels.append(opt[1])
			if opt[0] == Settings.look.get(slot):
				selected = i
		var options := MenuScreen.toggle_row(labels, selected, func(i: int) -> void:
			Settings.set_look(slot, str(info[1][i][0])))
		col.add_child(options)
		Perks.lock_look_row(options, slot) # Perk: some looks are bought with Brands (Rancher's Ledger)


func menu_press(_id: Variant, _action: StringName) -> void:
	pass


## A small studio: a dummy on a turntable, re-dressed whenever the look changes.
static func _preview_texture(host: Node) -> Texture2D:
	if _preview == null or not is_instance_valid(_preview):
		_preview = SubViewport.new()
		_preview.size = Vector2i(320, 480)
		_preview.own_world_3d = true
		_preview.transparent_bg = true
		host.add_child(_preview)
		_turn = Spinner.new()
		_preview.add_child(_turn)
		_rig = DummyRig.new()
		_turn.add_child(_rig)
		var cam := Camera3D.new()
		cam.fov = 30.0
		cam.position = Vector3(0, 1.05, -4.8)
		_preview.add_child(cam)
		cam.look_at(Vector3(0, 0.95, 0))
		var env := Environment.new()
		env.background_mode = Environment.BG_CLEAR_COLOR
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color("#D6C8B4") # neutral, so the set's backdrop shows true
		env.ambient_light_energy = 0.8
		cam.environment = env
		var sun := DirectionalLight3D.new()
		sun.rotation = Vector3(deg_to_rad(-35), deg_to_rad(150), 0)
		sun.light_energy = 1.3
		_preview.add_child(sun)
		# One connection for good (a new lambda per studio piled up a connection
		# each time a world freed the old one).
		if not Settings.look_changed.is_connected(_redress):
			Settings.look_changed.connect(_redress)
	_rig.build(Palette.TEAM_WEST, false, Settings.look)
	_rig.animate(0.016, 0.0, false, 0.0)
	return _preview.get_texture()


static func _redress() -> void:
	if is_instance_valid(_rig):
		_rig.build(Palette.TEAM_WEST, false, Settings.look)


## Turns the preview dummy slowly.
class Spinner extends Node3D:
	func _process(delta: float) -> void:
		rotate_y(delta * 0.6)
