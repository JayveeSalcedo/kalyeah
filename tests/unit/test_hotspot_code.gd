extends GutTest

const NET: NetRules = preload("res://data/rules/net_rules.tres")


func test_a_code_is_eight_room_code_characters() -> void:
	var code: String = HotspotCode.encode("192.168.43.1", NET)
	assert_eq(code.length(), NET.passcode_length)
	for letter: String in code:
		assert_true(NET.passcode_alphabet.contains(letter), "%s is in the room code alphabet" % letter)


func test_the_code_leads_back_to_the_hosts_address() -> void:
	for ip: String in ["192.168.43.1", "172.20.10.1", "192.168.1.25", "10.0.0.7", "172.31.255.254"]:
		assert_eq(HotspotCode.decode(HotspotCode.encode(ip, NET), NET), ip)
	assert_eq(HotspotCode.url_for(HotspotCode.encode("192.168.43.1", NET), NET), "ws://192.168.43.1:%d" % NET.default_port)
	assert_eq(HotspotCode.decode(HotspotCode.encode("192.168.43.1", NET).to_lower(), NET), "192.168.43.1", "case does not matter")


func test_wrong_codes_are_refused() -> void:
	var code: String = HotspotCode.encode("192.168.43.1", NET)
	assert_eq(HotspotCode.decode("", NET), "")
	assert_eq(HotspotCode.decode(code.left(7), NET), "", "too short")
	assert_eq(HotspotCode.decode(code + "A", NET), "", "too long")
	assert_eq(HotspotCode.decode("ILO01111", NET), "", "letters outside the alphabet")
	var bad: String = code.left(7) + NET.passcode_alphabet[(NET.passcode_alphabet.find(code[7]) + 1) % NET.passcode_alphabet.length()]
	assert_eq(HotspotCode.decode(bad, NET), "", "a mistyped check character")
	assert_eq(HotspotCode.encode("8.8.8.8", NET), HotspotCode.encode("8.8.8.8", NET))
	assert_eq(HotspotCode.decode(HotspotCode.encode("8.8.8.8", NET), NET), "", "only private addresses are ever dialled")


func test_a_random_online_code_is_almost_never_a_hotspot_code() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 5
	var accepted: int = 0
	for i: int in 2000:
		var code: String = ""
		for j: int in NET.passcode_length:
			code += NET.passcode_alphabet[rng.randi_range(0, NET.passcode_alphabet.length() - 1)]
		if not HotspotCode.decode(code, NET).is_empty():
			accepted += 1
	assert_lt(accepted, 20, "a typo rarely points at a stranger")


func test_the_phone_picks_its_hotspot_address() -> void:
	assert_eq(HotspotCode.local_ip(PackedStringArray(["127.0.0.1", "fe80::1", "10.1.2.3", "192.168.43.1"])), "192.168.43.1", "the Android hotspot first")
	assert_eq(HotspotCode.local_ip(PackedStringArray(["192.168.1.5", "172.20.10.1"])), "172.20.10.1", "then the iPhone hotspot")
	assert_eq(HotspotCode.local_ip(PackedStringArray(["10.0.0.4", "192.168.1.5"])), "192.168.1.5")
	assert_eq(HotspotCode.local_ip(PackedStringArray(["127.0.0.1", "169.254.3.3", "8.8.8.8"])), "", "no hotspot or Wi-Fi")


func test_a_hosted_room_gets_the_hotspot_code_and_only_once() -> void:
	var rooms: RoomService = RoomService.new(NET, 3)
	var code: String = HotspotCode.encode("192.168.43.1", NET)
	rooms.next_code = code
	var first: RoomService.Room = rooms.create_room(1, "Host", 1)
	assert_eq(first.code, code)
	var second: RoomService.Room = rooms.create_room(2, "Other", 1)
	assert_ne(second.code, code, "the next room gets a normal code")
	assert_eq(rooms.join(code, 3, "Friend"), RoomService.Result.OK)


func test_a_phone_hosts_a_room_for_a_friend_on_the_same_network() -> void:
	var host: GameServer = GameServer.new(load("res://data/rules/game_rules.tres") as GameRules, load("res://data/rules/map_layout.tres") as MapLayout, NET, 4)
	var code: String = HotspotCode.encode("192.168.43.1", NET)
	host.rooms.next_code = code
	assert_eq(host.listen(18941), OK)
	var creator: GameClient = GameClient.new(load("res://data/rules/game_rules.tres") as GameRules, load("res://data/rules/map_layout.tres") as MapLayout, NET)
	var joiner: GameClient = GameClient.new(load("res://data/rules/game_rules.tres") as GameRules, load("res://data/rules/map_layout.tres") as MapLayout, NET)
	assert_eq(creator.connect_to("ws://127.0.0.1:18941"), OK)
	for i: int in 200:
		host.poll(1.0 / 60.0)
		creator.poll(1.0 / 60.0)
		if creator.is_online():
			break
		OS.delay_usec(2000)
	creator.create_room(1)
	assert_eq(joiner.connect_to("ws://127.0.0.1:18941"), OK)
	var joined: bool = false
	for i: int in 400:
		host.poll(1.0 / 60.0)
		creator.poll(1.0 / 60.0)
		joiner.poll(1.0 / 60.0)
		if joiner.is_online() and not joined:
			joiner.join_room(code)
			joined = true
		if joined and joiner.room.get("code", "") == code and (joiner.room.get("members", []) as Array).size() == 2:
			break
		OS.delay_usec(2000)
	assert_eq(creator.room.get("code", ""), code, "the host's room has the hotspot code")
	assert_eq((joiner.room.get("members", []) as Array).size(), 2, "the friend joined with the code alone")
	creator.close()
	joiner.close()
	host.stop()
