extends Node
## Debug (with --shot): --casinoview=<game node> opens that casino game's screen
## (Slots0, Blackjack, Baccarat, Roulette, ShellGame, BeetleRace, Wheel).
## --casinoplay=<action>[:choice[:bet]] plays it (as the host) --casinoplayat=S
## seconds after the screen opens; --casinoplay2=<action> a second action 1 s later
## (e.g. blackjack hit / stand). --casinobets=<spot>,<spot> lays roulette chips first.


func _ready() -> void:
	for i in 30:
		await get_tree().process_frame
	var world := get_tree().current_scene
	var ship := world.get_node_or_null("Airship")
	if ship == null:
		push_warning("[casino] no airship")
		return
	var game := ship.get_node_or_null(GameState.flag_value("--casinoview")) as CasinoGame
	if game == null:
		push_warning("[casino] no game " + GameState.flag_value("--casinoview"))
		return
	Economy.earn(0, {&"scrap": 2000, &"chitin": 60})
	if GameState.flag_value("--casinobets") != "" and game.has_method("debug_bets"):
		game.call("debug_bets", GameState.flag_value("--casinobets").split(","))
	MenuScreen.instance.open(game)
	var play := GameState.flag_value("--casinoplay")
	if play == "":
		return
	var at := GameState.flag_value("--casinoplayat").to_float()
	await get_tree().create_timer(maxf(at, 0.05)).timeout
	var p := play.split(":")
	var choice := int(p[1]) if p.size() > 1 else game.ui_choice
	var bets := game.ui_bets()
	var bet := int(p[2]) if p.size() > 2 else (int(bets[0]) if not bets.is_empty() else 0)
	print("[casino] %s plays %s choice %d bet %d" % [game.name, p[0], choice, bet])
	game.ui_act(StringName(p[0]), choice, bet)
	var play2 := GameState.flag_value("--casinoplay2")
	if play2 != "":
		await get_tree().create_timer(1.0).timeout
		game.ui_act(StringName(play2), choice, bet)
	await get_tree().create_timer(1.0).timeout
	print("[casino] %s view %s" % [game.name, str(game.view)])
