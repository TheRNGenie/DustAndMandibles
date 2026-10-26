class_name Airship
extends Node3D
## "The Lucky Mandible", a flying casino. After every 5th wave it drifts in over
## the Oasis for the build phase (which runs 60 s longer), hovers, and drops a rope
## ladder onto the spire. On deck: slot machines and a prize wheel. When the
## warning bell rings it hauls up the ladder and leaves; anyone still aboard is
## set down on the Oasis. Every peer animates it from the game phase, so the
## ship itself needs no network sync (the games talk to the host).

const NAME := "The Lucky Mandible"
const HOVER := 14.0
const LADDER_FOOT := Vector3(-4.5, 0.0, OasisBuilder.CENTER_Z - 4.0)
const ARRIVE_TIME := 12.0
const FAR := 320.0
const LADDER_DROP := 3.0

var _deck: StaticBody3D
var _ladder_mi: MeshInstance3D
var _ladder_area: Area3D
var _props: Array[Node3D] = []
var _t := 0.0
var _state := 0 # 0 away, 1 arriving, 2 hovering, 3 leaving
var _hover_pos := Vector3.ZERO
var _away_pos := Vector3.ZERO


static func visits(w: int) -> bool:
	if GameState.has_flag("--airship"):
		return true
	return w > 1 and (w - 1) % 5 == 0 and w <= Defs.WAVE_CONFIG.last_wave


func _ready() -> void:
	var top_y := WorldLayout.CLIFF_HEIGHT
	_hover_pos = Vector3(LADDER_FOOT.x, top_y + HOVER, LADDER_FOOT.z - AirshipBuilder.DECK_L * 0.5 - 0.3)
	_away_pos = _hover_pos + Vector3(0, 25.0, -FAR)
	position = _away_pos
	visible = false
	var hull := MeshInstance3D.new()
	hull.mesh = AirshipBuilder.hull()
	hull.material_override = Materials.toon(0.04)
	add_child(hull)
	# Deck and railing collide so players can walk around up there.
	_deck = StaticBody3D.new()
	_deck.name = "Deck"
	add_child(_deck)
	var floor_col := CollisionShape3D.new()
	var floor_shape := BoxShape3D.new()
	floor_shape.size = Vector3(AirshipBuilder.DECK_W, 0.3, AirshipBuilder.DECK_L)
	floor_col.shape = floor_shape
	floor_col.position.y = -0.15
	_deck.add_child(floor_col)
	var rail_mesh := AirshipBuilder.railing()
	var rail := MeshInstance3D.new()
	rail.mesh = rail_mesh
	rail.material_override = Materials.toon(0.02)
	add_child(rail)
	var rail_col := CollisionShape3D.new()
	rail_col.shape = rail_mesh.create_trimesh_shape()
	_deck.add_child(rail_col)
	var roof_col := CollisionShape3D.new()
	var roof_shape := BoxShape3D.new()
	roof_shape.size = Vector3(AirshipBuilder.DECK_W + 0.6, 0.15, AirshipBuilder.DECK_L + 0.6)
	roof_col.shape = roof_shape
	roof_col.position.y = 2.85
	_deck.add_child(roof_col)
	for sx: float in [-1.0, 1.0]:
		var prop := Spin.new()
		prop.mesh = AirshipBuilder.propeller()
		prop.material_override = Materials.toon(0.02)
		prop.position = Vector3(sx * (AirshipBuilder.DECK_W * 0.5 + 2.8), 2.2, 1.0)
		add_child(prop)
	# Painted on both flanks of the envelope.
	for sx: float in [-1.0, 1.0]:
		var sign := Label3D.new()
		sign.text = "CASINO\n%s" % NAME
		sign.font_size = 160
		sign.outline_size = 28
		sign.modulate = Palette.GLOW_YELLOW
		sign.outline_modulate = Color("#7A2E22")
		sign.pixel_size = 0.011
		sign.position = Vector3(sx * (AirshipBuilder.ENVELOPE.x + 0.15), AirshipBuilder.ENVELOPE_Y, 0)
		sign.rotation.y = sx * PI * 0.5
		add_child(sign)
	var glow := OmniLight3D.new()
	glow.light_color = Color("#FFC27A")
	glow.light_energy = 2.0
	glow.omni_range = 10.0
	glow.position = Vector3(0, 2.2, 0)
	add_child(glow)
	# Ladder hangs from the gap in the +Z railing.
	var ladder_top := Vector3(0, 0.0, AirshipBuilder.DECK_L * 0.5 + 0.25)
	_ladder_mi = MeshInstance3D.new()
	_ladder_mi.mesh = AirshipBuilder.ladder(HOVER)
	_ladder_mi.material_override = Materials.toon(0.01)
	_ladder_mi.position = ladder_top
	add_child(_ladder_mi)
	_ladder_area = Area3D.new()
	_ladder_area.name = "Ladder"
	_ladder_area.collision_layer = 0
	_ladder_area.collision_mask = 0xFFFF
	_ladder_area.monitoring = false
	var lcol := CollisionShape3D.new()
	var lshape := BoxShape3D.new()
	lshape.size = Vector3(1.4, HOVER + 2.0, 1.4)
	lcol.shape = lshape
	lcol.position = ladder_top + Vector3(0, -HOVER * 0.5 + 0.9, 0.1)
	_ladder_area.add_child(lcol)
	add_child(_ladder_area)
	_ladder_area.body_entered.connect(func(b: Node3D) -> void:
		if b is Player:
			(b as Player).ladder_count += 1
			(b as Player).ladder_top_y = global_position.y)
	_ladder_area.body_exited.connect(func(b: Node3D) -> void:
		if b is Player:
			(b as Player).ladder_count = maxi((b as Player).ladder_count - 1, 0))
	# The games.
	for i in 2:
		var slot := SlotMachine.new()
		slot.name = "Slots%d" % i
		slot.position = Vector3(-AirshipBuilder.DECK_W * 0.5 + 1.0, 0, -2.0 + i * 2.2)
		slot.rotation.y = -PI * 0.5
		add_child(slot)
	var wheel := PrizeWheel.new()
	wheel.name = "Wheel"
	wheel.position = Vector3(AirshipBuilder.DECK_W * 0.5 - 1.0, 0, -1.0)
	wheel.rotation.y = PI * 0.5
	add_child(wheel)
	var bar := MeshInstance3D.new()
	bar.mesh = _bar_mesh()
	bar.material_override = Materials.toon(0.02)
	bar.position = Vector3(0, 0, -AirshipBuilder.DECK_L * 0.5 + 1.2)
	add_child(bar)
	_set_deck_active(false)
	GameState.phase_changed.connect(_on_phase)


