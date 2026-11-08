class_name StoryTracker
extends PanelContainer
## Story: the chapter's goal in the top-left corner: chapter and title, the
## objective, and how it stands (night 2 of 5; the valve on the plateau / on
## Tom's back / fitted; 9 of 12 sacks of silver left; 7 of 8 scaffold storeys). Local; it reads the
## StoryDirector's synced state.

var director: StoryDirector
var _head: Label
var _goal: Label
var _status: Label
var _mark: UiStyle.Mark


func _ready() -> void:
	add_theme_stylebox_override("panel", KeyHints.kit_box("plate"))
	add_to_group("story_tracker") # the partner alerts card sits under it
	anchor_left = 0.0
	anchor_top = 0.0
	offset_left = 24
	offset_top = HudStatus.HOME_TOP + HudStatus.HOME_STEP + 4.0 # under your Homestead plate
	custom_minimum_size = Vector2(400, 0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 3)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(col)
	_head = KeyHints.eyebrow("", 13)
	col.add_child(_head)
	_goal = UiStyle.label("", 17)
	_goal.theme_type_variation = "GoldLabel"
	_goal.add_theme_font_override("font", UiStyle.font("bold"))
	_goal.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_goal.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_goal.custom_minimum_size.x = 380
	col.add_child(_goal)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(row)
	_mark = UiStyle.mark("info", UiStyle.status_color("info", true), 12)
	_mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_mark)
	_status = UiStyle.label("", 15)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size.x = 360
	row.add_child(_status)
	refresh()


func _process(_delta: float) -> void:
	# The carrier line and the hold reminder change without a phase change.
	if Engine.get_process_frames() % 20 == 0:
		refresh()


func refresh() -> void:
	if director == null or director.chapter == null or _goal == null:
		return
	var ch := director.chapter
	_head.text = "Chapter %d  ·  %s" % [ch.number, ch.title]
	_goal.text = ch.objective_text()
	var night := clampi(GameState.wave - ch.first_wave + 1, 1, ch.wave_count())
	var nights := "Night %d of %d" % [night, ch.wave_count()]
	var text := nights
	var kind := "info"
	match ch.kind():
		"fetch":
			var item := director.item_name()
			match director.cargo_state:
				StoryDirector.Cargo.NONE:
					text = "%s  ·  %s" % [nights, "Watch the sky" if str(ch.objective.get("spawn", "")) == "airship_drop" else "She hasn't shown yet"]
				StoryDirector.Cargo.PACKED:
					text = "In %s backpack: get it up out of the canyon" % ("your" if director.carrier == multiplayer.get_unique_id() else director.carrier_name() + "'s")
					kind = "warn"
				StoryDirector.Cargo.FALLING:
					text = "The %s is coming down!" % item
					kind = "warn"
				StoryDirector.Cargo.GROUND:
					text = "On the canyon floor: ride down for it" if ch.floor_job() else "On the plateau: follow the light"
					kind = "warn"
				StoryDirector.Cargo.CARRIED:
					text = "%s carrying it: take it to %s" % [director.carrier_name(),
							"a well" if str(ch.objective.get("deliver_to", "")) == "well" else "a noticeboard"]
					kind = "warn"
				StoryDirector.Cargo.DELIVERED:
					text = "%s delivered  ·  %s" % [item, nights]
					kind = "good"
		"blast":
			if director.blast != null:
				var st: Array = director.blast.status()
				text = str(st[0])
				kind = str(st[1])
				if director.blast.blown:
					text += "  ·  " + nights
		"salvage", "reckoning":
			if director.piece != null:
				var st: Array = director.piece.call("status")
				text = str(st[0])
				kind = str(st[1])
		"protect":
			var total := director.loot_total()
			if total > 0:
				text = "Silver: %d / %d sacks  ·  %s" % [director.loot_left(), total, nights]
				if director.in_flight > 0:
					text += "  ·  %d in the air!" % director.in_flight
					kind = "bad"
				elif director.loot_left() < total:
					kind = "warn"
		"keep":
			var need := ch.keep_need(director.held_count())
			var have := director.keep_have
			text = "%s: %d / %d  ·  %s" % [UiStyle.tc(director.keep_noun(2)), have, need, nights]
			if have < need:
				text += "  ·  Build %d more!" % (need - have)
				kind = "bad" if GameState.phase == GameState.Phase.WAVE else "warn"
			else:
				kind = "good"
	if director.holding and not director.objective_done() and not (director.blast != null and director.blast.lit()):
		text = "The waves are done. Finish the job!" + ("  ·  " + text if ch.floor_job() else "")
		kind = "warn"
	_status.text = text
	_mark.kind = kind
	_mark.color = UiStyle.status_color(kind, true)
	_mark.queue_redraw()
