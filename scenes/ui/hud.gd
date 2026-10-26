class_name Hud
extends CanvasLayer
## HUD root: crosshair, ammo sign, phase banner, canyon-fall message and the F3 debug
## overlay, plus HudStatus (health, resources, Homesteads) and HudFeed (kill feed, prompts).

var _ammo_label: Label
var _center_label: Label
var _debug_label: Label
var _speed_lines: SpeedLines
var _crosshair: Control
var _phase_label: Label
var _hint_label: Label
var status: HudStatus
var feed: HudFeed
var hotbar: HudHotbar
var build_menu: HudBuildMenu

const PHASE_NAMES := {
	GameState.Phase.LOBBY: "Waiting for riders",
	GameState.Phase.BUILD: "DAYBREAK",
	GameState.Phase.WARNING: "DUST ON THE HORIZON",
	GameState.Phase.WAVE: "SUNDOWN",
	GameState.Phase.GAME_OVER: "THE END",
}


func _ready() -> void:
	status = HudStatus.new()
	add_child(status)
	feed = HudFeed.new()
	add_child(feed)
	hotbar = HudHotbar.new()
	add_child(hotbar)
	build_menu = HudBuildMenu.new()
	add_child(build_menu)
	_speed_lines = SpeedLines.new()
	_speed_lines.set_anchors_preset(Control.PRESET_FULL_RECT)
	_speed_lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_speed_lines)
	_crosshair = Crosshair.new()
	_crosshair.set_anchors_preset(Control.PRESET_FULL_RECT)
	_crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_crosshair)

	var ammo_sign := PanelContainer.new()
	ammo_sign.add_theme_stylebox_override("panel", wood_sign_style())
	ammo_sign.anchor_left = 1.0
	ammo_sign.anchor_right = 1.0
	ammo_sign.anchor_top = 1.0
	ammo_sign.anchor_bottom = 1.0
	ammo_sign.offset_left = -190
	ammo_sign.offset_top = -86
	ammo_sign.offset_right = -24
	ammo_sign.offset_bottom = -24
	add_child(ammo_sign)
	_ammo_label = Label.new()
	_ammo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ammo_label.add_theme_font_size_override("font_size", 30)
	_ammo_label.add_theme_color_override("font_color", Palette.BONE)
	ammo_sign.add_child(_ammo_label)

	_center_label = Label.new()
	_center_label.set_anchors_preset(Control.PRESET_CENTER)
	_center_label.offset_left = -300
	_center_label.offset_right = 300
	_center_label.offset_top = 60
	_center_label.offset_bottom = 110
	_center_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_center_label.add_theme_font_size_override("font_size", 28)
	_center_label.add_theme_color_override("font_color", Palette.GLOW_YELLOW)
	_center_label.add_theme_color_override("font_outline_color", Palette.OUTLINE)
	_center_label.add_theme_constant_override("outline_size", 8)
	add_child(_center_label)

	var banner := PanelContainer.new()
	banner.add_theme_stylebox_override("panel", wood_sign_style())
	banner.anchor_left = 0.5
	banner.anchor_right = 0.5
	banner.offset_left = -230
	banner.offset_right = 230
	banner.offset_top = 14
	add_child(banner)
	_phase_label = Label.new()
	_phase_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_phase_label.add_theme_font_size_override("font_size", 24)
	_phase_label.add_theme_color_override("font_color", Palette.BONE)
	banner.add_child(_phase_label)
	_hint_label = Label.new()
	_hint_label.anchor_left = 0.5
	_hint_label.anchor_right = 0.5
	_hint_label.offset_left = -300
	_hint_label.offset_right = 300
	_hint_label.offset_top = 70
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.add_theme_font_size_override("font_size", 18)
	_hint_label.add_theme_color_override("font_color", Palette.BONE)
	_hint_label.add_theme_color_override("font_outline_color", Palette.OUTLINE)
	_hint_label.add_theme_constant_override("outline_size", 6)
	add_child(_hint_label)
	GameState.phase_changed.connect(func(_p: GameState.Phase) -> void: _flash_phase())
	GameState.skip_votes_changed.connect(func(_v: int, _n: int) -> void: _update_hint())

	_debug_label = Label.new()
	_debug_label.position = Vector2(12, 12)
	_debug_label.add_theme_color_override("font_color", Color.WHITE)
	_debug_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_debug_label.add_theme_constant_override("outline_size", 4)
	_debug_label.visible = false
	add_child(_debug_label)


## Hooks the HUD up to a local player.
func bind_player(player: Player, bugs: BugManager, builds: BuildManager) -> void:
	status.bind_player(player)
	feed.bind_player(player, bugs, builds)
	build_menu.bind(player.build_mode)
	player.gun.ammo_changed.connect(_on_ammo_changed)
	player.gun.hit_confirmed.connect(func(weak: bool) -> void: (_crosshair as Crosshair).flash(weak))
	player.gun.reload_started.connect(func(_d: float) -> void: _ammo_label.text = "Reloading")
	player.fell_into_canyon.connect(func(delay: float) -> void:
		if delay > 0.0:
			_show_message("SPLAT. Hauling you back up..."))
	_speed_lines.player = player
	player.fall_landed.connect(func() -> void: _speed_lines.flash())
	player.respawned.connect(func() -> void: _center_label.text = "")
	_on_ammo_changed(player.gun.ammo, player.gun.def.mag_size)


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("debug_overlay"):
		_debug_label.visible = not _debug_label.visible
	_update_phase_label()
	if _debug_label.visible:
		var role := "offline"
		if NetworkManager.is_online():
			role = "host" if multiplayer.is_server() else "client"
		_debug_label.text = "FPS %d\nDraw calls %d\nPeer %d (%s)\nPing %d ms\nPlayers %d" % [
			Engine.get_frames_per_second(),
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
			multiplayer.get_unique_id(), role, NetworkManager.get_ping_ms(),
			get_tree().get_nodes_in_group("players").size()]


