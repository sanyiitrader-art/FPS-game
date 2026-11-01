extends Control
## Owns the screen stack, the popup layer, toast messages, the safe-area margins and the
## Android back button. One instance exists, reachable through ScreenManager.instance
## (preload this script as a constant and read .instance).

const C = preload("res://game/autoload/config.gd")
const Widgets = preload("res://game/ui/widgets.gd")
const ThemeFactory = preload("res://game/ui/theme_factory.gd")

signal screen_changed(screen: Control)

static var instance: Control = null

var _stack: Array[Control] = []
var _popups: Array[Control] = []
var _screen_layer: Control
var _popup_layer: Control
var _toast_layer: Control
var _toast_tween: Tween


func _ready() -> void:
	instance = self
	process_mode = Node.PROCESS_MODE_ALWAYS
	theme = ThemeFactory.get_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_screen_layer = _make_layer()
	_popup_layer = _make_layer()
	_toast_layer = _make_layer()
	get_tree().root.size_changed.connect(_update_safe_area)
	_update_safe_area()


func _exit_tree() -> void:
	if instance == self:
		instance = null


func _make_layer() -> Control:
	var layer := Control.new()
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(layer)
	return layer


# ---- Safe area ------------------------------------------------------------------------

func _update_safe_area() -> void:
	var window_size := Vector2(DisplayServer.window_get_size())
	var logical := get_viewport_rect().size
	var safe := Rect2(DisplayServer.get_display_safe_area())
	var screen := Vector2(DisplayServer.screen_get_size())
	if window_size.x <= 0.0 or logical.x <= 0.0 or safe.size.x <= 0.0 or safe.size.y <= 0.0:
		Widgets.safe_margins = Vector4.ZERO
	else:
		var k := logical.x / window_size.x
		var left := clampf(safe.position.x * k, 0.0, 160.0)
		var top := clampf(safe.position.y * k, 0.0, 160.0)
		var right := clampf((screen.x - safe.end.x) * k, 0.0, 160.0)
		var bottom := clampf((screen.y - safe.end.y) * k, 0.0, 160.0)
		Widgets.safe_margins = Vector4(left, top, right, bottom)
	for node in get_tree().get_nodes_in_group("safe_wrapper"):
		var wrapper := node as MarginContainer
		if wrapper != null:
			Widgets.apply_safe_margins(wrapper)


# ---- Screens --------------------------------------------------------------------------

func current_screen() -> Control:
	return _stack.back() if not _stack.is_empty() else null


func depth() -> int:
	return _stack.size()


## Replaces every screen with a new one (the old ones fade out and are freed).
func show_screen(screen: Control) -> void:
	var old: Array[Control] = []
	old.assign(_stack)
	_stack.clear()
	_stack.append(screen)
	_attach(screen)
	for node in old:
		_retire(node)


## Puts a new screen on top; the previous one is kept so pop_screen() can return to it.
func push_screen(screen: Control) -> void:
	var previous: Control = null
	if not _stack.is_empty():
		previous = _stack.back()
	_stack.append(screen)
	_attach(screen)
	if previous != null:
		previous.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var tween := previous.create_tween()
		tween.tween_interval(C.TRANSITION)
		tween.tween_callback(func() -> void: previous.visible = false)


func pop_screen() -> void:
	if _stack.size() < 2:
		return
	var top: Control = _stack.pop_back()
	var below: Control = _stack.back()
	below.visible = true
	below.modulate.a = 1.0
	below.mouse_filter = Control.MOUSE_FILTER_STOP
	_retire(top)
	screen_changed.emit(below)


func pop_to_root() -> void:
	while _stack.size() > 1:
		pop_screen()


func _attach(screen: Control) -> void:
	screen.mouse_filter = Control.MOUSE_FILTER_STOP
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_screen_layer.add_child(screen)
	screen.modulate.a = 0.0
	var tween := screen.create_tween()
	tween.tween_property(screen, "modulate:a", 1.0, C.TRANSITION)
	screen_changed.emit(screen)


