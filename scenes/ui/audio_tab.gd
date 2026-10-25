class_name AudioTab
extends VBoxContainer
## Audio tab: master, sound effects and music volume.


func _ready() -> void:
	add_theme_constant_override("separation", 8)
	add_child(UiStyle.row("Master volume", UiStyle.slider(0.0, 1.0, 0.05, Settings.master_volume, "%.2f",
			func(v: float) -> void: Settings.set_value("master_volume", v))))
	add_child(UiStyle.row("Sound effects", UiStyle.slider(0.0, 1.0, 0.05, Settings.sfx_volume, "%.2f",
			func(v: float) -> void: Settings.set_value("sfx_volume", v))))
	add_child(UiStyle.row("Music", UiStyle.slider(0.0, 1.0, 0.05, Settings.music_volume, "%.2f",
			func(v: float) -> void: Settings.set_value("music_volume", v))))
