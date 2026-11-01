extends Node
## Persistent player settings, saved to user://settings.cfg (autoload name: Settings).
##
## Values are validated on every change. A short timer batches saves so dragging a slider
## does not write the file constantly; the file is also saved when the app is paused or
## closed.
##
## Meaning of the two sensitivity values (used from Phase 3):
##   camera sensitivity = look speed during normal play
##   aim sensitivity    = look speed while the SHOOT button is held or a scope is used

signal changed(key: String)

const PATH := "user://settings.cfg"
const SECTION := "settings"

const K_NAME := "player_name"
const K_AVATAR := "avatar_id"
const K_MUSIC := "music_on"
const K_SFX := "sfx_on"
const K_GFX := "graphics"
const K_CAM := "camera_sensitivity"
const K_AIM := "aim_sensitivity"
const K_VIB := "vibration"
const K_XH_SHAPE := "crosshair_shape"
const K_XH_SIZE := "crosshair_size"

const GRAPHICS_LOW := 0
const GRAPHICS_MEDIUM := 1
const GRAPHICS_HIGH := 2
const GRAPHICS_LABELS := ["LOW", "MEDIUM", "HIGH"]

const CROSSHAIR_PLUS := 0
const CROSSHAIR_CIRCLE := 1
const CROSSHAIR_SQUARE := 2
const CROSSHAIR_LABELS := ["PLUS", "CIRCLE", "SQUARE"]

const SENS_MIN := 0.2
const SENS_MAX := 3.0
const XH_SIZE_MIN := 0.5
const XH_SIZE_MAX := 2.0

## One profile per graphics level. These are starting values and have not been measured
## on real devices yet; they will be tuned from your test reports.
const GRAPHICS_PROFILES := [
	{ # LOW
		"render_scale": 0.6, "msaa": 0, "shadows": false, "shadow_atlas": 0,
		"view_distance": 60.0, "particles": 0.4, "max_fps": 60,
	},
	{ # MEDIUM
		"render_scale": 0.8, "msaa": 0, "shadows": true, "shadow_atlas": 1024,
		"view_distance": 90.0, "particles": 0.7, "max_fps": 60,
	},
	{ # HIGH
		"render_scale": 1.0, "msaa": 1, "shadows": true, "shadow_atlas": 2048,
		"view_distance": 140.0, "particles": 1.0, "max_fps": 60,
	},
]

var _values: Dictionary = {}
var _save_timer: Timer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_values = _defaults()
	_save_timer = Timer.new()
	_save_timer.one_shot = true
	_save_timer.wait_time = 0.6
	_save_timer.timeout.connect(save_settings)
	add_child(_save_timer)
	load_settings()
	apply_graphics()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_settings()


func _defaults() -> Dictionary:
	return {
		K_NAME: Config.default_player_name(),
		K_AVATAR: 0,
		K_MUSIC: true,
		K_SFX: true,
		K_GFX: GRAPHICS_MEDIUM,
		K_CAM: 1.0,
		K_AIM: 0.7,
		K_VIB: true,
		K_XH_SHAPE: CROSSHAIR_PLUS,
		K_XH_SIZE: 1.0,
	}


func _sanitize(key: String, value: Variant) -> Variant:
	match key:
		K_NAME:
			var clean := Config.sanitize_name(str(value))
			return clean if clean != "" else Config.default_player_name()
		K_AVATAR:
			return maxi(0, int(value))
		K_MUSIC, K_SFX, K_VIB:
			return bool(value)
		K_GFX:
			return clampi(int(value), GRAPHICS_LOW, GRAPHICS_HIGH)
		K_CAM, K_AIM:
			return clampf(float(value), SENS_MIN, SENS_MAX)
		K_XH_SHAPE:
			return clampi(int(value), CROSSHAIR_PLUS, CROSSHAIR_SQUARE)
		K_XH_SIZE:
			return clampf(float(value), XH_SIZE_MIN, XH_SIZE_MAX)
	return value


# ---- Access ---------------------------------------------------------------------

func get_value(key: String) -> Variant:
	return _values.get(key)


func get_bool(key: String) -> bool:
	return bool(_values.get(key, false))


func get_int(key: String) -> int:
	return int(_values.get(key, 0))


func get_float(key: String) -> float:
	return float(_values.get(key, 0.0))


func get_string(key: String) -> String:
	return str(_values.get(key, ""))


func set_value(key: String, value: Variant) -> void:
	if not _values.has(key):
		return
	var clean: Variant = _sanitize(key, value)
	if _values[key] == clean:
		return
	_values[key] = clean
	if key == K_GFX:
		apply_graphics()
	changed.emit(key)
	_save_timer.start()


func reset_defaults() -> void:
	var defaults := _defaults()
	defaults[K_NAME] = _values[K_NAME]  # keep the player's name
	for key in defaults.keys():
		set_value(key, defaults[key])


# ---- Persistence ----------------------------------------------------------------

func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		save_settings()  # first run: store the defaults, including the generated name
		return
	for key in _values.keys():
		_values[key] = _sanitize(key, cfg.get_value(SECTION, key, _values[key]))


func save_settings() -> void:
	var cfg := ConfigFile.new()
	for key in _values.keys():
		cfg.set_value(SECTION, key, _values[key])
	var err := cfg.save(PATH)
	if err != OK:
		push_warning("Could not save settings (error %d)" % err)


# ---- Graphics ---------------------------------------------------------------------

func graphics_profile() -> Dictionary:
	return GRAPHICS_PROFILES[get_int(K_GFX)]


## Applies the parts of the graphics profile that are global. Lights, cameras and
## effects read graphics_profile() themselves when they are created.
func apply_graphics() -> void:
	var profile := graphics_profile()
	var root := get_tree().root
	root.scaling_3d_scale = float(profile["render_scale"])
	if int(profile["msaa"]) == 0:
		root.msaa_3d = Viewport.MSAA_DISABLED
	else:
		root.msaa_3d = Viewport.MSAA_2X
	if bool(profile["shadows"]):
		RenderingServer.directional_shadow_atlas_set_size(int(profile["shadow_atlas"]), true)
	Engine.max_fps = int(profile["max_fps"])


# ---- Haptics ----------------------------------------------------------------------

func vibrate(milliseconds: int = 30) -> void:
	if get_bool(K_VIB):
		Input.vibrate_handheld(milliseconds)