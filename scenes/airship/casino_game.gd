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


## Staked in Pearl's chips and paid out in your own scrap (Logan). The prize
## wheel keeps its own prices and prizes.
func uses_chips() -> bool:
	return true


## Bet types to pick from (Player / Banker / Tie, Red / Black...), or empty.
func ui_choices() -> Array:
	return []


## Buttons for the current state: [[action id, label], ...].
func ui_actions() -> Array:
	return []


## Brand (Snake Eyes): this game's cheat, [button label, game key for the
## odds in BrandTable.CHEAT_RISK], or empty when it has none. Pressing it sends
## the action &"cheat" with the same pick and stake as the normal play.
func ui_cheat() -> Array:
	return []


## The move your dummy makes when you play: deal cards by default.
func ui_anim() -> StringName:
	return &"cards"


func ui_act(action: StringName, choice: int, bet: int) -> void:
	var world := get_tree().current_scene
	if world != null and world.has_method("local_player"):
		var me: Player = world.call("local_player")
		if me != null:
			me.act(ui_anim(), &"")
	if multiplayer.is_server():
		_act(multiplayer.get_unique_id(), action, choice, bet)
	else:
		_request.rpc_id(1, action, choice, bet)


# ------------------------------------------------------------------ the menu screen

## This peer's picks on the game screen.
var ui_choice := 0
var ui_bet_index := 0
## When (local seconds) the current view arrived: the screens animate from it.
var view_at := -1000.0
## Sounds and effects already fired for the current view (the screen can be
## rebuilt mid-animation; a reel's thunk must not play twice).
var fx_done: Dictionary = {}


func menu_title() -> String:
	return ui_title()


func menu_tagline() -> String:
	return ui_tagline()


## One short line under the title (the full rules are printed on the table).
func ui_tagline() -> String:
	return ui_rules()


## The casino screens are bigger than a shop list.
func menu_size() -> Vector2:
	return Vector2(1180, 800)


## The game's live table for its screen (null: the plain felt with _draw_view).
func make_board() -> CasinoBoard:
	return null


## True when the board itself takes the bet pick (click a box, a lane, a shell).
func board_picks() -> bool:
	return false


## How long the current view's animation runs (cards dealt, reels, a wheel).
func anim_length() -> float:
	return 0.0


## Mid-animation: the result is held back and the buttons wait.
func ui_busy() -> bool:
	return view_age() < anim_length()


func view_age() -> float:
	return Time.get_ticks_msec() / 1000.0 - view_at


## The line under the table while the animation runs.
func busy_text() -> String:
	return "No more bets..."


## The line under the table once it has settled.
func result_text() -> String:
	return result_line("Place your bet.")


## The view's result, said to whoever is watching: someone else's win reads as theirs.
func result_line(none: String = "") -> String:
	var r := str(view.get("result", none))
	if view.has("peer") and int(view["peer"]) != multiplayer.get_unique_id() and r != none:
		return "Another player: " + r
	return r


func stake() -> int:
	var bets := ui_bets()
	return int(bets[clampi(ui_bet_index, 0, bets.size() - 1)]) if not bets.is_empty() else 0


