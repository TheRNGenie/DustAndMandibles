extends CanvasLayer
## Debug (main menu): --storyportraits=<png> lays the four radio portraits out
## big, side by side, saves a screenshot after --seconds (default 3) and quits.

func _ready() -> void:
	layer = 90
	var bg := ColorRect.new()
	bg.color = Color("#2A1A0F")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	row.position = Vector2(40, 200)
	add_child(row)
	for who in StoryChapter.SPEAKERS:
		var col := VBoxContainer.new()
		row.add_child(col)
		var card := RadioCard.new()
		var ring := card._portrait_frame()
		ring.custom_minimum_size = Vector2(340, 340)
		card._pic.texture = StoryPortrait.texture(self, who)
		col.add_child(ring)
		var l := UiStyle.label(StoryChapter.speaker_name(who), 22, UiStyle.c("title"))
		col.add_child(l)
		card.queue_free()
	var secs := GameState.flag_value("--seconds").to_float()
	get_tree().create_timer(secs if secs > 0.0 else 3.0).timeout.connect(func() -> void:
		get_viewport().get_texture().get_image().save_png(GameState.flag_value("--storyportraits"))
		get_tree().quit())
