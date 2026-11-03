extends Node
## Debug views for the UI theme and brands (added by the Brand autoload when a
## flag below is given; never part of a normal game):
##   --brand=sheaf|irons|snake|none   take that brand on start (the UI set follows)
##   --themeview=<png>   save a screenshot after --seconds (default 2.5) and quit
##   --brandview=<png>   open the branding-iron screen, screenshot it and quit
##                       (--brandhover=0..3 lights one iron)
##   --opensecrets       open the main menu's Secrets strongbox (MainMenu reads it)
##   --cineshot=N --cinet=S   title-screen film: start on shot N, S seconds in
## Combine with the screen flags, e.g.
##   --debug --menu --brand=irons --themeview=docs/screenshots/theme_menu_irons.png
##   --debug --brand=snake --pause=1 --themeview=...   (pause menu, Graphics tab)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var shot := GameState.flag_value("--themeview")
	var brand_shot := GameState.flag_value("--brandview")
	if brand_shot != "":
		_brand_view(brand_shot)
	elif shot != "":
		_shoot(shot)


func _brand_view(path: String) -> void:
	await get_tree().create_timer(0.6).timeout
	var screen := BrandScreen.new()
	get_tree().root.add_child(screen)
	screen.open()
	if GameState.flag_value("--brandhover") != "":
		var i := int(GameState.flag_value("--brandhover"))
		var irons: Array = screen.get("_irons")
		if i >= 0 and i < irons.size():
			(irons[i] as Control).set("hovered", true)
	_shoot(path)


func _shoot(path: String) -> void:
	var secs := GameState.flag_value("--seconds").to_float()
	await get_tree().create_timer(secs if secs > 0.0 else 2.5, true, false, true).timeout
	await RenderingServer.frame_post_draw
	var full := path if path.is_absolute_path() or path.begins_with("res://") else "res://" + path
	get_viewport().get_texture().get_image().save_png(full)
	print("[theme] saved ", full)
	get_tree().quit()