func menu_build_body(body: Control, _screen: MenuScreen) -> void:
	var board := make_board()
	if board != null:
		body.add_child(board)
	else:
		var felt := PanelContainer.new()
		# Theme: the table is always baize with a gold rail (the Snake Eyes felt, whatever the set).
		var sb := StyleBoxTexture.new()
		UiStyle._fill_box(sb, "icon", &"snake")
		sb.set_content_margin_all(16)
		felt.add_theme_stylebox_override("panel", sb)
		felt.custom_minimum_size.y = 210
		body.add_child(felt)
		var table := VBoxContainer.new()
		table.alignment = BoxContainer.ALIGNMENT_CENTER
		table.add_theme_constant_override("separation", 10)
		felt.add_child(table)
		_draw_view(table)
	var choices := ui_choices()
	if not choices.is_empty() and not board_picks():
		var pick := VBoxContainer.new()
		pick.add_child(_caption("Your Bet"))
		pick.add_child(MenuScreen.toggle_row(choices, ui_choice, func(i: int) -> void:
			ui_choice = i
			ui_changed.emit()))
		body.add_child(pick)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 14)
	body.add_child(bar)
	var bets := ui_bets()
	if not bets.is_empty():
		var col := VBoxContainer.new()
		col.add_child(_caption("Stake (Chips)" if uses_chips() else "Stake (%s)" % UiStyle.tc(String(ui_currency()))))
		var chips := HBoxContainer.new()
		chips.add_theme_constant_override("separation", 6)
		for i in bets.size():
			var b := ChipButton.new()
			b.value = int(bets[i])
			b.selected = i == ui_bet_index
			b.tooltip_text = ("Bet %d in chips" % int(bets[i])) if uses_chips() else "Bet %d %s" % [int(bets[i]), String(ui_currency())]
			var index := i
			b.pressed.connect(func() -> void:
				ui_bet_index = index
				Audio.play_ui(&"dice", -10.0, 1.6)
				ui_changed.emit())
			chips.add_child(b)
		col.add_child(chips)
		bar.add_child(col)
	# The dealer's call (the result once the animation has played out).
	var busy := ui_busy() or (board == null and bool(view.get("spinning", false)))
	var result := MenuScreen.ink_label(busy_text() if busy else result_text(), 19, MenuScreen.INK)
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	result.custom_minimum_size.x = 200
	result.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bar.add_child(result)
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_END
	actions.add_theme_constant_override("separation", 10)
	actions.size_flags_vertical = Control.SIZE_SHRINK_END
	bar.add_child(actions)
	if Brand.local_banned(): # Brand: a caught cheat sits out
		var barred := MenuScreen.ink_label("The pit boss has barred you from the tables until wave %d." % Brand.ban_wave(multiplayer.get_unique_id()), 17, UiStyle.c("bad"))
		body.add_child(barred)
		return
	for a: Array in ui_actions():
		var btn := MenuScreen.wood_button(str(a[1]))
		btn.custom_minimum_size.x = 130
		btn.disabled = ui_busy()
		var id: StringName = a[0]
		btn.pressed.connect(func() -> void: ui_press(id))
		actions.add_child(btn)
	_cheat_row(body, bets)


## A button under the table: plays it with this peer's pick and stake.
func ui_press(id: StringName) -> void:
	ui_act(id, ui_choice, stake())


static func _caption(t: String) -> Label:
	var l := MenuScreen.ink_label(t, 14, UiStyle.c("ink_soft"))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	return l


## Brand: the Snake Eyes cheat button, with the odds of getting caught right now.
func _cheat_row(body: Control, _bets: Array) -> void:
	var cheat := ui_cheat()
	if cheat.is_empty() or not BrandTable.can_cheat(Brand.local_id()) or ui_actions().is_empty():
		return
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	body.add_child(row)
	row.add_child(BrandMark.make(BrandTable.SNAKE, 26, UiStyle.c("bad")))
	var risk := Brand.local_risk(str(cheat[1]))
	var b := MenuScreen.wood_button("%s  (%d%% Risk)" % [str(cheat[0]), roundi(risk * 100.0)])
	b.custom_minimum_size.x = 300
	b.tooltip_text = "Snake Eyes: rig this one. If the pit boss catches you, you lose the stake and you're barred from the tables for a wave. He catches 70% of cheats, 5% more for each one that gets past him, and starts over once he's caught you."
	b.disabled = ui_busy()
	b.pressed.connect(func() -> void: ui_press(&"cheat"))
	row.add_child(b)


## Host: a cheat attempt. 1 = it worked (now take the stake and rig the game),
## 0 = not allowed, -1 = caught (the stake is forfeited and the rider barred).
func _cheat(peer_id: int, game: String, bet: int) -> int:
	var r := Brand.cheat(peer_id, game)
	if r < 0:
		if bet > 0:
			_spend_stake(peer_id, bet)
		_note.rpc("CAUGHT CHEATING! The pit boss takes the stake and shows you the door.")
	return r


@rpc("authority", "call_local", "reliable")
func _note(text: String) -> void:
	view["result"] = text
	view["spinning"] = false
	view_at = -1000.0
	ui_changed.emit()


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


## Like ui_act, with a dictionary (a roulette layout's chips: {spot: amount}).
func ui_act_data(action: StringName, data: Dictionary) -> void:
	var world := get_tree().current_scene
	if world != null and world.has_method("local_player"):
		var me: Player = world.call("local_player")
		if me != null:
			me.act(ui_anim(), &"")
	if multiplayer.is_server():
		_act_data(multiplayer.get_unique_id(), action, data)
	else:
		_request_data.rpc_id(1, action, data)


@rpc("any_peer", "reliable")
func _request_data(action: StringName, data: Dictionary) -> void:
	if multiplayer.is_server():
		_act_data(multiplayer.get_remote_sender_id(), action, data)


