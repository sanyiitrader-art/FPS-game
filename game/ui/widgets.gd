extends RefCounted
## Helpers that build consistent Calm Tactical controls. Everything is static.

const C = preload("res://game/autoload/config.gd")

## Safe-area margins in UI units (left, top, right, bottom). Set by the ScreenManager.
static var safe_margins: Vector4 = Vector4.ZERO


# ---- Text and buttons -------------------------------------------------------------------

static func label(text: String, variation: String = "",
		align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT, wrap: bool = false) -> Label:
	var node := Label.new()
	node.text = text
	if variation != "":
		node.theme_type_variation = variation
	node.horizontal_alignment = align
	if wrap:
		node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node


## Standard button. variation: "", "PrimaryButton" or "DangerButton".
static func button(text: String, on_press: Callable, variation: String = "",
		min_width: float = 0.0) -> Button:
	var node := Button.new()
	node.text = text
	node.focus_mode = Control.FOCUS_NONE
	node.custom_minimum_size = Vector2(min_width, C.BUTTON_HEIGHT)
	if variation != "":
		node.theme_type_variation = variation
	node.pressed.connect(func() -> void:
		Audio.play_ui("click")
		if on_press.is_valid():
			on_press.call())
	return node


## ON/OFF switch. on_change receives the new bool.
static func toggle(initial: bool, on_change: Callable,
		on_text: String = "ON", off_text: String = "OFF") -> Button:
	var node := Button.new()
	node.toggle_mode = true
	node.focus_mode = Control.FOCUS_NONE
	node.theme_type_variation = "ToggleButton"
	node.custom_minimum_size = Vector2(110.0, C.TOUCH_MIN)
	node.button_pressed = initial
	node.text = on_text if initial else off_text
	node.toggled.connect(func(pressed: bool) -> void:
		node.text = on_text if pressed else off_text
		Audio.play_ui("toggle")
		if on_change.is_valid():
			on_change.call(pressed))
	return node


## Horizontal slider with a large touch area. on_change receives the new float.
static func slider(min_v: float, max_v: float, step: float, value: float,
		on_change: Callable) -> HSlider:
	var node := HSlider.new()
	node.min_value = min_v
	node.max_value = max_v
	node.step = step
	node.value = value
	node.custom_minimum_size = Vector2(360.0, C.TOUCH_MIN)
	node.size_flags_horizontal = Control.SIZE_FILL
	node.focus_mode = Control.FOCUS_NONE
	node.scrollable = false
	node.value_changed.connect(func(v: float) -> void:
		if on_change.is_valid():
			on_change.call(v))
	return node


# ---- Layout -------------------------------------------------------------------------------

static func hbox(separation: int = C.SPACE) -> HBoxContainer:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", separation)
	return box


static func vbox(separation: int = C.SPACE) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", separation)
	return box


## Empty control that pushes its neighbours apart (expand = true) or reserves space.
static func spacer(expand: bool = true) -> Control:
	var node := Control.new()
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if expand:
		node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		node.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return node


static func gap(width: float, height: float) -> Control:
	var node := Control.new()
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.custom_minimum_size = Vector2(width, height)
	return node


static func hline() -> ColorRect:
	var line := ColorRect.new()
	line.color = C.BORDER
	line.custom_minimum_size = Vector2(0.0, 1.0)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return line


static func panel(variation: String = "") -> PanelContainer:
	var node := PanelContainer.new()
	if variation != "":
		node.theme_type_variation = variation
	return node


## One settings line: title (and optional hint) on the left, the control on the right.
static func settings_row(title: String, control: Control, hint: String = "") -> Control:
	var card := panel("DarkPanel")
	var row := hbox(16)
	card.add_child(row)
	var texts := vbox(2)
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	texts.add_child(label(title))
	if hint != "":
		texts.add_child(label(hint, "MutedLabel"))
	row.add_child(texts)
	control.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(control)
	return card


# ---- Safe area -----------------------------------------------------------------------------

## Wraps content in a full-screen margin container that keeps it clear of notches and
## rounded corners. extra = additional padding in UI units.
static func safe_container(content: Control, extra: int = 24) -> MarginContainer:
	var wrapper := MarginContainer.new()
	wrapper.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	wrapper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrapper.set_meta("safe_extra", extra)
	wrapper.add_to_group("safe_wrapper")
	wrapper.add_child(content)
	apply_safe_margins(wrapper)
	return wrapper


