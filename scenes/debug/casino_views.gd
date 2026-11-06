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
	# Chips from Pearl's cage for the chip games (bought as the host would).
	var cage := ship.get_node_or_null("ChipCage") as ChipCage
	if cage != null and game.uses_chips():
		cage._buy(multiplayer.get_unique_id(), &"chip_10", 3)
		cage._buy(multiplayer.get_unique_id(), &"chip_50", 1)
		print("[casino] chips bought: %s, team pot %d" % [_chips(), Economy.team_scrap()])
	if GameState.flag_value("--casinobets") != "" and game.has_method("debug_bets"):
		game.call("debug_bets", GameState.flag_value("--casinobets").split(","))
	MenuScreen.instance.open(game)
	var seen := [""]
	game.ui_changed.connect(func() -> void:
		var r := str(game.view.get("result", ""))
		if r != seen[0]:
			seen[0] = r
			print("[casino] %s sees: %s" % [game.name, r]))
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
	game.ui_choice = choice
	game.ui_bet_index = maxi(bets.find(bet), 0)
	game.ui_press(StringName(p[0]))
	var play2 := GameState.flag_value("--casinoplay2")
	if play2 != "":
		await get_tree().create_timer(GameState.flag_value("--casinoplay2at").to_float() if GameState.flag_value("--casinoplay2at") != "" else 2.0).timeout
		print("[casino] %s plays %s" % [game.name, play2])
		game.ui_press(StringName(play2))
	await get_tree().create_timer(1.0).timeout
	print("[casino] %s view %s" % [game.name, str(game.view)])
	await get_tree().create_timer(8.0).timeout
	print("[casino] after play: chips %s, own scrap %d" % [_chips(), Economy.amount(0, ResNames.PERSONAL_ID)])
	if cage != null and game.uses_chips():
		var pot := Economy.team_scrap()
		for id: StringName in ChipRules.ids():
			cage._cash(multiplayer.get_unique_id(), id)
		print("[casino] cashed out: chips %s, team pot %d -> %d" % [_chips(), pot, Economy.team_scrap()])


static func _chips() -> Dictionary:
	var out := {}
	for id: StringName in ChipRules.ids():
		out[id] = Economy.amount(0, id)
	return out
