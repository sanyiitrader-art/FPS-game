extends Node
## Global constants and small static helpers (autoload name: Config).
##
## Runtime-only scripts (UI, audio, settings) use the autoload name "Config".
## Pure-logic scripts that must also run in headless tests (session, protocol,
## scoring, ammo) preload this script instead:
##     const C = preload("res://game/autoload/config.gd")
## All helpers here are static so both ways work.

const GAME_NAME := "Quiet Front"
const VERSION := "0.1.0"

# ---- Network ------------------------------------------------------------------
const PROTOCOL_VERSION := 1
const DISCOVERY_PORT := 47777
const GAME_PORT := 47778

# ---- Lobby limits ---------------------------------------------------------------
const MIN_PLAYERS := 2
const MAX_PLAYERS := 20
const MIN_DURATION := 120
const MAX_DURATION := 1800
const DURATION_STEP := 30
const DEFAULT_DURATION := 600
const MAX_NAME_LENGTH := 16
const MAX_TEAM_NAME_LENGTH := 16

# ---- Teams and modes ------------------------------------------------------------
const TEAM_NONE := -1
const TEAM_A := 0
const TEAM_B := 1
const DEFAULT_TEAM_NAMES := ["Team A", "Team B"]

const MODE_NORMAL := "normal"
const MODE_TEAM := "team"
const MODES := [MODE_NORMAL, MODE_TEAM]
const MODE_LABELS := {"normal": "NORMAL", "team": "TEAM"}

# ---- Maps -----------------------------------------------------------------------
const DEFAULT_MAP := "urban"
const MAP_IDS := ["urban", "industrial"]
const MAPS := {
	"urban": {
		"label": "URBAN",
		"layout": "res://data/urban.json",
		"preview": "res://assets/ui/map_urban.png",
		"placeholder": "res://assets/generated/map_urban_placeholder.png",
	},
	"industrial": {
		"label": "INDUSTRIAL",
		"layout": "res://data/industrial.json",
		"preview": "res://assets/ui/map_industrial.png",
		"placeholder": "res://assets/generated/map_industrial_placeholder.png",
	},
}

# ---- Data files -----------------------------------------------------------------
const WEAPONS_PATH := "res://data/weapons.json"

# ---- Calm Tactical palette ------------------------------------------------------
const BG_MAIN := Color(0.082353, 0.098039, 0.117647)       # #15191E
const BG_SECOND := Color(0.125490, 0.156863, 0.188235)     # #202830
const PANEL := Color(0.160784, 0.203922, 0.239216)         # #29343D
const ACCENT := Color(0.384314, 0.713725, 0.647059)        # #62B6A5
const ACCENT_2 := Color(0.470588, 0.615686, 0.733333)      # #789DBB
const TEXT := Color(0.898039, 0.913725, 0.925490)          # #E5E9EC
const TEXT_2 := Color(0.603922, 0.650980, 0.682353)        # #9AA6AE
const BORDER := Color(0.215686, 0.262745, 0.298039)        # #37434C

# Situational colors
const FRIENDLY := Color(0.431373, 0.627451, 0.843137)     # soft blue
const ENEMY := Color(0.752941, 0.345098, 0.329412)        # muted red
const HEALTH := Color(0.431373, 0.686275, 0.431373)       # muted green
const WARNING := Color(0.878431, 0.666667, 0.313725)      # soft amber
const DEATH := Color(0.431373, 0.117647, 0.117647)        # dark red

# ---- UI metrics (designed for a 1280x720 base, scaled by the stretch mode) ------
const SPACE := 8
const RADIUS := 6
const BORDER_WIDTH := 1
const BUTTON_HEIGHT := 56
const TOUCH_MIN := 48
const FONT_TITLE := 40
const FONT_HEADING := 28
const FONT_BODY := 22
const FONT_SMALL := 18
const TRANSITION := 0.18


# ---- Text helpers ---------------------------------------------------------------

static func format_time(total_seconds: int) -> String:
	var secs := maxi(0, total_seconds)
	return "%02d:%02d" % [secs / 60, secs % 60]


static func clamp_duration(seconds: int) -> int:
	var steps := int(round(float(seconds) / float(DURATION_STEP)))
	return clampi(steps * DURATION_STEP, MIN_DURATION, MAX_DURATION)


