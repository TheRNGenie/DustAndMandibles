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
	return "%d / %d Voted" % [votes.size(), _peers().size()]


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
	if on:
		UiStyle.fade_in(_root)
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
	UiStyle.fit(_root) # Theme: bigger on 1440p and up
	add_child(_root)
	_root.add_child(UiStyle.scrim())
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)
	var frame := UiStyle.panel("FramePanel")
	frame.custom_minimum_size = Vector2(540, 0)
	center.add_child(frame)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 0)
	frame.add_child(outer)
	outer.add_child(UiStyle.strap("Paused", "The game waits until every rider presses Unpause.", 30))
	var card := UiStyle.panel("PaperPanel")
	outer.add_child(card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", UiStyle.GAP_GROUP)
	card.add_child(col)
	_boxes = HBoxContainer.new()
	_boxes.alignment = BoxContainer.ALIGNMENT_CENTER
	_boxes.add_theme_constant_override("separation", UiStyle.GAP_GROUP)
	col.add_child(_boxes)
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", UiStyle.GAP_GROUP)
	col.add_child(footer)
	_status = UiStyle.label("", 16)
	_status.theme_type_variation = "SoftInkLabel"
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(_status)
	var unpause := MenuScreen.wood_button("Unpause")
	unpause.pressed.connect(press_unpause)
	footer.add_child(unpause)


## One card per player: a tick and "Ready" once they press Unpause, else a cross and "Waiting".
func _refresh() -> void:
	for c in _boxes.get_children():
		c.queue_free()
	var peers := _peers()
	for id in peers:
		var go := ready_ids.has(id)
		var cell := UiStyle.panel("CardPanel")
		cell.custom_minimum_size = Vector2(120, 0)
		var v := VBoxContainer.new()
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		v.add_theme_constant_override("separation", 4)
		cell.add_child(v)
		var m := UiStyle.mark("good" if go else "bad", UiStyle.c("good") if go else UiStyle.c("bad"), 34)
		m.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(m)
		var name_l := UiStyle.label(_name_of(id), 16)
		name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(name_l)
		var state := UiStyle.label("Ready" if go else "Waiting", 14, UiStyle.c("good") if go else UiStyle.c("ink_soft"))
		state.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(state)
		_boxes.add_child(cell)
	_status.text = "%d of %d Ready to Carry On" % [ready_ids.size(), peers.size()]


func _name_of(id: int) -> String:
	var p: Variant = NetworkManager.players.get(id)
	if p is Dictionary:
		return str((p as Dictionary).get("name", "P%d" % id)).substr(0, 12)
	return "You" if id == multiplayer.get_unique_id() else "P%d" % id
