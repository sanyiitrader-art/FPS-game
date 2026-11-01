extends Control
## Settings screen (also reused later by the in-match settings overlay).
## Every control writes straight into Settings, which saves automatically.
##
## back_action: when set, the back arrow and the Android back button call it instead of
## going back one screen.

const C = preload("res://game/autoload/config.gd")
const Widgets = preload("res://game/ui/widgets.gd")
const Screens = preload("res://game/ui/screen_manager.gd")


## Draws the three crosshair shapes. Shared by the option buttons and the preview.
class ShapeDrawer extends RefCounted:
	static func draw_shape(canvas: CanvasItem, shape: int, center: Vector2, extent: float,
			color: Color, width: float) -> void:
		match shape:
			0: # plus
				var gap := extent * 0.3
				canvas.draw_line(center + Vector2(-extent, 0.0), center + Vector2(-gap, 0.0), color, width, true)
				canvas.draw_line(center + Vector2(gap, 0.0), center + Vector2(extent, 0.0), color, width, true)
				canvas.draw_line(center + Vector2(0.0, -extent), center + Vector2(0.0, -gap), color, width, true)
				canvas.draw_line(center + Vector2(0.0, gap), center + Vector2(0.0, extent), color, width, true)
			1: # circle
				canvas.draw_arc(center, extent, 0.0, TAU, 48, color, width, true)
			2: # square
				canvas.draw_rect(Rect2(center - Vector2(extent, extent), Vector2(extent, extent) * 2.0), color, false, width)


class ShapeButton extends Button:
	var shape: int = 0

	func _draw() -> void:
		var color := Color(0.082353, 0.098039, 0.117647) if button_pressed else Color(0.898039, 0.913725, 0.92549)
		ShapeDrawer.draw_shape(self, shape, size / 2.0, 12.0, color, 3.0)


class CrosshairPreview extends Control:
	var shape: int = 0
	var size_factor: float = 1.0

	func _init() -> void:
		custom_minimum_size = Vector2(112.0, 112.0)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.082353, 0.098039, 0.117647))
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.215686, 0.262745, 0.298039), false, 1.0)
		ShapeDrawer.draw_shape(self, shape, size / 2.0, 12.0 * size_factor, Color(0.384314, 0.713725, 0.647059), 2.0)


class BackButton extends Button:
	func _draw() -> void:
		var c := size / 2.0
		var color := Color(0.898039, 0.913725, 0.92549)
		draw_line(c + Vector2(10.0, 0.0), c + Vector2(-10.0, 0.0), color, 3.0, true)
		draw_line(c + Vector2(-10.0, 0.0), c + Vector2(-2.0, -8.0), color, 3.0, true)
		draw_line(c + Vector2(-10.0, 0.0), c + Vector2(-2.0, 8.0), color, 3.0, true)


var back_action: Callable = Callable()

var _preview: CrosshairPreview


## The square back-arrow button used in the top-left corner of full screens.
static func make_back_button(on_press: Callable) -> Button:
	var button := BackButton.new()
	button.custom_minimum_size = Vector2(C.BUTTON_HEIGHT, C.BUTTON_HEIGHT)
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(func() -> void:
		Audio.play_ui("back")
		if on_press.is_valid():
			on_press.call())
	return button


func _ready() -> void:
	var background := ColorRect.new()
	background.color = C.BG_MAIN
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	add_child(Widgets.safe_container(_build_ui(), 32))