static func _is_bad_char(code: int) -> bool:
	if code < 32 or code == 127:
		return true
	if code >= 0x200B and code <= 0x200F:
		return true
	if code >= 0x202A and code <= 0x202E:
		return true
	if code >= 0x2066 and code <= 0x2069:
		return true
	# BOM and the square brackets (they would be read as BBCode in rich text labels)
	return code == 0xFEFF or code == 0x5B or code == 0x5D


## Removes control and formatting characters, collapses spaces, trims, limits length.
static func sanitize_text(raw: String, max_len: int) -> String:
	var out := ""
	var last_space := true
	for i in raw.length():
		var ch := raw.substr(i, 1)
		var code := ch.unicode_at(0)
		if _is_bad_char(code):
			continue
		if code == 32:
			if last_space:
				continue
			last_space = true
		else:
			last_space = false
		out += ch
		if out.length() >= max_len:
			break
	return out.strip_edges()


## Returns "" when nothing usable is left.
static func sanitize_name(raw: String) -> String:
	return sanitize_text(raw, MAX_NAME_LENGTH)


static func sanitize_team_name(raw: String, fallback: String) -> String:
	var clean := sanitize_text(raw, MAX_TEAM_NAME_LENGTH)
	return fallback if clean == "" else clean


static func default_player_name() -> String:
	return "OPERATOR-%03d" % randi_range(100, 999)


static func map_label(map_id: String) -> String:
	if MAPS.has(map_id):
		return String(MAPS[map_id]["label"])
	return map_id.to_upper()


static func mode_label(mode_id: String) -> String:
	return String(MODE_LABELS.get(mode_id, mode_id.to_upper()))


# ---- Data helpers -----------------------------------------------------------------

static var _weapon_data: Dictionary = {}


static func load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_warning("JSON file not found: " + path)
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Dictionary:
		return parsed
	push_error("JSON file is invalid or not an object: " + path)
	return {}


## Balance data from data/weapons.json (loaded once).
static func balance() -> Dictionary:
	if _weapon_data.is_empty():
		_weapon_data = load_json(WEAPONS_PATH)
	return _weapon_data


static func weapon_ids() -> Array[String]:
	var weapons: Dictionary = balance().get("weapons", {})
	var ids: Array[String] = []
	for id in weapons.keys():
		ids.append(String(id))
	ids.sort_custom(func(a: String, b: String) -> bool:
		return int(weapons[a].get("order", 99)) < int(weapons[b].get("order", 99)))
	return ids


static func get_weapon(weapon_id: String) -> Dictionary:
	var weapons: Dictionary = balance().get("weapons", {})
	return weapons.get(weapon_id, {})


# ---- Optional asset helpers --------------------------------------------------------
# Every model, texture and sound is optional so the game always runs; the code falls
# back to placeholders when a file has not been added yet.

## Loads a resource if it exists, otherwise returns null.
static func load_optional(path: String) -> Resource:
	if path != "" and ResourceLoader.exists(path):
		return load(path)
	return null


## Finds an asset file below dir_path (searching sub-folders). If hint is given, the
## first file whose name contains it wins. Returns "" when nothing matches.
static func find_asset(dir_path: String, exts: PackedStringArray, hint: String = "", depth: int = 4) -> String:
	var found: Array[String] = []
	_collect_files(dir_path, exts, depth, found)
	if found.is_empty():
		return ""
	found.sort()
	if hint != "":
		var wanted := hint.to_lower()
		for path in found:
			if path.get_file().to_lower().contains(wanted):
				return path
	return found[0]


static func _collect_files(dir_path: String, exts: PackedStringArray, depth: int, out: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	if depth > 0:
		for sub in dir.get_directories():
			_collect_files(dir_path.path_join(sub), exts, depth - 1, out)
	for file in dir.get_files():
		# Exported games list ".import" / ".remap" entries instead of the original name.
		var clean := file.trim_suffix(".import").trim_suffix(".remap")
		if clean.get_extension().to_lower() in exts:
			var path := dir_path.path_join(clean)
			if not out.has(path):
				out.append(path)