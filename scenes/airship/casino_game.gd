class_name CasinoGame
extends StaticBody3D
## Base for every game on the casino deck. E opens the game's own screen
## (CasinoPanel); the screen calls ui_act(), which goes to the host. The host
## settles the bet and broadcasts the table's view (cards, reels, number...) to
## everyone, and each peer's screen redraws from `view`.

signal ui_changed

## What the screen shows; replaced by the host's broadcasts.
var view: Dictionary = {}
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	collision_layer = WorldLayout.LAYER_STRUCTURE
	collision_mask = 0


# ------------------------------------------------------------------ for the screen

func ui_title() -> String:
	return "Casino"


## How the game's rules read, one or two lines.
func ui_rules() -> String:
	return ""


## Bet amounts to pick from (empty = fixed price) and their currency.
func ui_bets() -> Array:
	return []


func ui_currency() -> StringName:
	return &"scrap"


## Bet types to pick from (Player / Banker / Tie, Red / Black...), or empty.
func ui_choices() -> Array:
	return []


## Buttons for the current state: [[action id, label], ...].
func ui_actions() -> Array:
	return []


func ui_act(action: StringName, choice: int, bet: int) -> void:
	if multiplayer.is_server():
		_act(multiplayer.get_unique_id(), action, choice, bet)
	else:
		_request.rpc_id(1, action, choice, bet)


# ------------------------------------------------------------------ the menu screen

## This peer's picks on the game screen.
var ui_choice := 0
var ui_bet_index := 0


func menu_title() -> String:
	return ui_title()


func menu_tagline() -> String:
	return ui_rules()


func menu_build_body(body: Control, _screen: MenuScreen) -> void:
	var felt := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#2E6B3A")
	sb.border_color = Palette.WOOD_DARK
	sb.set_border_width_all(6)
	sb.set_corner_radius_all(12)
	sb.set_content_margin_all(14)
	felt.add_theme_stylebox_override("panel", sb)
	felt.custom_minimum_size.y = 240
	body.add_child(felt)
	var table := VBoxContainer.new()
	table.alignment = BoxContainer.ALIGNMENT_CENTER
	table.add_theme_constant_override("separation", 10)
	felt.add_child(table)
	_draw_view(table)
	var result_text := "Spinning..." if bool(view.get("spinning", false)) else str(view.get("result", "Place your bet."))
	var result := MenuScreen.ink_label(result_text, 20, MenuScreen.GOLD)
	result.add_theme_color_override("font_outline_color", Palette.OUTLINE)
	result.add_theme_constant_override("outline_size", 6)
	table.add_child(result)
	var choices := ui_choices()
	if not choices.is_empty():
		body.add_child(MenuScreen.ink_label("Your bet", 15))
		body.add_child(MenuScreen.toggle_row(choices, ui_choice, func(i: int) -> void:
			ui_choice = i
			ui_changed.emit()))
	var bets := ui_bets()
	if not bets.is_empty():
		var labels: Array = []
		for b: int in bets:
			labels.append("%d %s" % [b, String(ui_currency())])
		body.add_child(MenuScreen.ink_label("Stake", 15))
		body.add_child(MenuScreen.toggle_row(labels, ui_bet_index, func(i: int) -> void:
			ui_bet_index = i
			ui_changed.emit()))
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 12)
	body.add_child(actions)
	for a: Array in ui_actions():
		var btn := MenuScreen.wood_button(str(a[1]))
		btn.custom_minimum_size.x = 140
		var id: StringName = a[0]
		btn.pressed.connect(func() -> void:
			var stake := int(bets[clampi(ui_bet_index, 0, bets.size() - 1)]) if not bets.is_empty() else 0
			ui_act(id, ui_choice, stake))
		actions.add_child(btn)


