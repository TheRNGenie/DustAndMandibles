class_name Airship
extends Node3D
## "The Lucky Mandible", a flying casino and market. It hangs over the play area all game,
## between the two great arches, its stern boarding ring 45 m above their crowns:
## climb an arch, grapple the ring and you're pulled up onto the deck. The stern
## half is the market (the produce vendor and the gunsmith, moved up from the old
## Oasis); the bow half is the casino: slots, the prize wheel, card tables, roulette. Jump off to leave (the
## arches are a grapple away). Every peer animates it the same way, so the ship
## needs no network sync (the games talk to the host).

const NAME := "The Lucky Mandible"
## Where it hangs: its boarding ring 45 m straight above the crown of the
## northern great arch (crown at about (6.7, 96.7, 21.5)), the ship stretching
## away north so there's a clear line to the ring from both arches.
const ARCH_CROWN := Vector3(6.7, 96.7, 21.5)
const RING_ABOVE_ARCHES := 45.0
const HOVER := 14.0
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


## The ship no longer comes and goes (so no extra build time for a visit).
static func visits(_w: int) -> bool:
	return false


## The boarding ring's world position (grapple target).
static func ring_position() -> Vector3:
	return ARCH_CROWN + Vector3(0, RING_ABOVE_ARCHES, 0)


func _ready() -> void:
	# Turned round so the stern (and its ring) faces south, toward the other arch.
	rotation.y = PI
	_hover_pos = ring_position() + Vector3(0, -RING_Y, AirshipBuilder.DECK_L * 0.5 + RING_OUT)
	_away_pos = _hover_pos
	position = _hover_pos
	visible = true
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
	roof_col.position.y = AirshipBuilder.ROOF_Y + 0.05
	_deck.add_child(roof_col)
	for sx: float in [-1.0, 1.0]:
		var prop := Spin.new()
		prop.mesh = AirshipBuilder.propeller()
		prop.material_override = Materials.toon(0.02)
		for pz: float in [-8.0, 8.0]:
			var p2 := Spin.new()
			p2.mesh = AirshipBuilder.propeller()
			p2.material_override = Materials.toon(0.02)
			p2.scale = Vector3.ONE * 1.4
			p2.position = Vector3(sx * (AirshipBuilder.DECK_W * 0.5 + 2.8), AirshipBuilder.ROOF_Y - 0.6, pz - 1.2)
			add_child(p2)
		prop.queue_free()
	# Painted on both flanks of the envelope.
	for sx: float in [-1.0, 1.0]:
		var sign := Label3D.new()
		sign.text = "CASINO\n%s" % NAME
		sign.font_size = 240
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
	glow.position = Vector3(0, 3.0, -7.0)
	glow.omni_range = 16.0
	add_child(glow)
	var glow2 := OmniLight3D.new()
	glow2.light_color = Color("#FFE2B0")
	glow2.light_energy = 1.6
	glow2.omni_range = 14.0
	glow2.position = Vector3(0, 3.2, 9.0)
	add_child(glow2)
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
		slot.position = Vector3(-AirshipBuilder.DECK_W * 0.5 + 1.0, 0, -12.0 + i * 2.4)
		slot.rotation.y = -PI * 0.5
		add_child(slot)
	var wheel := PrizeWheel.new()
	wheel.name = "Wheel"
	wheel.position = Vector3(AirshipBuilder.DECK_W * 0.5 - 1.0, 0, -10.0)
	wheel.rotation.y = PI * 0.5
	add_child(wheel)
	# Card tables and the roulette wheel.
	var tables: Array = [[BlackjackTable.new(), "Blackjack", Vector3(3.2, 0, -3.0)], [BaccaratTable.new(), "Baccarat", Vector3(-3.2, 0, -3.0)],
		[RouletteTable.new(), "Roulette", Vector3(0.0, 0, -8.5)]]
	for t: Array in tables:
		var table := t[0] as CasinoTable
		table.name = t[1]
		table.position = t[2]
		add_child(table)
	var bar := MeshInstance3D.new()
	bar.mesh = _bar_mesh()
	bar.material_override = Materials.toon(0.02)
	bar.position = Vector3(0, 0, -AirshipBuilder.DECK_L * 0.5 + 1.2)
	add_child(bar)
	_add_market()
	_add_boarding_ring()
	# Always here, open for business.
	_state = 2
	_t = 1.0
	_set_deck_active(true)
	_ladder_mi.visible = false
	_ladder_area.monitoring = false


