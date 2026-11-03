extends TestCase
## Online backends: the Epic credentials file and the Direct backend's codes.
## (No network here: the Epic login itself is tested by hand, see docs/online_epic.md.)

const EPIC := "res://components/net/epic_backend.gd"


func test_epic_credentials_labelled_lines() -> void:
	var script := load(EPIC) as GDScript
	var text := "# from the Epic dev portal\nProduct ID: p123\nSandbox ID = s456\nDeployment-ID: d789\nClient ID: c1\nClient Secret: \"sec/ret+x=\"\n"
	var got: Dictionary = script.call("parse_credentials", text)
	assert_eq(str(got.get("product_id", "")), "p123")
	assert_eq(str(got.get("sandbox_id", "")), "s456")
	assert_eq(str(got.get("deployment_id", "")), "d789")
	assert_eq(str(got.get("client_id", "")), "c1")
	assert_eq(str(got.get("client_secret", "")), "sec/ret+x=", "only the first ':' or '=' splits")


func test_epic_credentials_bare_lines_and_missing() -> void:
	var script := load(EPIC) as GDScript
	var got: Dictionary = script.call("parse_credentials", "p\ns\nd\nc\nx\n")
	assert_eq(str(got.get("client_secret", "")), "x", "five bare lines in portal order")
	var partial: Dictionary = script.call("parse_credentials", "Product ID: p\nClient ID: c\n")
	assert_true(partial.is_empty(), "missing fields mean no credentials")
	var none: Dictionary = script.call("load_credentials", "res://no_such_file.txt")
	assert_true(none.is_empty())


func test_direct_backend_codes() -> void:
	var d := DirectBackend.new()
	assert_true(d.owns_code(InviteCode.encode("73.42.190.5", 24565)))
	assert_true(d.owns_code("192.168.1.20:24565"))
	assert_false(d.owns_code("DUST-7K2MQX"), "a lobby code belongs to the online backend")
	assert_eq(int(DirectBackend.parse("10.0.0.5").get("port", 0)), DirectBackend.DEFAULT_PORT)
	assert_true(d.is_available() and d.is_ready())
	d.free()


func test_epic_credentials_portal_paste() -> void:
	# The layout of a copy-paste from the Epic Developer Portal (made-up ids).
	var text := "Product\nProduct\tProduct ID\nDust And Mandibles\t\nPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPP1\n\n\nCustom\tClient ID\t\nDust And Mandibles Client\t\nCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC2\n\n\nClient Secret  SeCrEt/with+symbols-and_more0123456789abcde\n\n\nSandbox type\tSandbox ID\nLive\t\nSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSS3\n\n\n\nDeployment name\tSandbox\tDeployment ID\nLive Deployment\tLive\t\nDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDD4\n"
	var got: Dictionary = (load(EPIC) as GDScript).call("parse_credentials", text)
	assert_eq(str(got.get("product_id", "")), "PPPPPPPPPPPPPPPPPPPPPPPPPPPPPPP1")
	assert_eq(str(got.get("client_id", "")), "CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC2")
	assert_eq(str(got.get("client_secret", "")), "SeCrEt/with+symbols-and_more0123456789abcde")
	assert_eq(str(got.get("sandbox_id", "")), "SSSSSSSSSSSSSSSSSSSSSSSSSSSSSSS3")
	assert_eq(str(got.get("deployment_id", "")), "DDDDDDDDDDDDDDDDDDDDDDDDDDDDDDD4")