## Host: an action with a dictionary of bets.
func _act_data(_peer_id: int, _action: StringName, _data: Dictionary) -> void:
	pass


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
	var before := view
	view = v
	view_at = Time.get_ticks_msec() / 1000.0
	fx_done.clear()
	_on_view_change(before)
	_on_view()
	ui_changed.emit()


## Hook before _on_view with the view it replaced (card tables keep their dealt cards' timings).
func _on_view_change(_before: Dictionary) -> void:
	pass


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
	if Brand.is_banned(peer_id): # Brand: caught cheats are barred for a wave
		Economy.notify(peer_id, "The pit boss won't take your bets until wave %d." % Brand.ban_wave(peer_id))
		return false
	if _spend_stake(peer_id, amount):
		return true
	if uses_chips():
		Economy.notify(peer_id, "You need %d in chips for that bet. Pearl sells them at her cage." % amount)
	else:
		Economy.notify(peer_id, "You need %d %s for that bet." % [amount, String(ui_currency())])
	return false


## Host: takes `amount` from this rider's chips (or currency); false if short.
func _spend_stake(peer_id: int, amount: int) -> bool:
	var cid := _cliff(peer_id)
	if not uses_chips():
		return Economy.spend(cid, {ui_currency(): amount})
	var held := {}
	for id: StringName in ChipRules.ids():
		held[id] = Economy.amount(cid, id)
	var plan := ChipRules.pay(held, amount)
	if plan.is_empty() or not Economy.spend(cid, plan["spend"]):
		return false
	if not (plan["add"] as Dictionary).is_empty():
		Economy.earn(cid, plan["add"])
	return true


## Host: a win sometimes comes with a turret part (CasinoRules.PART_CHANCE).
## Pays it and returns a line naming it for the result, or "".
func _part_bonus(peer_id: int) -> String:
	var key := CasinoRules.part_bonus(_rng)
	if key == &"":
		return ""
	_pay(peer_id, {key: 1})
	return " The house throws in a %s for the Workshop!" % CraftTable.part_name(key)


func _pay(peer_id: int, amounts: Dictionary) -> void:
	if amounts.is_empty():
		return
	var out := amounts.duplicate()
	if uses_chips() and out.has(ui_currency()):
		# Chip games pay winnings in your own scrap.
		out[ResNames.PERSONAL_ID] = int(out.get(ResNames.PERSONAL_ID, 0)) + int(out[ui_currency()])
		out.erase(ui_currency())
	Economy.earn(_cliff(peer_id), out)


## A stake button drawn as a casino chip with its value; the picked one sits in a gold ring.
class ChipButton extends Button:
	var value := 10
	var selected := false

	func _init() -> void:
		custom_minimum_size = Vector2(54, 54)
		focus_mode = Control.FOCUS_ALL
		flat = true
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	func _draw() -> void:
		var c := size * 0.5 + Vector2(0, 0 if selected else 2)
		var r := minf(size.x, size.y) * 0.42
		if selected:
			draw_circle(c, r + 5, Color("#E9C46A"))
		elif is_hovered() or has_focus():
			draw_circle(c, r + 4, Color(1, 1, 1, 0.5))
		var col := CasinoBoard.chip_color(value)
		draw_circle(c + Vector2(1.5, 2.5), r, Color(0, 0, 0, 0.35))
		draw_circle(c, r, col)
		for i in 6:
			var a := TAU * i / 6.0 + 0.3
			var p := c + Vector2(cos(a), sin(a)) * r * 0.8
			draw_set_transform(p, a, Vector2.ONE)
			draw_rect(Rect2(-r * 0.12, -r * 0.2, r * 0.24, r * 0.4), Color(1, 1, 1, 0.9))
			draw_set_transform_matrix(Transform2D.IDENTITY)
		draw_circle(c, r * 0.6, Color(1, 1, 1, 0.95) if value < 100 else Color("#E9C46A"))
		draw_arc(c, r * 0.6, 0, TAU, 20, col, 2.0, true)
		draw_arc(c, r, 0, TAU, 28, Color(0, 0, 0, 0.5), 1.0, true)
		var f := CasinoBoard.sign_font()
		var px := 15 if value < 100 else 13
		var w := f.get_string_size(str(value), HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
		draw_string(f, c + Vector2(-w * 0.5, (f.get_ascent(px) - f.get_descent(px)) * 0.5), str(value), HORIZONTAL_ALIGNMENT_LEFT, -1, px, Color("#1E1A18"))