## The market at the stern: the produce vendor and the gunsmith either side of
## the walk in from the boarding ring, facing each other across the deck.
func _add_market() -> void:
	var vendor := VendorCart.new()
	vendor.name = "Vendor"
	vendor.setup(WorldLayout.WEST)
	vendor.position = Vector3(-4.2, 0, 9.5)
	vendor.rotation.y = -PI * 0.5
	add_child(vendor)
	var shop := GunShop.new()
	shop.name = "GunShop"
	shop.setup(WorldLayout.WEST)
	shop.position = Vector3(4.2, 0, 9.5)
	shop.rotation.y = PI * 0.5
	add_child(shop)
	for sx: float in [-1.0, 1.0]:
		var sign := Label3D.new()
		sign.text = "MARKET" if sx < 0 else "GUNSMITH"
		sign.font_size = 96
		sign.outline_size = 18
		sign.modulate = Color("#FFE2B0")
		sign.outline_modulate = Color("#5C351D")
		sign.pixel_size = 0.01
		# Readable as you walk in from the boarding ring.
		sign.position = Vector3(sx * 4.2, AirshipBuilder.ROOF_Y - 0.9, 9.5)
		add_child(sign)


const RING_Y := 0.9
const RING_OUT := 1.6


## A big brass ring on a post at the stern gap in the railing: hook it with the
## grapple (left click) and the pull lands you on the deck.
func _add_boarding_ring() -> void:
	var at := Vector3(0, RING_Y, AirshipBuilder.DECK_L * 0.5 + RING_OUT)
	var st := MeshKit.begin()
	MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, RING_Y * 0.5 - 0.1, AirshipBuilder.DECK_L * 0.5 + RING_OUT)), 0.06, 0.08, RING_Y + 0.2, 10, Palette.WOOD_DARK)
	MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, -0.05, AirshipBuilder.DECK_L * 0.5 + RING_OUT * 0.5)), 0.5, 0.5, 0.12, 14, Palette.WOOD)
	var prev := Vector3.ZERO
	for i in 25:
		var a := TAU * i / 24.0
		var p := at + Vector3(cos(a) * 0.45, sin(a) * 0.45 + 0.45, 0)
		if i > 0:
			MeshKit.add_limb(st, prev, p, 0.06, Color("#D6A74A"), 8)
		prev = p
	var ring := MeshInstance3D.new()
	ring.mesh = MeshKit.finish(st)
	ring.material_override = Materials.toon(0.02)
	add_child(ring)
	var glow := OmniLight3D.new()
	glow.light_color = Palette.GLOW_YELLOW
	glow.light_energy = 1.5
	glow.omni_range = 6.0
	glow.position = at + Vector3(0, 0.45, 0.3)
	add_child(glow)
	var body := StaticBody3D.new()
	body.name = "BoardingRing"
	body.collision_layer = WorldLayout.LAYER_STRUCTURE
	add_child(body)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.1, 1.1, 0.3)
	col.shape = shape
	col.position = at + Vector3(0, 0.45, 0)
	body.add_child(col)
	var sign := Label3D.new()
	sign.text = "GRAPPLE HERE"
	sign.font_size = 64
	sign.outline_size = 14
	sign.modulate = Palette.GLOW_YELLOW
	sign.outline_modulate = Color("#7A2E22")
	sign.pixel_size = 0.012
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign.position = at + Vector3(0, -0.8, 0.3)
	add_child(sign)


func _bar_mesh() -> ArrayMesh:
	var st := MeshKit.begin()
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.55, 0)), Vector3(4.0, 1.1, 0.7), Palette.WOOD_DARK)
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 1.12, 0)), Vector3(4.2, 0.08, 0.9), Palette.WOOD)
	for k in 6:
		MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(-1.6 + k * 0.6, 1.3, -0.1)), 0.07, 0.06, 0.3, 6, Color("#5C8A3A") if k % 2 == 0 else Color("#7A2E22"))
	return MeshKit.finish(st)


func _aboard(p: Vector3) -> bool:
	var local := global_transform.affine_inverse() * p
	return absf(local.x) < AirshipBuilder.DECK_W * 0.5 + 1.5 and local.z > -AirshipBuilder.DECK_L * 0.5 - 1.0 \
			and local.z < AirshipBuilder.DECK_L * 0.5 + 2.0 and local.y > -HOVER - 0.5 and local.y < 4.0


func _set_deck_active(on: bool) -> void:
	_deck.process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED
	# The rope ladder is gone: you board by grappling the ring.
	_ladder_area.monitoring = false
	_ladder_mi.visible = false
	for c in get_children():
		if c is CasinoGame:
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
			position = _hover_pos + bob
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
