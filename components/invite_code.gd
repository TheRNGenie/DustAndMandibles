class_name InviteCode
extends RefCounted
## Short invite codes: the host's IPv4 address and port packed into ten
## letters and digits, shown as DUST-XXXXX-XXXXX. No server is involved; the
## code is just the address written so it's easy to read out and type.
## Crockford base 32: no I, L, O or U, and those letters read as 1, 1, 0, V when typed.

const PREFIX := "DUST"
const ALPHABET := "0123456789ABCDEFGHJKMNPQRSTVWXYZ"
const LENGTH := 10 # 50 bits: 32 for the address, 16 for the port, 2 spare


## "DUST-XXXXX-XXXXX" for an IPv4 address and port, or "" if it isn't IPv4.
static func encode(address: String, port: int) -> String:
	var parts := address.split(".")
	if parts.size() != 4 or port <= 0 or port > 65535:
		return ""
	var n := 0
	for p in parts:
		if not p.is_valid_int() or int(p) < 0 or int(p) > 255:
			return ""
		n = (n << 8) | int(p)
	n = (n << 16) | port
	var out := ""
	for i in LENGTH:
		out = ALPHABET[n & 31] + out
		n >>= 5
	return "%s-%s-%s" % [PREFIX, out.substr(0, 5), out.substr(5, 5)]


## {"address", "port"} from a code (any case, dashes and spaces optional,
## with or without DUST), or {} if it isn't one.
static func decode(text: String) -> Dictionary:
	var t := text.strip_edges().to_upper().replace("-", "").replace(" ", "")
	if t.begins_with(PREFIX):
		t = t.substr(PREFIX.length())
	if t.length() != LENGTH:
		return {}
	t = t.replace("O", "0").replace("I", "1").replace("L", "1").replace("U", "V")
	var n := 0
	for ch in t:
		var v := ALPHABET.find(ch)
		if v < 0:
			return {}
		n = (n << 5) | v
	var port := n & 0xFFFF
	var ip := (n >> 16) & 0xFFFFFFFF
	if n >> 48 != 0 or port == 0 or ip == 0:
		return {}
	return {"address": "%d.%d.%d.%d" % [(ip >> 24) & 255, (ip >> 16) & 255, (ip >> 8) & 255, ip & 255], "port": port}


## Does this look like a code (rather than an IP:port)?
static func looks_like_code(text: String) -> bool:
	return not decode(text).is_empty()


# ------------------------------------------------------------------ lobby codes
## Short lobby codes for the online backends (EpicBackend, a future SteamBackend):
## six random Crockford letters stored on the lobby, shown as DUST-XXXXXX. They
## are a lookup key, not an address, so they're shorter than the direct codes
## above (DUST-XXXXX-XXXXX) and the two can never be mistaken for each other.
const LOBBY_LENGTH := 6


## A fresh random lobby code, e.g. "DUST-7K2MQX".
static func make_lobby_code() -> String:
	var out := ""
	for i in LOBBY_LENGTH:
		out += ALPHABET[randi() % ALPHABET.length()]
	return "%s-%s" % [PREFIX, out]


## The canonical "DUST-XXXXXX" for anything a player typed (any case, dashes
## and spaces optional, with or without DUST, I/L/O/U typos fixed), or "".
static func normalize_lobby_code(text: String) -> String:
	var t := text.strip_edges().to_upper().replace("-", "").replace(" ", "")
	if t.begins_with(PREFIX):
		t = t.substr(PREFIX.length())
	if t.length() != LOBBY_LENGTH:
		return ""
	t = t.replace("O", "0").replace("I", "1").replace("L", "1").replace("U", "V")
	for ch in t:
		if ALPHABET.find(ch) < 0:
			return ""
	return "%s-%s" % [PREFIX, t]


## Is this a lobby code (DUST-XXXXXX) rather than a direct code or an IP?
static func is_lobby_code(text: String) -> bool:
	return normalize_lobby_code(text) != ""
