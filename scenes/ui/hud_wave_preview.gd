class_name HudWavePreview
extends PanelContainer
## Top-right, under the other cliffs' Homestead plates while you build: which
## bugs the coming wave brings and roughly how many of each, so you can build
## for it. Hidden during the wave.

const MAX_KINDS := 5
const WIDTH := 300.0


func _ready() -> void:
	add_theme_stylebox_override("panel", KeyHints.kit_box("plate"))
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Top-right corner, under the other cliffs' plates (out of the middle).
	anchor_left = 1.0
	anchor_right = 1.0
	grow_horizontal = Control.GROW_DIRECTION_BEGIN
	offset_top = HudStatus.right_stack_bottom() + 10.0
	offset_right = -24.0
	offset_left = -24.0 - WIDTH
	custom_minimum_size.x = WIDTH
	visible = false
	WaveDirector.wave_previewed.connect(func(_m: Array) -> void: _rebuild())
	GameState.phase_changed.connect(func(_p: GameState.Phase) -> void: _rebuild())
	_rebuild()


## How many, in words: the mix matters more than the exact count.
static func amount_word(n: int) -> String:
	if n <= 3:
		return "a few"
	if n <= 12:
		return "some"
	if n <= 40:
		return "many"
	if n <= 120:
		return "a horde"
	return "a swarm"


func _rebuild() -> void:
	for c in get_children():
		remove_child(c)
		c.queue_free()
	var mix: Array = WaveDirector.preview
	visible = GameState.phase in [GameState.Phase.BUILD, GameState.Phase.WARNING] and not mix.is_empty()
	if not visible:
		return
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", UiStyle.GAP_ROW)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(col)
	# WAVE 3 BRINGS ............ A STEADY STREAM
	var head := HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(head)
	var title := KeyHints.eyebrow("Wave %d Brings" % GameState.wave, 14)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	# (Bugs helper) How the wave arrives: steady stream, one big rush, two pushes...
	var shape := str(WavePlanner.SHAPE_NAMES.get(WaveDirector.preview_shape, ""))
	if shape != "":
		var sh := KeyHints.ink(UiStyle.tc(shape), 14, true)
		sh.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		head.add_child(sh)
	# One bug type per line: its picture in a well, its name, how many in words.
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 4)
	rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(rows)
	for i in mini(mix.size(), MAX_KINDS):
		var id := StringName(str(mix[i][0]))
		var n := int(mix[i][1])
		var cell := HBoxContainer.new()
		cell.add_theme_constant_override("separation", 10)
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var well := KeyHints.plate("well")
		var icon := TextureRect.new()
		# Rendered under the HUD, not this panel (which clears its children).
		icon.texture = IconStudio.bug(get_parent(), id)
		icon.custom_minimum_size = Vector2(30, 30)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		well.add_child(icon)
		cell.add_child(well)
		var bd := Defs.bug(id)
		# Kill-method variants stand out in their own shell colour.
		var name_l := KeyHints.ink(UiStyle.tc(bd.display_name), 15)
		name_l.add_theme_font_override("font", UiStyle.font("bold"))
		if bd.is_variant():
			name_l.add_theme_color_override("font_color", bd.shell_color.lightened(0.5))
		name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		cell.add_child(name_l)
		var amt := KeyHints.eyebrow(amount_word(n), 13)
		amt.theme_type_variation = "SoftInkLabel"
		amt.add_theme_font_override("font", UiStyle.font("label"))
		cell.add_child(amt)
		rows.add_child(cell)
	if mix.size() > MAX_KINDS:
		rows.add_child(KeyHints.ink("+%d More" % (mix.size() - MAX_KINDS), 13, true))
	# Balance pass: next wave's boss, a build phase early.
	for id: Variant in WaveDirector.next_boss:
		var bd := Defs.bug(StringName(str(id)))
		if bd != null:
			var warn := UiStyle.status(UiStyle.tc("Next wave: %s" % bd.display_name), "warn", 14, true)
			col.add_child(warn)
	_center.call_deferred()


## Fits the content's height and keeps the card pinned to the right edge.
func _center() -> void:
	size = Vector2(WIDTH, get_combined_minimum_size().y)
	offset_right = -24.0
	offset_left = -24.0 - WIDTH
