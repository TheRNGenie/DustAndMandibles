class_name CasinoTable
extends StaticBody3D
## A green-felt card table on the casino deck with a sign above it showing the
## last hand. Subclasses (blackjack, baccarat, roulette) fill in the game:
## E and F go to the host as actions; the host settles bets from the player's
## cliff stockpile (scrap) and broadcasts the table text.

const BET := 20

var title := "TABLE"
var _label: Label3D
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	collision_layer = WorldLayout.LAYER_STRUCTURE
	collision_mask = 0
	var st := MeshKit.begin()
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.45, 0)), Vector3(1.6, 0.9, 0.9), Palette.WOOD_DARK)
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.93, 0)), Vector3(1.9, 0.08, 1.15), Palette.WOOD)
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.975, 0)), Vector3(1.7, 0.02, 0.95), Color("#2E6B3A"))
	_decorate(st)
	var mi := MeshInstance3D.new()
	mi.mesh = MeshKit.finish(st)
	mi.material_override = Materials.toon(0.015)
	add_child(mi)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.9, 1.0, 1.15)
	col.shape = shape
	col.position.y = 0.5
	add_child(col)
	_label = Label3D.new()
	_label.font_size = 34
	_label.outline_size = 8
	_label.modulate = Palette.GLOW_YELLOW
	_label.outline_modulate = Palette.OUTLINE
	_label.pixel_size = 0.0045
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.position = Vector3(0, 1.75, 0)
	_label.text = title
	add_child(_label)


## Extra table dressing (chips, a wheel...).
func _decorate(_st: SurfaceTool) -> void:
	pass


func local_interact(holding: bool) -> void:
	if holding:
		return
	_send(&"e", _local_choice())


func cycle_option() -> void:
	_on_f()


## What the local player has selected (bet type), sent with E.
func _local_choice() -> int:
	return 0


## F pressed locally. Default: nothing.
func _on_f() -> void:
	pass


func _send(action: StringName, arg: int) -> void:
	if multiplayer.is_server():
		_act(multiplayer.get_unique_id(), action, arg)
	else:
		_request.rpc_id(1, action, arg)


@rpc("any_peer", "reliable")
func _request(action: StringName, arg: int) -> void:
	if multiplayer.is_server():
		_act(multiplayer.get_remote_sender_id(), action, arg)


## Host: a player acted at the table.
func _act(_peer_id: int, _action: StringName, _arg: int) -> void:
	pass


func _cliff(peer_id: int) -> int:
	return NetworkManager.cliff_of(peer_id)


func _take_bet(peer_id: int) -> bool:
	if Economy.spend(_cliff(peer_id), {&"scrap": BET}):
		return true
	Economy.notify(peer_id, "You need %d scrap to sit down." % BET)
	return false


func _pay(peer_id: int, amount: int) -> void:
	if amount > 0:
		Economy.earn(_cliff(peer_id), {&"scrap": amount})


func _hand_text(hand: Array) -> String:
	var parts: PackedStringArray = []
	for i in hand.size():
		parts.append(CasinoRules.card_text(int(hand[i]), i + int(hand[i])))
	return " ".join(parts)


func _shoe() -> Array[int]:
	return CasinoRules.new_shoe(_rng)


@rpc("authority", "call_local", "reliable")
func _show(text: String, sound: StringName) -> void:
	_label.text = "%s\n%s" % [title, text]
	if sound != &"":
		Audio.play_at(sound, global_position + Vector3.UP, -4.0)
