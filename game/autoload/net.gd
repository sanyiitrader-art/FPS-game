extends Node
## Network layer (autoload name: Net).
##
## Phase 1 only contains the helpers that inspect this phone's local network. They tell
## the MULTIPLAYER screen whether the phone can host. Hosting, joining and discovery are
## added in Phase 2 (this file is then replaced by a complete new version).
##
## How "can this phone host?" is decided without any permission: the phone must have a
## private IPv4 address (10.x, 172.16-31.x or 192.168.x) on a non-mobile-data interface.
## Android hotspot interfaces are recognised by name where possible. Interface names differ
## between phone makers, so this has to be confirmed on real devices.

## Interfaces that are loopback, mobile data or tunnels. They never carry LAN play.
const IGNORED_NAME_PREFIXES: PackedStringArray = [
	"rmnet", "ccmni", "pdp", "tun", "ppp", "dummy", "v4-rmnet", "clat", "sit", "ip6", "tap",
]

## Interface names Android commonly uses for the phone's own hotspot access point.
const HOTSPOT_NAME_PREFIXES: PackedStringArray = ["ap", "swlan", "softap"]


static func _starts_with_any(text: String, prefixes: PackedStringArray) -> bool:
	for prefix in prefixes:
		if text.begins_with(prefix):
			return true
	return false


static func is_private_ipv4(ip: String) -> bool:
	var parts := ip.split(".")
	if parts.size() != 4:
		return false
	for part in parts:
		if not part.is_valid_int():
			return false
		var value := int(part)
		if value < 0 or value > 255:
			return false
	var a := int(parts[0])
	var b := int(parts[1])
	return a == 10 or (a == 172 and b >= 16 and b <= 31) or (a == 192 and b == 168)


## Turns the raw list from IP.get_local_interfaces() into usable LAN addresses.
## Each entry: {"name": String, "ip": String, "hotspot": bool}. Hotspot entries come first.
static func classify_interfaces(interfaces: Array) -> Array[Dictionary]:
	var hotspots: Array[Dictionary] = []
	var others: Array[Dictionary] = []
	for iface in interfaces:
		var iface_name := String(iface.get("name", "")).to_lower()
		if iface_name == "lo" or _starts_with_any(iface_name, IGNORED_NAME_PREFIXES):
			continue
		var is_hotspot := _starts_with_any(iface_name, HOTSPOT_NAME_PREFIXES)
		for address in iface.get("addresses", []):
			var ip := String(address)
			if not is_private_ipv4(ip):
				continue
			var entry := {"name": iface_name, "ip": ip, "hotspot": is_hotspot}
			if is_hotspot:
				hotspots.append(entry)
			else:
				others.append(entry)
	hotspots.append_array(others)
	return hotspots


## Broadcast address of the phone's /24 network (the usual size for phone hotspots).
static func broadcast_address(ip: String) -> String:
	var parts := ip.split(".")
	if parts.size() != 4:
		return "255.255.255.255"
	return "%s.%s.%s.255" % [parts[0], parts[1], parts[2]]


## Most likely address of the router or hosting phone on the same /24 network.
static func gateway_guess(ip: String) -> String:
	var parts := ip.split(".")
	if parts.size() != 4:
		return ""
	return "%s.%s.%s.1" % [parts[0], parts[1], parts[2]]


func local_candidates() -> Array[Dictionary]:
	return classify_interfaces(IP.get_local_interfaces())


func can_host() -> bool:
	return not local_candidates().is_empty()


func hotspot_active() -> bool:
	for entry in local_candidates():
		if bool(entry["hotspot"]):
			return true
	return false


## The address this phone would use on the LAN, or "" if there is none.
func primary_ip() -> String:
	var candidates := local_candidates()
	if candidates.is_empty():
		return ""
	return String(candidates[0]["ip"])