func _retire(node: Control) -> void:
	if not is_instance_valid(node):
		return
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tween := node.create_tween()
	tween.tween_property(node, "modulate:a", 0.0, C.TRANSITION * 0.7)
	tween.tween_callback(node.queue_free)


# ---- Popups ---------------------------------------------------------------------------

func has_popup() -> bool:
	return not _popups.is_empty()


## Opens a modal dialog above everything. Returns the wrapper to pass to close_popup().
## dismissible = false means the Android back button cannot close it.
## on_back (optional) is called instead when the back button is pressed.
func open_popup(dialog: Control, dismissible: bool = true, on_back: Callable = Callable()) -> Control:
	var wrapper := Control.new()
	wrapper.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	wrapper.mouse_filter = Control.MOUSE_FILTER_STOP

	var dim := ColorRect.new()
	dim.color = Color(0.04, 0.05, 0.06, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrapper.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrapper.add_child(center)
	center.add_child(dialog)

	if on_back.is_valid():
		wrapper.set_meta("on_back", on_back)
	if not dismissible:
		wrapper.set_meta("blocking", true)

	_popup_layer.add_child(wrapper)
	_popups.append(wrapper)
	wrapper.modulate.a = 0.0
	var tween := wrapper.create_tween()
	tween.tween_property(wrapper, "modulate:a", 1.0, 0.15)
	return wrapper


## Closes the given popup, or the top one when none is given.
func close_popup(wrapper: Control = null) -> void:
	var target: Control = wrapper
	if target == null and not _popups.is_empty():
		target = _popups.back()
	if target == null or not _popups.has(target):
		return
	_popups.erase(target)
	# Disabled nodes receive no input, so the buttons cannot be pressed twice while fading.
	target.process_mode = Node.PROCESS_MODE_DISABLED
	var tween := create_tween()
	tween.tween_property(target, "modulate:a", 0.0, 0.12)
	tween.tween_callback(target.queue_free)


func close_all_popups() -> void:
	var open: Array[Control] = []
	open.assign(_popups)
	for wrapper in open:
		close_popup(wrapper)


# ---- Toast ----------------------------------------------------------------------------

## A short message near the bottom of the screen that fades away by itself.
func show_toast(text: String, seconds: float = 2.2) -> void:
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	for child in _toast_layer.get_children():
		child.queue_free()

	var holder := VBoxContainer.new()
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.alignment = BoxContainer.ALIGNMENT_END
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(row)
	var card := Widgets.panel("DialogPanel")
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(Widgets.label(text, "", HORIZONTAL_ALIGNMENT_CENTER))
	row.add_child(card)
	holder.add_child(Widgets.gap(0.0, 48.0 + Widgets.safe_margins.w))
	_toast_layer.add_child(holder)

	holder.modulate.a = 0.0
	_toast_tween = create_tween()
	_toast_tween.tween_property(holder, "modulate:a", 1.0, 0.15)
	_toast_tween.tween_interval(seconds)
	_toast_tween.tween_property(holder, "modulate:a", 0.0, 0.3)
	_toast_tween.tween_callback(holder.queue_free)


# ---- Back button ------------------------------------------------------------------------

## Returns true if the back press was used. Popups first, then the top screen (a screen
## may define on_back()), then going back one screen.
func handle_back() -> bool:
	if not _popups.is_empty():
		var top: Control = _popups.back()
		if top.has_meta("on_back"):
			var action: Callable = top.get_meta("on_back")
			if action.is_valid():
				action.call()
		elif not bool(top.get_meta("blocking", false)):
			close_popup(top)
		return true
	if _stack.is_empty():
		return false
	var screen: Control = _stack.back()
	if screen.has_method("on_back"):
		screen.call("on_back")
		return true
	if _stack.size() > 1:
		pop_screen()
		return true
	return false


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		handle_back()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if handle_back():
			get_viewport().set_input_as_handled()