func _build_ui() -> Control:
	var root := Widgets.vbox(12)

	var header := Widgets.hbox(16)
	header.add_child(make_back_button(on_back))
	var title := Widgets.label("SETTINGS", "HeadingLabel")
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(title)
	root.add_child(header)
	root.add_child(Widgets.hline())

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)

	var list := Widgets.vbox(10)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)

	_section(list, "AUDIO")
	list.add_child(Widgets.settings_row("Music",
			Widgets.toggle(Settings.get_bool(Settings.K_MUSIC),
					func(on: bool) -> void: Settings.set_value(Settings.K_MUSIC, on))))
	list.add_child(Widgets.settings_row("Sound effects",
			Widgets.toggle(Settings.get_bool(Settings.K_SFX),
					func(on: bool) -> void: Settings.set_value(Settings.K_SFX, on))))

	_section(list, "GRAPHICS")
	var gfx_buttons: Array = []
	for label_text in Settings.GRAPHICS_LABELS:
		var button := Button.new()
		button.text = String(label_text)
		gfx_buttons.append(button)
	list.add_child(Widgets.settings_row("Graphics quality",
			_segment_row(gfx_buttons, Settings.get_int(Settings.K_GFX), _on_graphics),
			"Lower settings run smoother on older phones"))

	_section(list, "CONTROLS")
	list.add_child(Widgets.settings_row("Camera sensitivity",
			_slider_with_value(Settings.SENS_MIN, Settings.SENS_MAX, 0.05,
					Settings.get_float(Settings.K_CAM), _on_camera_sens, _fmt_sens),
			"How fast the view turns when you drag"))
	list.add_child(Widgets.settings_row("Aim sensitivity",
			_slider_with_value(Settings.SENS_MIN, Settings.SENS_MAX, 0.05,
					Settings.get_float(Settings.K_AIM), _on_aim_sens, _fmt_sens),
			"View speed while holding the shoot button"))
	list.add_child(Widgets.settings_row("Vibration",
			Widgets.toggle(Settings.get_bool(Settings.K_VIB), _on_vibration)))

	_section(list, "CROSSHAIR")
	var shape_buttons: Array = []
	for shape_index in 3:
		var shape_button := ShapeButton.new()
		shape_button.shape = shape_index
		shape_buttons.append(shape_button)
	_preview = CrosshairPreview.new()
	_preview.shape = Settings.get_int(Settings.K_XH_SHAPE)
	_preview.size_factor = Settings.get_float(Settings.K_XH_SIZE)
	var shape_control := Widgets.hbox(14)
	shape_control.add_child(_segment_row(shape_buttons, Settings.get_int(Settings.K_XH_SHAPE), _on_shape))
	shape_control.add_child(_preview)
	list.add_child(Widgets.settings_row("Crosshair shape", shape_control))
	list.add_child(Widgets.settings_row("Crosshair size",
			_slider_with_value(Settings.XH_SIZE_MIN, Settings.XH_SIZE_MAX, 0.05,
					Settings.get_float(Settings.K_XH_SIZE), _on_xh_size, _fmt_percent)))

	list.add_child(Widgets.gap(0.0, 16.0))
	return root


func _section(list: VBoxContainer, title: String) -> void:
	list.add_child(Widgets.gap(0.0, 6.0))
	list.add_child(Widgets.label(title, "MutedLabel"))


# ---- Building blocks ---------------------------------------------------------------------

## A row of mutually exclusive buttons. on_select receives the chosen index.
func _segment_row(buttons: Array, selected: int, on_select: Callable) -> HBoxContainer:
	var group := ButtonGroup.new()
	var row := Widgets.hbox(6)
	for i in buttons.size():
		var button := buttons[i] as Button
		button.toggle_mode = true
		button.button_group = group
		button.focus_mode = Control.FOCUS_NONE
		button.theme_type_variation = "ToggleButton"
		button.custom_minimum_size = Vector2(112.0, C.TOUCH_MIN)
		button.button_pressed = (i == selected)
		button.toggled.connect(func(pressed: bool) -> void:
			if pressed:
				Audio.play_ui("toggle")
				on_select.call(i))
		row.add_child(button)
	return row


## Slider with a live value label. format turns the number into text.
func _slider_with_value(min_v: float, max_v: float, step: float, value: float,
		on_change: Callable, format: Callable) -> HBoxContainer:
	var row := Widgets.hbox(12)
	var value_label := Widgets.label(String(format.call(value)), "MutedLabel", HORIZONTAL_ALIGNMENT_RIGHT)
	value_label.custom_minimum_size = Vector2(76.0, 0.0)
	value_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var slider := Widgets.slider(min_v, max_v, step, value, func(v: float) -> void:
		value_label.text = String(format.call(v))
		on_change.call(v))
	row.add_child(slider)
	row.add_child(value_label)
	return row


func _fmt_sens(value: float) -> String:
	return "%.2fx" % value


func _fmt_percent(value: float) -> String:
	return "%d%%" % roundi(value * 100.0)


# ---- Handlers ---------------------------------------------------------------------------------

func _on_graphics(index: int) -> void:
	Settings.set_value(Settings.K_GFX, index)


func _on_camera_sens(value: float) -> void:
	Settings.set_value(Settings.K_CAM, value)


func _on_aim_sens(value: float) -> void:
	Settings.set_value(Settings.K_AIM, value)


func _on_vibration(on: bool) -> void:
	Settings.set_value(Settings.K_VIB, on)
	if on:
		Settings.vibrate(40)


func _on_shape(index: int) -> void:
	Settings.set_value(Settings.K_XH_SHAPE, index)
	_preview.shape = index
	_preview.queue_redraw()


func _on_xh_size(value: float) -> void:
	Settings.set_value(Settings.K_XH_SIZE, value)
	_preview.size_factor = value
	_preview.queue_redraw()


## Android back button and the back arrow.
func on_back() -> void:
	if back_action.is_valid():
		back_action.call()
	else:
		Screens.instance.pop_screen()