class_name HudWavePreview
extends PanelContainer
## Under the phase plaque while you build: which bugs the coming wave brings and
## roughly how many of each, so you can build for it. Hidden during the wave.

const MAX_KINDS := 5


func _ready() -> void:
	var sb := KeyHints.card_style()
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	add_theme_stylebox_override("panel", sb)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Top-right corner, under the partner's homestead bar (out of the middle).
	anchor_left = 1.0
	anchor_right = 1.0
	grow_horizontal = Control.GROW_DIRECTION_BEGIN
	offset_top = 66 + (WorldLayout.cliff_count() - 2) * 50 # Maps: under every other cliff's bar
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
	col.add_theme_constant_override("separation", 4)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(col)
	var head_text := "WAVE %d BRINGS" % GameState.wave
	# (Bugs helper) How the wave arrives: steady stream, one big rush, two pushes...
	var shape := str(WavePlanner.SHAPE_NAMES.get(WaveDirector.preview_shape, ""))
	if shape != "":
		head_text = "WAVE %d  -  %s" % [GameState.wave, shape.to_upper()]
	var head := KeyHints.text(head_text, 12, Palette.BONE.darkened(0.3))
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(head)
	# A narrow column in the corner: one bug type per line.
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(row)
	for i in mini(mix.size(), MAX_KINDS):
		var id := StringName(str(mix[i][0]))
		var n := int(mix[i][1])
		var cell := HBoxContainer.new()
		cell.add_theme_constant_override("separation", 6)
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var icon := TextureRect.new()
		# Rendered under the HUD, not this panel (which clears its children).
		icon.texture = IconStudio.bug(get_parent(), id)
		icon.custom_minimum_size = Vector2(30, 30)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(icon)
		var words := VBoxContainer.new()
		words.add_theme_constant_override("separation", -2)
		words.alignment = BoxContainer.ALIGNMENT_CENTER
		words.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var bd := Defs.bug(id)
		# Kill-method variants stand out in their own shell colour.
		words.add_child(KeyHints.text(bd.display_name, 14, bd.shell_color.lightened(0.5) if bd.is_variant() else Palette.BONE))
		words.add_child(KeyHints.text(amount_word(n), 12, Palette.GLOW_YELLOW))
		cell.add_child(words)
		row.add_child(cell)
	if mix.size() > MAX_KINDS:
		row.add_child(KeyHints.text("+%d more" % (mix.size() - MAX_KINDS), 13, Palette.BONE.darkened(0.25)))
	_center.call_deferred()


## Fits the content and centres the panel under the plaque.
func _center() -> void:
	size = get_combined_minimum_size()
	offset_right = -20.0
	offset_left = -20.0 - size.x
