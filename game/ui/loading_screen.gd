extends Control
## Startup screen: a dark scene of soldiers, a quiet wordmark and a thin loading animation
## near the bottom. Main drives it (status text, progress, errors). It stays on screen only
## while real loading work is running.

const C = preload("res://game/autoload/config.gd")
const Widgets = preload("res://game/ui/widgets.gd")
const CharacterModel = preload("res://game/player/character_model.gd")

signal retry_requested
signal quit_requested


## Thin bar: a faint track, the real progress behind it and a sweeping highlight.
class LoadingBar extends Control:
	var progress: float = 0.0
	var phase: float = 0.0
	var track_color: Color = Color(1.0, 1.0, 1.0, 0.08)
	var fill_color: Color = Color(1.0, 1.0, 1.0, 0.3)
	var sweep_color: Color = Color.WHITE

	func _init() -> void:
		custom_minimum_size = Vector2(0.0, 6.0)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		phase = fposmod(phase + delta * 0.9, 1.0)
		queue_redraw()

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), track_color)
		if progress > 0.0:
			draw_rect(Rect2(0.0, 0.0, size.x * progress, size.y), fill_color)
		var seg_w := size.x * 0.22
		var x0 := lerpf(-seg_w, size.x, phase)
		var left := maxf(x0, 0.0)
		var right := minf(x0 + seg_w, size.x)
		if right > left:
			draw_rect(Rect2(left, 0.0, right - left, size.y), sweep_color)


var _status: Label
var _bar: LoadingBar
var _error_row: HBoxContainer
var _soldiers: Array[Node3D] = []


func _ready() -> void:
	var background := ColorRect.new()
	background.color = C.BG_MAIN
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	add_child(Widgets.stage(_build_scene(), Vector3(0.0, 1.3, 4.9), Vector3(0.0, 1.05, 0.0), 38.0))
	for soldier in _soldiers:
		CharacterModel.start_idle(soldier)

	add_child(Widgets.vignette())
	add_child(Widgets.bottom_fade())
	add_child(Widgets.safe_container(_build_bottom(), 40))


func _build_scene() -> Node3D:
	var root := Node3D.new()
	root.add_child(Widgets.ground_plane())
	var placements := [
		{"x": -1.25, "z": -0.9, "yaw": 18.0, "variant": 1},
		{"x": 1.2, "z": -0.7, "yaw": -16.0, "variant": 2},
		{"x": 0.0, "z": 0.0, "yaw": 0.0, "variant": 0},
	]
	for spec in placements:
		var soldier := CharacterModel.create_soldier(int(spec["variant"]))
		soldier.position = Vector3(float(spec["x"]), 0.0, float(spec["z"]))
		soldier.rotation_degrees.y = float(spec["yaw"])
		root.add_child(soldier)
		_soldiers.append(soldier)
	return root


func _build_bottom() -> Control:
	var column := Widgets.vbox(10)
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.alignment = BoxContainer.ALIGNMENT_END

	column.add_child(Widgets.label("QUIET FRONT", "TitleLabel"))
	_status = Widgets.label("LOADING", "MutedLabel")
	column.add_child(_status)

	_bar = LoadingBar.new()
	_bar.track_color = Color(C.TEXT, 0.08)
	_bar.fill_color = Color(C.ACCENT, 0.35)
	_bar.sweep_color = C.ACCENT
	_bar.custom_minimum_size = Vector2(420.0, 6.0)
	_bar.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	column.add_child(_bar)

	_error_row = Widgets.hbox(12)
	_error_row.visible = false
	_error_row.add_child(Widgets.button("RETRY", _on_retry, "PrimaryButton", 160.0))
	_error_row.add_child(Widgets.button("QUIT", _on_quit, "", 160.0))
	column.add_child(_error_row)
	return column


func set_status(text: String) -> void:
	if _status != null:
		_status.text = text


func set_progress(value: float) -> void:
	if _bar != null:
		_bar.progress = clampf(value, 0.0, 1.0)


## Replaces the loading animation with an error message and RETRY / QUIT buttons.
func show_error(message: String) -> void:
	_status.text = message
	_status.theme_type_variation = "DangerLabel"
	_bar.visible = false
	_error_row.visible = true


func clear_error() -> void:
	_status.text = "LOADING"
	_status.theme_type_variation = "MutedLabel"
	_bar.visible = true
	_error_row.visible = false


func _on_retry() -> void:
	clear_error()
	retry_requested.emit()


func _on_quit() -> void:
	quit_requested.emit()