extends Control
## AVATAR: edit the player name. The soldier preview stands on the right.
## A valid change is saved with SAVE, with the keyboard's confirm key, or when going back.

const C = preload("res://game/autoload/config.gd")
const Widgets = preload("res://game/ui/widgets.gd")
const Screens = preload("res://game/ui/screen_manager.gd")
const CharacterModel = preload("res://game/player/character_model.gd")
const SettingsPanel = preload("res://game/ui/settings_panel.gd")

const CAMERA_DISTANCE := 3.8
const CAMERA_FOV := 40.0

var _edit: LineEdit
var _save: Button
var _hint: Label
var _soldier: Node3D


func _ready() -> void:
	var background := ColorRect.new()
	background.color = C.BG_MAIN
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var scene := Node3D.new()
	scene.add_child(Widgets.ground_plane())
	_soldier = CharacterModel.create_soldier(0)
	_soldier.rotation_degrees.y = -14.0
	scene.add_child(_soldier)
	add_child(Widgets.stage(scene, Vector3(0.0, 1.15, CAMERA_DISTANCE), Vector3(0.0, 1.0, 0.0), CAMERA_FOV))
	CharacterModel.start_idle(_soldier)

	add_child(Widgets.side_fade())
	add_child(Widgets.safe_container(_build_ui(), 32))

	resized.connect(_place_soldier)
	_place_soldier()
	_update_state()


func _build_ui() -> Control:
	var root := Widgets.vbox(12)

	var header := Widgets.hbox(16)
	header.add_child(SettingsPanel.make_back_button(on_back))
	var title := Widgets.label("AVATAR", "HeadingLabel")
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(title)
	root.add_child(header)
	root.add_child(Widgets.hline())

	var column := Widgets.vbox(10)
	column.custom_minimum_size = Vector2(460.0, 0.0)
	column.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN

	column.add_child(Widgets.label("PLAYER NAME", "MutedLabel"))
	_edit = LineEdit.new()
	_edit.text = Settings.get_string(Settings.K_NAME)
	_edit.max_length = C.MAX_NAME_LENGTH
	_edit.placeholder_text = "Player name"
	_edit.custom_minimum_size = Vector2(0.0, 60.0)
	_edit.select_all_on_focus = true
	_edit.context_menu_enabled = false
	_edit.text_changed.connect(_on_text_changed)
	_edit.text_submitted.connect(_on_submitted)
	column.add_child(_edit)

	_hint = Widgets.label("1 to %d characters. Other players see this name." % C.MAX_NAME_LENGTH, "MutedLabel", HORIZONTAL_ALIGNMENT_LEFT, true)
	column.add_child(_hint)

	column.add_child(Widgets.gap(0.0, 6.0))
	_save = Widgets.button("SAVE", _save_name, "PrimaryButton", 200.0)
	_save.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	column.add_child(_save)

	root.add_child(Widgets.spacer())
	root.add_child(column)
	root.add_child(Widgets.spacer())
	return root


func _place_soldier() -> void:
	if _soldier == null or size.y <= 0.0:
		return
	var half_height := tan(deg_to_rad(CAMERA_FOV) * 0.5) * CAMERA_DISTANCE
	_soldier.position.x = half_height * (size.x / size.y) * 0.45


func _current_clean() -> String:
	return C.sanitize_name(_edit.text)


func _update_state() -> void:
	var clean := _current_clean()
	var stored := Settings.get_string(Settings.K_NAME)
	_save.disabled = clean == "" or clean == stored
	if clean == "":
		_hint.text = "Enter a name (1 to %d characters)." % C.MAX_NAME_LENGTH
		_hint.add_theme_color_override("font_color", C.WARNING)
	else:
		_hint.text = "1 to %d characters. Other players see this name." % C.MAX_NAME_LENGTH
		_hint.remove_theme_color_override("font_color")


func _on_text_changed(_new_text: String) -> void:
	_update_state()


func _on_submitted(_text: String) -> void:
	_save_name()


func _save_name() -> void:
	var clean := _current_clean()
	if clean == "":
		Audio.play_ui("error")
		_update_state()
		return
	Settings.set_value(Settings.K_NAME, clean)
	_edit.text = clean
	_edit.release_focus()
	_update_state()
	Audio.play_ui("confirm")
	Screens.instance.show_toast("NAME SAVED")


## Android back button and the back arrow. A valid unsaved name is kept.
func on_back() -> void:
	var clean := _current_clean()
	if clean != "" and clean != Settings.get_string(Settings.K_NAME):
		Settings.set_value(Settings.K_NAME, clean)
	_edit.release_focus()
	Screens.instance.pop_screen()