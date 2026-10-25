class_name SocialTab
extends VBoxContainer
## Social tab: who's in the game, an invite to copy and send to a friend, and joining
## another game by its invite. Invites are "IP:port" over LAN or a forwarded port for now;
## a Steam/relay invite can replace this later without changing the tab's layout.

var _players: Label
var _invite: LineEdit
var _join_edit: LineEdit
var _status: Label


func _ready() -> void:
	add_theme_constant_override("separation", 8)
	add_child(UiStyle.label("In this game", 18))
	_players = UiStyle.label("", 16, Palette.WOOD_DARK)
	_players.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	add_child(_players)
	add_child(HSeparator.new())

	add_child(UiStyle.label("Invite a partner", 18))
	add_child(UiStyle.label("Send this to your friend. They paste it into Join below (or on the main menu).", 14, Palette.WOOD_DARK))
	var invite_row := HBoxContainer.new()
	_invite = LineEdit.new()
	_invite.editable = false
	_invite.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	invite_row.add_child(_invite)
	var copy := UiStyle.button("Copy invite")
	copy.pressed.connect(func() -> void:
		DisplayServer.clipboard_set(_invite.text)
		_status.text = "Invite copied to the clipboard.")
	invite_row.add_child(copy)
	add_child(invite_row)
	add_child(UiStyle.label("Playing over the internet? Forward UDP port %d on your router, or use a LAN tool such as a VPN." % NetworkManager.DEFAULT_PORT, 13, Palette.WOOD_DARK))
	add_child(HSeparator.new())

	add_child(UiStyle.label("Join a game", 18))
	var join_row := HBoxContainer.new()
	_join_edit = LineEdit.new()
	_join_edit.placeholder_text = "IP:port, e.g. 192.168.1.20:%d" % NetworkManager.DEFAULT_PORT
	_join_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	join_row.add_child(_join_edit)
	var join := UiStyle.button("Join")
	join.pressed.connect(_on_join)
	join_row.add_child(join)
	add_child(join_row)
	_status = UiStyle.label("", 14, Palette.ROCK_B)
	add_child(_status)

	NetworkManager.players_changed.connect(_refresh)
	visibility_changed.connect(_refresh)
	_refresh()


func _refresh() -> void:
	var lines: PackedStringArray = []
	for id: int in NetworkManager.players:
		var p: Dictionary = NetworkManager.players[id]
		var cliff := "West cliff" if int(p["cliff"]) == WorldLayout.WEST else "East cliff"
		var me := " (you)" if id == multiplayer.get_unique_id() else ""
		lines.append("%s: %s%s" % [cliff, str(p["name"]), me])
	if lines.is_empty():
		lines.append("Playing offline.")
	_players.text = "\n".join(lines)
	_invite.text = NetworkManager.invite_code()


func _on_join() -> void:
	var parsed := NetworkManager.parse_invite(_join_edit.text)
	if parsed.is_empty():
		_status.text = "That doesn't look like an invite (expected IP:port)."
		return
	_status.text = "Leaving this game and joining %s..." % _join_edit.text
	NetworkManager.join_from_menu(str(parsed["address"]), int(parsed["port"]))
