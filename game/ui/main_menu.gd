extends Control
## Main menu: five buttons on the left, a 3D soldier with a gentle idle movement on the
## right, the player name and version at the bottom.

const C = preload("res://game/autoload/config.gd")
const Widgets = preload("res://game/ui/widgets.gd")
const Popups = preload("res://game/ui/popups.gd")
const Screens = preload("res://game/ui/screen_manager.gd")
const CharacterModel = preload("res://game/player/character_model.gd")
const AvatarScreen = preload("res://game/ui/avatar_screen.gd")
const SettingsPanel = preload("res://game/ui/settings_panel.gd")

const CAMERA_DISTANCE := 3.8
const CAMERA_FOV := 40.0

var _soldier: Node3D
var _name_label: Label


func _ready() -> void:
	var background := ColorRect.new()
	background.color = C.BG_MAIN
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var scene := Node3D.new()
	scene.add_child(Widgets.ground_plane())
	_soldier = CharacterModel.create_soldier(0)
	_soldier.rotation_degrees.y = -18.0
	scene.add_child(_soldier)
	add_child(Widgets.stage(scene, Vector3(0.0, 1.15, CAMERA_DISTANCE), Vector3(0.0, 1.0, 0.0), CAMERA_FOV))
	CharacterModel.start_idle(_soldier)

	add_child(Widgets.side_fade())
	add_child(Widgets.bottom_fade(0.6))
	var content := _build_ui()
	add_child(Widgets.safe_container(content, 40))
	Widgets.fade_in(content, 0.25)

	resized.connect(_update_soldier_position)
	_update_soldier_position()
	Settings.changed.connect(_on_setting_changed)
	Audio.play_menu_music()


func _build_ui() -> Control:
	var outer := Widgets.vbox(0)
	outer.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var column := Widgets.vbox(10)
	column.custom_minimum_size = Vector2(340.0, 0.0)
	column.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	column.add_child(Widgets.label("QUIET FRONT", "TitleLabel"))
	column.add_child(Widgets.label("LAN TACTICAL SHOOTER", "MutedLabel"))
	column.add_child(Widgets.gap(0.0, 14.0))

	var play := Widgets.button("PLAY", Callable())
	play.disabled = true
	column.add_child(play)
	column.add_child(Widgets.button("MULTIPLAYER", _on_multiplayer, "PrimaryButton"))
	column.add_child(Widgets.button("SETTINGS", _on_settings))
	column.add_child(Widgets.button("SHOP", _on_shop))
	column.add_child(Widgets.button("AVATAR", _on_avatar))

	outer.add_child(Widgets.spacer())
	outer.add_child(column)
	outer.add_child(Widgets.spacer())
	outer.add_child(_build_footer())
	return outer


func _build_footer() -> Control:
	var row := Widgets.hbox(16)
	var who := Widgets.vbox(0)
	who.add_child(Widgets.label("PLAYER", "MutedLabel"))
	_name_label = Widgets.label(Settings.get_string(Settings.K_NAME))
	who.add_child(_name_label)
	row.add_child(who)
	row.add_child(Widgets.spacer())
	var version := Widgets.label("v" + C.VERSION, "MutedLabel")
	version.size_flags_vertical = Control.SIZE_SHRINK_END
	row.add_child(version)
	return row


## Keeps the soldier on the right-hand side of the screen for any screen shape.
func _update_soldier_position() -> void:
	if _soldier == null or size.y <= 0.0:
		return
	var half_height := tan(deg_to_rad(CAMERA_FOV) * 0.5) * CAMERA_DISTANCE
	var aspect := size.x / size.y
	_soldier.position.x = half_height * aspect * 0.5


func _on_setting_changed(key: String) -> void:
	if key == Settings.K_NAME and _name_label != null:
		_name_label.text = Settings.get_string(Settings.K_NAME)


func _on_multiplayer() -> void:
	# Replaced in Phase 2 by the real multiplayer screen.
	Popups.info("LAN MULTIPLAYER", "Multiplayer arrives in the next build.")


func _on_settings() -> void:
	Screens.instance.push_screen(SettingsPanel.new())


func _on_shop() -> void:
	Screens.instance.show_toast("SHOP: COMING SOON")


func _on_avatar() -> void:
	Screens.instance.push_screen(AvatarScreen.new())


## Called by the ScreenManager when the Android back button is pressed on this screen.
func on_back() -> void:
	Popups.confirm_quit_app(func() -> void: get_tree().quit())