func _bar_mesh() -> ArrayMesh:
	var st := MeshKit.begin()
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.55, 0)), Vector3(4.0, 1.1, 0.7), Palette.WOOD_DARK)
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 1.12, 0)), Vector3(4.2, 0.08, 0.9), Palette.WOOD)
	for k in 6:
		MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(-1.6 + k * 0.6, 1.3, -0.1)), 0.07, 0.06, 0.3, 6, Color("#5C8A3A") if k % 2 == 0 else Color("#7A2E22"))
	return MeshKit.finish(st)


func _on_phase(p: GameState.Phase) -> void:
	if p == GameState.Phase.BUILD and visits(GameState.wave):
		_state = 1
		_t = 0.0
		visible = true
		position = _away_pos
		Economy.notice.emit("%s, a flying casino, is drifting in over the Oasis! Climb its ladder for slots and the prize wheel. (+60 s to build)" % NAME)
		Audio.play_ui(&"bell")
	elif _state == 1 or _state == 2:
		_leave()


func _leave() -> void:
	_state = 3
	_t = 0.0
	_set_deck_active(false)
	# Anyone aboard (or on the ladder) is set down on the Oasis.
	for n: Node in get_tree().get_nodes_in_group("players"):
		var pl := n as Player
		if pl.is_multiplayer_authority() and _aboard(pl.global_position):
			pl.global_position = Vector3(LADDER_FOOT.x, WorldLayout.CLIFF_HEIGHT + 0.3, LADDER_FOOT.z + 1.5)
			pl.velocity = Vector3.ZERO
			pl.ladder_count = 0
			Economy.notice.emit("The casino ship is leaving. A deckhand lowers you to the Oasis.")


func _aboard(p: Vector3) -> bool:
	var local := global_transform.affine_inverse() * p
	return absf(local.x) < AirshipBuilder.DECK_W * 0.5 + 1.5 and local.z > -AirshipBuilder.DECK_L * 0.5 - 1.0 \
			and local.z < AirshipBuilder.DECK_L * 0.5 + 2.0 and local.y > -HOVER - 0.5 and local.y < 4.0


func _set_deck_active(on: bool) -> void:
	_deck.process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED
	_ladder_area.monitoring = on
	_ladder_mi.visible = on
	for c in get_children():
		if c is SlotMachine or c is PrizeWheel:
			(c as Node3D).process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED
	if not on:
		for n: Node in get_tree().get_nodes_in_group("players"):
			(n as Player).ladder_count = 0


func _process(delta: float) -> void:
	if _state == 0:
		return
	_t += delta
	var bob := Vector3(0, sin(_t * 0.7) * 0.25, 0)
	match _state:
		1:
			var k := clampf(_t / ARRIVE_TIME, 0.0, 1.0)
			k = 1.0 - pow(1.0 - k, 3.0)
			position = _away_pos.lerp(_hover_pos, k)
			if _t >= ARRIVE_TIME:
				_state = 2
				_t = 0.0
		2:
			position = _hover_pos + bob * minf(_t, 1.0)
			if _t >= 0.5 and not _ladder_mi.visible:
				_set_deck_active(true)
				Audio.play_at(&"build", global_position)
			# The ladder unrolls downward.
			_ladder_mi.scale.y = clampf((_t - 0.5) / LADDER_DROP, 0.05, 1.0)
		3:
			var k := clampf(_t / ARRIVE_TIME, 0.0, 1.0)
			k = k * k
			position = _hover_pos.lerp(_away_pos, k)
			if _t >= ARRIVE_TIME:
				_state = 0
				visible = false


## Spins a propeller.
class Spin extends MeshInstance3D:
	func _process(delta: float) -> void:
		rotate_z(delta * 9.0)
