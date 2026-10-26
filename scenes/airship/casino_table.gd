class_name CasinoTable
extends CasinoGame
## A green-felt card table on the casino deck with a sign above it showing the
## last result. Subclasses add the game (blackjack, baccarat, roulette).

const BETS: Array = [10, 20, 50, 100]

var _label: Label3D


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
	Audio.play_at(&"pluck", global_position + Vector3.UP, -6.0)


func _shoe() -> Array[int]:
	return CasinoRules.new_shoe(_rng)
