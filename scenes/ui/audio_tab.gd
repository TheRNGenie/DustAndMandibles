class_name AudioTab
extends VBoxContainer
## Audio tab: the overall volume, then bugs, music, weapons (guns, turrets, the
## dynamite, the whip), speech (the voiced radio) and every other sound effect.


func _ready() -> void:
	add_theme_constant_override("separation", 8)
	_slider("Volume", "master_volume", Settings.master_volume)
	_slider("Bug Volume", "bug_volume", Settings.bug_volume)
	_slider("Music Volume", "music_volume", Settings.music_volume)
	_slider("Weapon Volume", "weapon_volume", Settings.weapon_volume)
	_slider("Speech Volume", "speech_volume", Settings.speech_volume)
	_slider("Other Effects", "sfx_volume", Settings.sfx_volume)


func _slider(label: String, key: String, value: float) -> void:
	add_child(UiStyle.row(label, UiStyle.slider(0.0, 1.0, 0.05, value, "pct",
			func(v: float) -> void: Settings.set_value(key, v))))