static func apply_safe_margins(wrapper: MarginContainer) -> void:
	var extra := int(wrapper.get_meta("safe_extra", 24))
	wrapper.add_theme_constant_override("margin_left", extra + int(safe_margins.x))
	wrapper.add_theme_constant_override("margin_top", extra + int(safe_margins.y))
	wrapper.add_theme_constant_override("margin_right", extra + int(safe_margins.z))
	wrapper.add_theme_constant_override("margin_bottom", extra + int(safe_margins.w))


# ---- Animation -----------------------------------------------------------------------------

static func fade_in(node: CanvasItem, duration: float = C.TRANSITION) -> void:
	node.modulate.a = 0.0
	var tween := node.create_tween()
	tween.tween_property(node, "modulate:a", 1.0, duration)


# ---- Gradient overlays ----------------------------------------------------------------------

static func _overlay(gradient: Gradient, fill: int, from: Vector2, to: Vector2) -> TextureRect:
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill = fill as GradientTexture2D.Fill
	tex.fill_from = from
	tex.fill_to = to
	tex.width = 256
	tex.height = 256
	var rect := TextureRect.new()
	rect.texture = tex
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


static func _gradient(from_color: Color, to_color: Color, start: float = 0.0) -> Gradient:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([start, 1.0])
	g.colors = PackedColorArray([from_color, to_color])
	return g


## Dark edges around the screen, clear in the middle.
static func vignette() -> TextureRect:
	return _overlay(_gradient(Color(C.BG_MAIN, 0.0), Color(C.BG_MAIN, 0.92), 0.45),
			GradientTexture2D.FILL_RADIAL, Vector2(0.5, 0.5), Vector2(1.0, 0.5))


## Darkens the lower part of the screen so text stays readable.
static func bottom_fade(strength: float = 0.95) -> TextureRect:
	return _overlay(_gradient(Color(C.BG_MAIN, 0.0), Color(C.BG_MAIN, strength)),
			GradientTexture2D.FILL_LINEAR, Vector2(0.0, 0.5), Vector2(0.0, 1.0))


## Darkens the left side (menu column) and fades out towards the right.
static func side_fade(strength: float = 0.9) -> TextureRect:
	return _overlay(_gradient(Color(C.BG_MAIN, strength), Color(C.BG_MAIN, 0.0)),
			GradientTexture2D.FILL_LINEAR, Vector2(0.0, 0.5), Vector2(0.6, 0.5))


# ---- 3D stage -------------------------------------------------------------------------------

## A dark, softly lit 3D scene rendered inside its own viewport (menu and loading screens).
static func stage(content: Node3D, cam_pos: Vector3, cam_target: Vector3,
		fov: float = 40.0) -> SubViewportContainer:
	var container := SubViewportContainer.new()
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var viewport := SubViewport.new()
	viewport.own_world_3d = true
	viewport.gui_disable_input = true
	viewport.msaa_3d = Viewport.MSAA_DISABLED
	viewport.scaling_3d_scale = float(Settings.graphics_profile()["render_scale"])
	container.add_child(viewport)

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = C.BG_MAIN
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.62, 0.68)
	env.ambient_light_energy = 0.7
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	viewport.add_child(world_env)

	var key := DirectionalLight3D.new()
	key.light_color = Color(1.0, 0.95, 0.88)
	key.light_energy = 1.1
	key.rotation_degrees = Vector3(-35.0, 35.0, 0.0)
	viewport.add_child(key)

	var rim := DirectionalLight3D.new()
	rim.light_color = C.ACCENT_2
	rim.light_energy = 0.9
	rim.rotation_degrees = Vector3(-15.0, 165.0, 0.0)
	viewport.add_child(rim)

	var cam := Camera3D.new()
	cam.fov = fov
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	cam.transform = Transform3D(Basis.looking_at((cam_target - cam_pos).normalized(), Vector3.UP), cam_pos)
	viewport.add_child(cam)
	cam.current = true

	viewport.add_child(content)
	return container


static func ground_plane(extent: float = 16.0) -> MeshInstance3D:
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(extent, extent)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.10, 0.12, 0.14)
	material.roughness = 1.0
	mesh.material = material
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	return instance