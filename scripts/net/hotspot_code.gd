class_name HotspotCode
extends RefCounted
## A hotspot room code carries the address of the phone that hosts it, so players only ever type
## the code (no server address). The host's IPv4 address is written in 7 characters of the room
## code alphabet (base 31, most significant first) plus 1 check character: 8 characters, like
## every other room code.

const DIGITS: int = 7


## The room code for the IPv4 address `ip`, or "" if it is not one.
static func encode(ip: String, rules: NetRules) -> String:
	var value: int = _ip_to_int(ip)
	if value < 0 or rules.passcode_length != DIGITS + 1:
		return ""
	var base: int = rules.passcode_alphabet.length()
	var digits: Array[int] = []
	for i: int in DIGITS:
		digits.push_front(value % base)
		value /= base
	var code: String = ""
	for digit: int in digits:
		code += rules.passcode_alphabet[digit]
	return code + rules.passcode_alphabet[_check(digits, base)]


## The host's address in `code`, or "" when the code is not a valid hotspot code (wrong length or
## characters, failed check, or an address that is not on a private network).
static func decode(code: String, rules: NetRules) -> String:
	var text: String = code.strip_edges().to_upper()
	if text.length() != DIGITS + 1 or rules.passcode_length != DIGITS + 1:
		return ""
	var base: int = rules.passcode_alphabet.length()
	var digits: Array[int] = []
	for i: int in text.length():
		var at: int = rules.passcode_alphabet.find(text[i])
		if at < 0:
			return ""
		digits.append(at)
	var check: int = digits.pop_back()
	if _check(digits, base) != check:
		return ""
	var value: int = 0
	for digit: int in digits:
		value = value * base + digit
	if value > 0xFFFFFFFF:
		return ""
	var ip: String = "%d.%d.%d.%d" % [(value >> 24) & 255, (value >> 16) & 255, (value >> 8) & 255, value & 255]
	return ip if is_private(ip) else ""


## The WebSocket address of the hotspot room `code` (ws://ip:port), or "".
static func url_for(code: String, rules: NetRules) -> String:
	var ip: String = decode(code, rules)
	return "" if ip.is_empty() else "ws://%s:%d" % [ip, rules.default_port]


## The address this phone has on its hotspot or Wi-Fi: the Android hotspot range first, then the
## iPhone one, then any other private IPv4 address. "" when there is none.
static func local_ip(addresses: PackedStringArray) -> String:
	var best: String = ""
	var best_rank: int = 99
	for address: String in addresses:
		if not is_private(address):
			continue
		var rank: int = 3
		if address.begins_with("192.168.43."):
			rank = 0
		elif address.begins_with("172.20.10."):
			rank = 1
		elif address.begins_with("192.168."):
			rank = 2
		if rank < best_rank:
			best = address
			best_rank = rank
	return best


## True for 10.x.x.x, 172.16-31.x.x and 192.168.x.x.
static func is_private(ip: String) -> bool:
	var parts: PackedStringArray = ip.split(".")
	if _ip_to_int(ip) < 0:
		return false
	var a: int = parts[0].to_int()
	var b: int = parts[1].to_int()
	return a == 10 or (a == 172 and b >= 16 and b <= 31) or (a == 192 and b == 168)


static func _check(digits: Array[int], base: int) -> int:
	var sum: int = 0
	for i: int in digits.size():
		sum += digits[i] * (i + 1)
	return sum % base


static func _ip_to_int(ip: String) -> int:
	var parts: PackedStringArray = ip.split(".")
	if parts.size() != 4:
		return -1
	var value: int = 0
	for part: String in parts:
		if not part.is_valid_int():
			return -1
		var n: int = part.to_int()
		if n < 0 or n > 255:
			return -1
		value = value * 256 + n
	return value
