extends Node
## Global game state: phase, wave number, Homestead health, win/lose.
## M0 only holds the phase enum and command-line flags. The host-only wave
## logic arrives in M1/M2.

signal phase_changed(new_phase: Phase)

enum Phase { LOBBY, BUILD, WARNING, WAVE, GAME_OVER }

var phase: Phase = Phase.LOBBY
var wave: int = 0
## Command-line flags (anything after `--` on the command line).
var flags: PackedStringArray = PackedStringArray()


func _ready() -> void:
	flags = OS.get_cmdline_user_args()
	# Also accept flags passed without the `--` separator.
	for arg: String in OS.get_cmdline_args():
		if arg.begins_with("--") and not flags.has(arg):
			flags.append(arg)


func has_flag(flag: String) -> bool:
	return flags.has(flag)


## Value of a `--name=value` flag, or "" if absent.
func flag_value(flag: String) -> String:
	for f: String in flags:
		if f.begins_with(flag + "="):
			return f.substr(flag.length() + 1)
	return ""


func set_phase(new_phase: Phase) -> void:
	if new_phase == phase:
		return
	phase = new_phase
	phase_changed.emit(new_phase)
