extends CanvasLayer
## Debug (main menu): --storyportraits=<png> lays the four radio portraits out
## big, side by side (the painted card and the radio ring), saves a screenshot after --seconds (default 3) and quits.

func _ready() -> void:
	layer = 90
	var bg := ColorRect.new()
	bg.color = Color("#2A1A0F")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	# Four to a row (the crew, then the Board and its hangers-on).
	var row := GridContainer.new()
	row.columns = 4
	row.add_theme_constant_override("h_separation", 24)
	row.add_theme_constant_override("v_separation", 12)
	add_child(row)
	row.position = Vector2(40, 20)
	for who in StoryChapter.SPEAKERS:
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 10)
		row.add_child(col)
		# The painted card itself, then as the radio card shows it.
		var pic := TextureRect.new()
		pic.texture = StoryPortrait.texture(self, who)
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.custom_minimum_size = Vector2(300, 300)
		col.add_child(pic)
		var l := UiStyle.label(StoryChapter.speaker_name(who), 22, UiStyle.c("title"))
		col.add_child(l)
		var card := RadioCard.new()
		var ring := card._portrait_frame()
		ring.custom_minimum_size = Vector2(150, 150)
		ring.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		card._pic.texture = StoryPortrait.face_texture(self, who)
		ring.custom_minimum_size = Vector2(RadioCard.PORTRAIT, RadioCard.PORTRAIT)
		col.add_child(ring)
		card.queue_free()
	var secs := GameState.flag_value("--seconds").to_float()
	get_tree().create_timer(secs if secs > 0.0 else 3.0).timeout.connect(func() -> void:
		get_viewport().get_texture().get_image().save_png(GameState.flag_value("--storyportraits"))
		get_tree().quit())
