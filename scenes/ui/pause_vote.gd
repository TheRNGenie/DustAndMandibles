class_name PauseVote
extends CanvasLayer
## Vote to pause. Each player can press "Vote to pause" in the Esc menu; once
## every player in the game has voted, the whole game freezes on every screen
## and a "PAUSED" sign comes up with an Unpause button and one box per player.
## A box starts red and turns green when that player presses Unpause; when
## every box is green the game carries on. The host keeps the tally.

signal votes_changed

static var instance: PauseVote

## peer id -> true, while gathering votes to pause.
var votes: Dictionary = {}
## peer id -> true, once paused: who has pressed Unpause.
var ready_ids: Dictionary = {}
var paused := false
var _root: Control
var _boxes: HBoxContainer
var _status: Label


func _ready() -> void:
	instance = self
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_root.visible = false


## Everyone in the game (host included); just you when playing alone.
func _peers() -> Array[int]:
	var out: Array[int] = []
	if NetworkManager.is_online():
		for id: int in NetworkManager.players:
			out.append(id)
	if out.is_empty():
		out.append(multiplayer.get_unique_id())
	out.sort()
	return out


func vote_count_text() -> String:
	return "%d / %d voted" % [votes.size(), _peers().size()]


func has_voted() -> bool:
	return votes.has(multiplayer.get_unique_id())


# ------------------------------------------------------------------ voting

## Local: toggle my vote to pause.
func toggle_vote() -> void:
	if multiplayer.is_server():
		_host_vote(multiplayer.get_unique_id())
	else:
		_request_vote.rpc_id(1)


@rpc("any_peer", "reliable")
func _request_vote() -> void:
	if multiplayer.is_server():
		_host_vote(multiplayer.get_remote_sender_id())


func _host_vote(id: int) -> void:
	if paused:
		return
	if votes.has(id):
		votes.erase(id)
	else:
		votes[id] = true
	var everyone := true
	for p in _peers():
		if not votes.has(p):
			everyone = false
	if everyone:
		_set_paused.rpc(true)
	else:
		_sync_votes.rpc(votes)


@rpc("authority", "call_local", "reliable")
func _sync_votes(v: Dictionary) -> void:
	votes = v
	votes_changed.emit()


# ------------------------------------------------------------------ paused

@rpc("authority", "call_local", "reliable")
func _set_paused(on: bool) -> void:
	paused = on
	votes.clear()
	ready_ids.clear()
	get_tree().paused = on
	_root.visible = on
	GameState.menu_open = on
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if on else Input.MOUSE_MODE_CAPTURED
	var pm := get_parent().get_node_or_null("PauseMenu") as PauseMenu
	if pm == null:
		pm = get_tree().current_scene.get_node_or_null("PauseMenu") as PauseMenu
	if on and pm != null and pm.is_open():
		pm.close()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		GameState.menu_open = true
	Audio.play_ui(&"bell", -8.0)
	_refresh()
	votes_changed.emit()


## Local: I'm ready to carry on.
func press_unpause() -> void:
	if multiplayer.is_server():
		_host_unpause(multiplayer.get_unique_id())
	else:
		_request_unpause.rpc_id(1)


@rpc("any_peer", "reliable")
func _request_unpause() -> void:
	if multiplayer.is_server():
		_host_unpause(multiplayer.get_remote_sender_id())


func _host_unpause(id: int) -> void:
	if not paused:
		return
	ready_ids[id] = true
	_sync_ready.rpc(ready_ids)
	var everyone := true
	for p in _peers():
		if not ready_ids.has(p):
			everyone = false
	if everyone:
		# A short beat so the last box visibly turns green first.
		get_tree().create_timer(0.6, true, false, true).timeout.connect(func() -> void: _set_paused.rpc(false))


@rpc("authority", "call_local", "reliable")
func _sync_ready(r: Dictionary) -> void:
	ready_ids = r
	_refresh()


# ------------------------------------------------------------------ the screen

func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0.08, 0.04, 0.03, 0.62)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)
	var poster := PanelContainer.new()
	poster.add_theme_stylebox_override("panel", UiStyle.poster())
	poster.custom_minimum_size = Vector2(520, 300)
	center.add_child(poster)
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 18)
	poster.add_child(col)
	var title := UiStyle.label("PAUSED", 54, Palette.OUTLINE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	_boxes = HBoxContainer.new()
	_boxes.alignment = BoxContainer.ALIGNMENT_CENTER
	_boxes.add_theme_constant_override("separation", 14)
	col.add_child(_boxes)
	_status = UiStyle.label("", 16, Palette.OUTLINE)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_status)
	var row := CenterContainer.new()
	col.add_child(row)
	var unpause := UiStyle.button("Unpause")
	unpause.custom_minimum_size = Vector2(200, 48)
	unpause.pressed.connect(press_unpause)
	row.add_child(unpause)


## One box per player: red until they press Unpause, then green.
func _refresh() -> void:
	for c in _boxes.get_children():
		c.queue_free()
	var peers := _peers()
	for id in peers:
		var cell := VBoxContainer.new()
		cell.alignment = BoxContainer.ALIGNMENT_CENTER
		var box := Panel.new()
		box.custom_minimum_size = Vector2(76, 76)
		var sb := StyleBoxFlat.new()
		var go := ready_ids.has(id)
		sb.bg_color = Color("#3FAE4A") if go else Color("#C23A2C")
		sb.border_color = Palette.OUTLINE
		sb.set_border_width_all(4)
		sb.set_corner_radius_all(8)
		box.add_theme_stylebox_override("panel", sb)
		cell.add_child(box)
		var name_l := UiStyle.label(_name_of(id), 14, Palette.OUTLINE)
		name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cell.add_child(name_l)
		_boxes.add_child(cell)
	_status.text = "%d of %d ready to carry on" % [ready_ids.size(), peers.size()]


func _name_of(id: int) -> String:
	var p: Variant = NetworkManager.players.get(id)
	if p is Dictionary:
		return str((p as Dictionary).get("name", "P%d" % id)).substr(0, 12)
	return "You" if id == multiplayer.get_unique_id() else "P%d" % id