func _update_phase_label() -> void:
	var title: String = PHASE_NAMES.get(GameState.phase, "")
	if DayCycle.instance != null and (GameState.phase == GameState.Phase.BUILD or GameState.phase == GameState.Phase.WAVE):
		title = DayCycle.instance.stage_name()
	var secs := int(ceilf(GameState.time_left))
	if GameState.phase == GameState.Phase.LOBBY:
		_phase_label.text = title
	elif GameState.phase == GameState.Phase.WAVE:
		_phase_label.text = "Wave %d  -  %s  -  %d bugs left" % [GameState.wave, title, get_tree().get_nodes_in_group("bugs").size()]
	else:
		_phase_label.text = "Wave %d  -  %s  -  %d:%02d" % [GameState.wave, title, secs / 60, secs % 60]


func _flash_phase() -> void:
	_update_hint()
	var tw := create_tween()
	_phase_label.scale = Vector2(1.15, 1.15)
	tw.tween_property(_phase_label, "scale", Vector2.ONE, 0.25)


func _update_hint() -> void:
	match GameState.phase:
		GameState.Phase.BUILD:
			_hint_label.text = "Build up your partner's defenses. Press G when ready (%d/%d)" % [
				GameState.skip_votes, maxi(NetworkManager.players.size(), 1)]
		GameState.Phase.WARNING:
			_hint_label.text = "The bridge is coming up! Get back to your own cliff."
		GameState.Phase.WAVE:
			_hint_label.text = "Bugs are climbing. Cover your partner's cliff!"
		_:
			_hint_label.text = ""


func _on_ammo_changed(current: int, max_ammo: int) -> void:
	_ammo_label.text = "%d / %d" % [current, max_ammo]


func _show_message(text: String) -> void:
	_center_label.text = text


## Wooden sign panel (StyleBoxFlat only, no textures).
static func wood_sign_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Palette.WOOD
	sb.border_color = Palette.OUTLINE
	sb.set_border_width_all(4)
	sb.set_corner_radius_all(6)
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 4
	sb.shadow_offset = Vector2(3, 3)
	sb.set_content_margin_all(10)
	return sb


## A small cross with a dark outline, drawn in code.
class Crosshair extends Control:
	var marker := 0.0
	var marker_weak := false

	func flash(weak: bool) -> void:
		marker = 1.0
		marker_weak = weak
		queue_redraw()

	func _process(delta: float) -> void:
		if marker > 0.0:
			marker = maxf(marker - delta * 5.0, 0.0)
			queue_redraw()

	func _draw() -> void:
		var c := size * 0.5
		if marker > 0.0:
			# Hit marker: an X that pops when your shot lands.
			var mc := (Palette.GLOW_YELLOW if marker_weak else Color.WHITE) * Color(1, 1, 1, marker)
			for d: Vector2 in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
				draw_line(c + d * 7.0, c + d * 15.0, mc, 3.0)
		for pass_i in 2:
			var col := Palette.OUTLINE if pass_i == 0 else Palette.BONE
			var w := 4.0 if pass_i == 0 else 2.0
			draw_line(c + Vector2(-10, 0), c + Vector2(-4, 0), col, w)
			draw_line(c + Vector2(4, 0), c + Vector2(10, 0), col, w)
			draw_line(c + Vector2(0, -10), c + Vector2(0, -4), col, w)
			draw_line(c + Vector2(0, 4), c + Vector2(0, 10), col, w)

	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED:
			queue_redraw()


## Streaks rushing past the edges of the screen while you fall (and a white
## flash on impact). Only the outer ring of the screen, so you can still see.
class SpeedLines extends Control:
	var player: Player
	var _lines: Array = []
	var _flash := 0.0

	func _ready() -> void:
		for i in 70:
			_lines.append([randf() * TAU, randf(), randf_range(0.6, 1.4)])

	func _process(delta: float) -> void:
		if player == null:
			return
		if player.fall_intensity > 0.02 or _flash > 0.0:
			for l: Array in _lines:
				l[1] = fposmod(float(l[1]) + delta * (1.5 + player.fall_intensity * 5.0) * float(l[2]), 1.0)
			queue_redraw()
		_flash = maxf(_flash - delta * 2.5, 0.0)
		if player.fall_intensity <= 0.02 and _flash <= 0.0:
			queue_redraw()

	func flash() -> void:
		_flash = 1.0

	func _draw() -> void:
		if player == null:
			return
		var k := player.fall_intensity
		if k > 0.02:
			var c := size * 0.5
			var r_max := c.length()
			for l: Array in _lines:
				var a := float(l[0])
				var dir := Vector2(cos(a), sin(a))
				# Lines start in the outer ring and race outward.
				var t := float(l[1])
				var r0 := lerpf(0.55, 1.0, t) * r_max
				var len := r_max * (0.08 + 0.25 * k) * float(l[2])
				var col := Color(1, 1, 1, 0.55 * k * (1.0 - t * 0.6))
				draw_line(c + dir * r0, c + dir * (r0 + len), col, 2.0 + 3.0 * k)
		if _flash > 0.0:
			draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 0.95, _flash * 0.85))
