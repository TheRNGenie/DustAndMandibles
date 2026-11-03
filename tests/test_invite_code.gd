extends TestCase
## Invite codes: the host's address and port as DUST-XXXXX-XXXXX.


func test_round_trip() -> void:
	for pair: Array in [["73.42.190.5", 24565], ["192.168.1.20", 24565], ["255.255.255.255", 65535], ["1.2.3.4", 1]]:
		var code := InviteCode.encode(pair[0], pair[1])
		assert_eq(code.length(), 16, code)
		assert_true(code.begins_with("DUST-"), code)
		var back := InviteCode.decode(code)
		assert_eq(str(back.get("address", "")), str(pair[0]))
		assert_eq(int(back.get("port", 0)), int(pair[1]))


func test_forgiving_typing() -> void:
	var code := InviteCode.encode("73.42.190.5", 24565)
	var loose := code.to_lower().replace("-", " ").replace("dust", "")
	assert_eq(str(InviteCode.decode(loose).get("address", "")), "73.42.190.5", "lower case, spaces, no prefix")
	# O for 0 and I/L for 1 still read right.
	var typo := code.replace("0", "O").replace("1", "I")
	assert_eq(str(InviteCode.decode(typo).get("address", "")), "73.42.190.5")


func test_rejects_junk() -> void:
	assert_true(InviteCode.decode("").is_empty())
	assert_true(InviteCode.decode("DUST-12345").is_empty())
	assert_true(InviteCode.decode("hello world").is_empty())
	assert_true(InviteCode.decode("192.168.1.20:24565").is_empty(), "an IP:port isn't a code")
	assert_eq(InviteCode.encode("::1", 24565), "", "IPv6 has no code")
	assert_eq(InviteCode.encode("1.2.3", 24565), "")
