extends MultiplayerPeerExtension
## Wraps a MultiplayerPeer whose packets have a small hard size limit (Epic P2P:
## about 1170 bytes, and EOSGMultiplayerPeer refuses anything bigger instead of
## splitting it) and splits big packets into pieces, joined again on the other
## side. Everything else is passed straight to the wrapped peer.
##
## Every packet gets a 1-byte header: WHOLE, or MORE / LAST for the pieces of a
## big one. Pieces always go reliable on the packet's channel, so they arrive in
## order and complete (an oversized unreliable packet is sent reliably: rare,
## and better than never). Both sides must use this wrapper.

const WHOLE := 0
const MORE := 1
const LAST := 2
## Payload bytes per piece: under Epic's limit with room for EOSG's own header.
const PIECE := 1000

var inner: MultiplayerPeer
## Complete packets waiting for SceneMultiplayer: [data, peer, channel, mode].
var _queue: Array = []
## Pieces received so far: "peer:channel" -> PackedByteArray.
var _partial: Dictionary = {}
var _mode := TRANSFER_MODE_RELIABLE
var _channel := 0
var _target := 0


func _init(wrapped: MultiplayerPeer) -> void:
	inner = wrapped
	# Bound methods, not lambdas: those would keep this wrapper alive through inner.
	inner.peer_connected.connect(_on_connected)
	inner.peer_disconnected.connect(_on_disconnected)


func _on_connected(id: int) -> void:
	peer_connected.emit(id)


func _on_disconnected(id: int) -> void:
	for k: String in _partial.keys():
		if k.begins_with("%d:" % id):
			_partial.erase(k)
	peer_disconnected.emit(id)


func _poll() -> void:
	inner.poll()
	while inner.get_available_packet_count() > 0:
		var from := inner.get_packet_peer()
		var ch := inner.get_packet_channel()
		var mode := inner.get_packet_mode()
		var data := inner.get_packet()
		if data.is_empty():
			continue
		var kind := data[0]
		if kind == WHOLE:
			_queue.append([data.slice(1), from, ch, mode])
			continue
		var key := "%d:%d" % [from, ch]
		var got: PackedByteArray = _partial.get(key, PackedByteArray())
		got.append_array(data.slice(1))
		if kind == LAST:
			_partial.erase(key)
			_queue.append([got, from, ch, TRANSFER_MODE_RELIABLE])
		else:
			_partial[key] = got


func _put_packet_script(buf: PackedByteArray) -> Error:
	inner.transfer_channel = _channel
	inner.set_target_peer(_target)
	if buf.size() <= PIECE:
		inner.transfer_mode = _mode
		var whole := PackedByteArray([WHOLE])
		whole.append_array(buf)
		return inner.put_packet(whole)
	inner.transfer_mode = TRANSFER_MODE_RELIABLE
	var at := 0
	while at < buf.size():
		var end := mini(at + PIECE, buf.size())
		var piece := PackedByteArray([LAST if end == buf.size() else MORE])
		piece.append_array(buf.slice(at, end))
		var err := inner.put_packet(piece)
		if err != OK:
			return err
		at = end
	return OK


func _get_packet_script() -> PackedByteArray:
	if _queue.is_empty():
		return PackedByteArray()
	return (_queue.pop_front() as Array)[0]


func _get_available_packet_count() -> int:
	return _queue.size()


func _get_max_packet_size() -> int:
	return 1 << 24


func _get_packet_peer() -> int:
	return int((_queue[0] as Array)[1]) if not _queue.is_empty() else 0


func _get_packet_channel() -> int:
	return int((_queue[0] as Array)[2]) if not _queue.is_empty() else 0


func _get_packet_mode() -> TransferMode:
	return int((_queue[0] as Array)[3]) as TransferMode if not _queue.is_empty() else TRANSFER_MODE_RELIABLE


func _set_transfer_channel(ch: int) -> void:
	_channel = ch


func _get_transfer_channel() -> int:
	return _channel


func _set_transfer_mode(mode: TransferMode) -> void:
	_mode = mode


func _get_transfer_mode() -> TransferMode:
	return _mode


func _set_target_peer(peer: int) -> void:
	_target = peer


func _get_unique_id() -> int:
	return inner.get_unique_id()


func _is_server_relay_supported() -> bool:
	return inner.is_server_relay_supported()


func _get_connection_status() -> ConnectionStatus:
	return inner.get_connection_status()


func _set_refuse_new_connections(enable: bool) -> void:
	inner.refuse_new_connections = enable


func _is_refusing_new_connections() -> bool:
	return inner.refuse_new_connections


func _disconnect_peer(peer: int, now: bool) -> void:
	inner.disconnect_peer(peer, now)


func _close() -> void:
	_queue.clear()
	_partial.clear()
	inner.close()
