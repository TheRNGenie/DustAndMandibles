class_name CasinoTable
extends CasinoGame
## A green-felt card table on the casino deck with a sign above it showing the
## last result. Subclasses add the game (blackjack, baccarat, roulette).

const BETS: Array = [10, 20, 50, 100]

var _label: Label3D
## Every peer: when each card on the felt is (or was) dealt, in local seconds,
## keyed by the table's own names ("h0:1", "d:0", "flip"...), so the screen can
## slide them in one by one however often it is rebuilt.
var deal_times: Dictionary = {}
var deal_last := 0.0
var _deal_round := -1
const DEAL_GAP := 0.42


func _ready() -> void:
	super._ready()
	var st := MeshKit.begin()
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.45, 0)), Vector3(1.6, 0.9, 0.9), Palette.WOOD_DARK)
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.93, 0)), Vector3(1.9, 0.08, 1.15), Palette.WOOD)
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.975, 0)), Vector3(1.7, 0.02, 0.95), Color("#2E6B3A"))
	# Painted name board standing at the back edge of the table.
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 1.22, 0.52)), Vector3(1.3, 0.42, 0.05), Palette.WOOD_DARK)
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 1.22, 0.495)), Vector3(1.2, 0.34, 0.02), Palette.BONE)
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
	_label.font_size = 56
	_label.outline_size = 0
	_label.modulate = Color("#3A2416")
	_label.pixel_size = 0.0035
	_label.position = Vector3(0, 1.22, 0.48)
	_label.rotation.y = PI
	_label.double_sided = false
	_label.text = ui_title().to_upper()
	add_child(_label)


func _decorate(_st: SurfaceTool) -> void:
	pass


func ui_bets() -> Array:
	return BETS


func _on_view() -> void:
	Audio.play_at(&"card_flick", global_position + Vector3.UP, -4.0)


func _shoe() -> Array[int]:
	return CasinoRules.new_shoe(_rng)


## Host: pay out after the table's animation (shell game, beetle race).
func _pay_later(peer_id: int, amounts: Dictionary, seconds: float) -> void:
	if amounts.is_empty():
		return
	get_tree().create_timer(seconds, false).timeout.connect(_pay.bind(peer_id, amounts))


## Every peer: stamps the cards in `keys` (in dealing order) that are new this
## view; a new round clears the felt first.
func stamp_deal(round_id: int, keys: Array, gap: float = DEAL_GAP) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if round_id != _deal_round:
		_deal_round = round_id
		deal_times.clear()
		deal_last = now - gap + 0.1
	for k: Variant in keys:
		if deal_times.has(k):
			continue
		deal_last = maxf(now, deal_last + gap)
		deal_times[k] = deal_last


## The dealing animation's length for this view (cards still to land + a beat).
func deal_anim_length() -> float:
	return deal_last + 0.45 - view_at


## A card's look-only suit, the same on every peer.
static func card_suit(round_id: int, key: String) -> int:
	return absi(hash("%d/%s" % [round_id, key])) % 4
