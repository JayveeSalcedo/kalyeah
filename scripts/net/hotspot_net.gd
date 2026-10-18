class_name HotspotNet
extends RefCounted
## Finding the other phone on a hotspot or Wi-Fi without anyone typing an address or a code. The
## phone that made the hotspot is the router: it is the ".1" of the network everyone else is on
## (192.168.43.1 on Android, 172.20.10.1 on iPhone), and it is where the room server runs.


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


## Where a room server could be, most likely first: the ".1" of every private network this phone
## is on, then the two phone-hotspot addresses.
static func candidates(addresses: PackedStringArray, port: int) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	var hosts: Array[String] = []
	for address: String in addresses:
		if is_private(address):
			var parts: PackedStringArray = address.split(".")
			hosts.append("%s.%s.%s.1" % [parts[0], parts[1], parts[2]])
	hosts.append("192.168.43.1")
	hosts.append("172.20.10.1")
	for host: String in hosts:
		var url: String = "ws://%s:%d" % [host, port]
		if not found.has(url):
			found.append(url)
	return found


## True for 10.x.x.x, 172.16-31.x.x and 192.168.x.x.
static func is_private(ip: String) -> bool:
	var parts: PackedStringArray = ip.split(".")
	if parts.size() != 4:
		return false
	for part: String in parts:
		if not part.is_valid_int() or part.to_int() < 0 or part.to_int() > 255:
			return false
	var a: int = parts[0].to_int()
	var b: int = parts[1].to_int()
	return a == 10 or (a == 172 and b >= 16 and b <= 31) or (a == 192 and b == 168)