## Draws the game's current state on the felt.
func _draw_view(table: VBoxContainer) -> void:
	match str(view.get("kind", "")):
		"cards":
			for row: Array in view.get("rows", []):
				var line := HBoxContainer.new()
				line.alignment = BoxContainer.ALIGNMENT_CENTER
				line.add_theme_constant_override("separation", 6)
				var who := MenuScreen.ink_label("%s  %d" % [row[0], int(row[2])], 18, MenuScreen.PARCHMENT)
				who.custom_minimum_size.x = 120
				line.add_child(who)
				var cards: Array = row[1]
				for i in cards.size():
					line.add_child(MenuScreen.card(int(cards[i]), i * 3 + int(cards[i])))
				table.add_child(line)
		"reels":
			var line := HBoxContainer.new()
			line.alignment = BoxContainer.ALIGNMENT_CENTER
			line.add_theme_constant_override("separation", 10)
			for sym: Variant in view.get("reels", ["?", "?", "?"]):
				var reel := PanelContainer.new()
				var rs := StyleBoxFlat.new()
				rs.bg_color = Color("#FFFDF5")
				rs.border_color = Palette.OUTLINE
				rs.set_border_width_all(3)
				rs.set_corner_radius_all(8)
				reel.add_theme_stylebox_override("panel", rs)
				reel.custom_minimum_size = Vector2(150, 110)
				var l := MenuScreen.ink_label(str(sym), 24, Color("#B3261E") if str(sym) == "STAR" else MenuScreen.INK)
				l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
				reel.add_child(l)
				line.add_child(reel)
			table.add_child(line)
		"number":
			var spinning := bool(view.get("spinning", false))
			var colour := str(view.get("colour", "green"))
			var ball := PanelContainer.new()
			var bs := StyleBoxFlat.new()
			bs.bg_color = Palette.WOOD_DARK if spinning else (Color("#2E7D32") if colour == "green" else (Color("#B3261E") if colour == "red" else Color("#1E1A18")))
			bs.set_corner_radius_all(60)
			bs.border_color = MenuScreen.GOLD
			bs.set_border_width_all(4)
			ball.add_theme_stylebox_override("panel", bs)
			ball.custom_minimum_size = Vector2(120, 120)
			ball.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			var l := MenuScreen.ink_label("..." if spinning else str(view.get("number", "")), 44, MenuScreen.PARCHMENT)
			l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			ball.add_child(l)
			table.add_child(ball)
		_:
			table.add_child(MenuScreen.ink_label(ui_title(), 34, MenuScreen.PARCHMENT))


# ------------------------------------------------------------------ interaction

func interact_prompt() -> String:
	return "E: play %s" % ui_title().to_lower()


func local_interact(holding: bool) -> void:
	if holding or MenuScreen.instance == null:
		return
	MenuScreen.instance.open(self)


@rpc("any_peer", "reliable")
func _request(action: StringName, choice: int, bet: int) -> void:
	if multiplayer.is_server():
		_act(multiplayer.get_remote_sender_id(), action, choice, bet)


## Host: a player pressed a button on this game's screen.
func _act(_peer_id: int, _action: StringName, _choice: int, _bet: int) -> void:
	pass


## Host: send the new view to everyone.
func _broadcast(v: Dictionary) -> void:
	_set_view.rpc(v)


@rpc("authority", "call_local", "reliable")
func _set_view(v: Dictionary) -> void:
	view = v
	_on_view()
	ui_changed.emit()


## Hook for 3D effects when the view changes (spin the wheel, pull the arm...).
func _on_view() -> void:
	pass


# ------------------------------------------------------------------ money helpers

func _cliff(peer_id: int) -> int:
	return NetworkManager.cliff_of(peer_id)


## Clamps the bet to one of the allowed amounts.
func _valid_bet(bet: int) -> int:
	var bets := ui_bets()
	if bets.is_empty():
		return 0
	return bet if bets.has(bet) else int(bets[0])


func _take(peer_id: int, amount: int) -> bool:
	if Economy.spend(_cliff(peer_id), {ui_currency(): amount}):
		return true
	Economy.notify(peer_id, "You need %d %s for that bet." % [amount, String(ui_currency())])
	return false


func _pay(peer_id: int, amounts: Dictionary) -> void:
	if not amounts.is_empty():
		Economy.earn(_cliff(peer_id), amounts)
