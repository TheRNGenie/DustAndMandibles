class_name CasinoTable
extends CasinoGame
## A green-felt card table on the casino deck with a sign above it showing the
## last result. Subclasses add the game (blackjack, baccarat, roulette).

const BETS: Array = [10, 20, 50, 100]
const TABLE_ART := preload("res://gen/casino_table_art.gd")

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
	# The table itself (gen/casino_table_art.gd): shaped printed felt, padded
	# leather rail, brass and mahogany, pedestals, the dealer's kit and the sign.
	var size := TABLE_ART.build(self, _art_kind(), ui_title())
	var st := MeshKit.begin()
	_decorate(st)
	var deco := MeshInstance3D.new()
	deco.mesh = MeshKit.finish(st)
	deco.material_override = Materials.toon(0.015)
	add_child(deco)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(size.x + 0.28, 1.0, size.y + 0.28)
	col.shape = shape
	col.position.y = 0.5
	add_child(col)
	# (The sign's lettering is part of the art; the result label stays as before for subclasses that read it.)
	_label = Label3D.new()
	_label.visible = false
	add_child(_label)


## Which table the art builds (see gen/casino_table_art.gd KINDS).
func _art_kind() -> String:
	return "shell"


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
