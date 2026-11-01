extends Control
## App entry point (scene: game/main.tscn).
##
## Shows the loading screen, runs the real start-up steps one after another, builds the
## main menu while the loading screen is still up, then swaps to it. Nothing is delayed on
## purpose: if the steps finish quickly, the menu opens at once. If a step fails, the
## loading screen shows the problem with RETRY and QUIT.

const C = preload("res://game/autoload/config.gd")
const Screens = preload("res://game/ui/screen_manager.gd")
const LoadingScreen = preload("res://game/ui/loading_screen.gd")
const MainMenu = preload("res://game/ui/main_menu.gd")

var _screens: Control
var _loading: LoadingScreen
var _menu: MainMenu
var _booting := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	RenderingServer.set_default_clear_color(C.BG_MAIN)

	_screens = Screens.new()
	add_child(_screens)

	_loading = LoadingScreen.new()
	_loading.retry_requested.connect(_boot)
	_loading.quit_requested.connect(_quit)
	_screens.show_screen(_loading)
	_boot()


func _boot() -> void:
	if _booting:
		return
	_booting = true
	var steps: Array[Dictionary] = [
		{"text": "LOADING GAME DATA", "run": _step_data},
		{"text": "PREPARING AUDIO", "run": _step_audio},
		{"text": "BUILDING MENU", "run": _step_menu},
	]
	for i in steps.size():
		_loading.set_status(String(steps[i]["text"]))
		_loading.set_progress(float(i) / float(steps.size()))
		# One frame so the loading screen is actually drawn before each step runs.
		await get_tree().process_frame
		var run: Callable = steps[i]["run"]
		var error: String = run.call()
		if error != "":
			_loading.show_error(error)
			_booting = false
			return
	_loading.set_progress(1.0)
	await get_tree().process_frame
	_booting = false
	_show_menu()


## Each step returns "" on success or a short error message.
func _step_data() -> String:
	var data := C.balance()
	if data.is_empty() or not data.has("weapons"):
		return "COULD NOT LOAD GAME DATA"
	if C.weapon_ids().is_empty():
		return "GAME DATA HAS NO WEAPONS"
	return ""


func _step_audio() -> String:
	# Starts the menu music if a music file has been added; silent otherwise.
	Audio.play_menu_music()
	return ""


func _step_menu() -> String:
	if _menu != null and is_instance_valid(_menu):
		_menu.queue_free()
	_menu = MainMenu.new()
	# Added hidden so its _ready() (the expensive part) runs now, behind the loading screen.
	_menu.visible = false
	add_child(_menu)
	return ""


func _show_menu() -> void:
	remove_child(_menu)
	_menu.visible = true
	_screens.show_screen(_menu)
	_loading = null


func _quit() -> void:
	get_tree().quit()