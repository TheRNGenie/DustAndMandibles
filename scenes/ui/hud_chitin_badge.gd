class_name HudChitinBadge
extends PanelContainer
## The round's takings, in place of the old kill lines ("X saved Y from a Wolf
## Spider (+4 Chitin to Y)", Logan: too much text in the way). A small plate at
## the top of the right-hand feed: the Chitin icon and "+N", counting up with
## every bug the turrets (or anyone) kill this round, into the team pot.
##   - Hidden until the round's first kill; then it shows "This Round +N".
##   - Each kill rolls the number up (quickly, so a burst reads as a count, not
##     a jump), gives the plate a small pop and lifts a faint "+4" off it.
##   - When the round ends it turns to "Round Total +N" with a gold flash, holds
##     a few seconds and fades. The next round starts again from +0.

const HOLD := 5.0
## Rolls at least this fast (per second), faster when far behind.
const ROLL_MIN := 20.0

var _icon: Control
var _caption: Label
var _num: Label
var _target := 0
var _shown := 0.0
var _hold_t := -1.0
var _pop := 0.0
var _round_over := false
var _spare_t := 0.0


func _ready() -> void:
	add_theme_stylebox_override("panel", KeyHints.kit_box("plate_tight"))
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_horizontal = Control.SIZE_SHRINK_END
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)
	_icon = UiStyle.resource_chip(ResNames.TEAM_ID, 24)
	_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_icon)
	var words := VBoxContainer.new()
	words.add_theme_constant_override("separation", -2)
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(words)
	_caption = KeyHints.eyebrow("This Round", 12)
	words.add_child(_caption)
	_num = KeyHints.number("+0", 24)
	_num.add_theme_color_override("font_color", UiStyle.c("accent_hi"))
	words.add_child(_num)
	visible = false
	modulate.a = 0.0
	GameState.phase_changed.connect(_on_phase)


func _exit_tree() -> void:
	if GameState.phase_changed.is_connected(_on_phase):
		GameState.phase_changed.disconnect(_on_phase)


## A kill paid `amount` into the pot.
func add(amount: int) -> void:
	if amount <= 0:
		return
	if _round_over:
		_reset() # a straggler after the round: start the next count
	_target += amount
	if not visible:
		visible = true
		modulate.a = 1.0
	_hold_t = -1.0
	_pop = 1.0
	if _spare_t <= 0.0:
		_spare_t = 0.12
		_float_up("+%d" % amount)


func _on_phase(p: GameState.Phase) -> void:
	if p == GameState.Phase.WAVE:
		_reset()
	elif _target > 0 and not _round_over and p != GameState.Phase.WARNING:
		# The round's over: the total, a flash, then it fades.
		_round_over = true
		_caption.text = "Round Total"
		_hold_t = HOLD
		_pop = 1.0
		var tw := create_tween()
		self_modulate = Color(1.6, 1.35, 0.7)
		tw.tween_property(self, "self_modulate", Color.WHITE, 0.8)


func _reset() -> void:
	_round_over = false
	_target = 0
	_shown = 0.0
	_hold_t = -1.0
	_caption.text = "This Round"
	_num.text = "+0"
	visible = false
	modulate.a = 0.0


func _process(delta: float) -> void:
	if not visible:
		return
	_spare_t -= delta
	# Roll the number up to the total.
	if _shown < float(_target):
		var behind := float(_target) - _shown
		_shown = minf(_shown + maxf(ROLL_MIN, behind * 6.0) * delta, float(_target))
		_num.text = "+%d" % int(_shown)
	# A small pop on each kill.
	_pop = move_toward(_pop, 0.0, delta * 5.0)
	pivot_offset = size * 0.5
	scale = Vector2.ONE * (1.0 + 0.1 * _pop * _pop)
	# After the round: hold, then fade away.
	if _hold_t >= 0.0:
		_hold_t -= delta
		if _hold_t < 1.0:
			modulate.a = maxf(_hold_t, 0.0)
		if _hold_t <= 0.0:
			_reset()


## A faint "+4" lifting off the badge.
func _float_up(text: String) -> void:
	var l := KeyHints.number(text, 16)
	l.add_theme_color_override("font_color", Color(UiStyle.c("accent_hi"), 0.9))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.top_level = true
	add_child(l)
	var at := global_position + Vector2(-l.get_combined_minimum_size().x - 6.0, size.y * 0.25)
	l.global_position = at
	var tw := l.create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "global_position:y", at.y - 22.0, 0.9).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 0.9).set_delay(0.25)
	tw.chain().tween_callback(l.queue_free)
