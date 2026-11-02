class_name BugSync
extends RefCounted
## The batched bug state sync's wire format (BugManager.send_states): instead of
## a MultiplayerSynchronizer per bug, the host packs every bug into a few
## unreliable packets at 10 Hz. Per bug: id, state, cliff, crouch, ride, hp,
## then either its place on the cliff face (climb height, lane, crest progress)
## or its ground/air position. 19 or 25 bytes a bug.

## Bug.State values that live on the cliff face (CLIMBING, CRESTING, DEAD).
const FACE_STATES: Array[int] = [0, 1, 3]


static func on_face(st: int) -> bool:
	return FACE_STATES.has(st)


static func pack_state(id: int, st: int, cliff: int, crouch: float, ride: float, hp: float,
		climb_y: float, lane_z: float, crest_t: float, ground_pos: Vector3) -> PackedByteArray:
	var face := on_face(st)
	var out := PackedByteArray()
	out.resize(19 if face else 25)
	out.encode_u32(0, id)
	out.encode_u8(4, st)
	out.encode_u8(5, cliff)
	out.encode_u8(6, clampi(roundi(crouch * 255.0), 0, 255))
	out.encode_half(7, ride)
	out.encode_float(9, hp)
	if face:
		out.encode_half(13, climb_y)
		out.encode_half(15, lane_z)
		out.encode_u16(17, clampi(roundi(crest_t * 65535.0), 0, 65535))
	else:
		out.encode_float(13, ground_pos.x)
		out.encode_float(17, ground_pos.y)
		out.encode_float(21, ground_pos.z)
	return out


## Every bug state in a packet, as Dictionaries; stops at a truncated entry.
static func unpack_states(buf: PackedByteArray) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var o := 0
	while o + 13 <= buf.size():
		var st := buf.decode_u8(o + 4)
		var face := on_face(st)
		if o + (19 if face else 25) > buf.size():
			break
		var d := {"id": buf.decode_u32(o), "state": st, "cliff": buf.decode_u8(o + 5),
				"crouch": float(buf.decode_u8(o + 6)) / 255.0, "ride": buf.decode_half(o + 7),
				"hp": buf.decode_float(o + 9)}
		if face:
			d["climb_y"] = buf.decode_half(o + 13)
			d["lane_z"] = buf.decode_half(o + 15)
			d["crest_t"] = float(buf.decode_u16(o + 17)) / 65535.0
			o += 19
		else:
			d["ground_pos"] = Vector3(buf.decode_float(o + 13), buf.decode_float(o + 17), buf.decode_float(o + 21))
			o += 25
		out.append(d)
	return out
