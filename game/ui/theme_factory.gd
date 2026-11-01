extends RefCounted
## Builds the Calm Tactical theme: flat dark panels, thin borders and one teal accent.
## Type variations (set with theme_type_variation) are listed in _build().

const C = preload("res://game/autoload/config.gd")

static var _theme: Theme = null


static func get_theme() -> Theme:
	if _theme == null:
		_theme = _build()
	return _theme


static func box(bg: Color, border: Color = C.BORDER, radius: int = C.RADIUS,
		border_width: int = C.BORDER_WIDTH, pad_h: float = 16.0, pad_v: float = 8.0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_width)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = pad_h
	sb.content_margin_right = pad_h
	sb.content_margin_top = pad_v
	sb.content_margin_bottom = pad_v
	return sb


static func _build() -> Theme:
	var t := Theme.new()
	t.default_font_size = C.FONT_BODY

	# Labels: Label, TitleLabel, HeadingLabel, AccentLabel, WarningLabel, DangerLabel,
	# MutedLabel, SmallLabel
	t.set_font_size("font_size", "Label", C.FONT_BODY)
	t.set_color("font_color", "Label", C.TEXT)
	_label_variation(t, "TitleLabel", C.FONT_TITLE, C.TEXT)
	_label_variation(t, "HeadingLabel", C.FONT_HEADING, C.TEXT)
	_label_variation(t, "AccentLabel", C.FONT_HEADING, C.ACCENT)
	_label_variation(t, "WarningLabel", C.FONT_HEADING, C.WARNING)
	_label_variation(t, "DangerLabel", C.FONT_HEADING, C.ENEMY)
	_label_variation(t, "MutedLabel", C.FONT_SMALL, C.TEXT_2)
	_label_variation(t, "SmallLabel", C.FONT_SMALL, C.TEXT)

	# Buttons: Button, PrimaryButton, DangerButton, ToggleButton
	_button_styles(t, "Button", C.PANEL, C.TEXT, C.BORDER)
	t.set_type_variation("PrimaryButton", "Button")
	_button_styles(t, "PrimaryButton", C.ACCENT, C.BG_MAIN, C.ACCENT)
	t.set_type_variation("DangerButton", "Button")
	_button_styles(t, "DangerButton", C.ENEMY.darkened(0.3), C.TEXT, C.ENEMY)
	t.set_type_variation("ToggleButton", "Button")
	_toggle_styles(t)

	# Panels: PanelContainer, DarkPanel, DialogPanel, SelectedPanel
	t.set_stylebox("panel", "PanelContainer", box(C.PANEL, C.BORDER, C.RADIUS, 1, 16.0, 14.0))
	t.set_stylebox("panel", "Panel", box(C.PANEL, C.BORDER, C.RADIUS, 1, 0.0, 0.0))
	t.set_type_variation("DarkPanel", "PanelContainer")
	t.set_stylebox("panel", "DarkPanel", box(C.BG_SECOND, C.BORDER, C.RADIUS, 1, 16.0, 12.0))
	t.set_type_variation("SelectedPanel", "PanelContainer")
	t.set_stylebox("panel", "SelectedPanel", box(C.PANEL, C.ACCENT, C.RADIUS, 2, 16.0, 14.0))
	t.set_type_variation("DialogPanel", "PanelContainer")
	var dialog := box(C.PANEL, C.BORDER, 8, 1, 28.0, 24.0)
	dialog.shadow_size = 14
	dialog.shadow_color = Color(0.0, 0.0, 0.0, 0.45)
	dialog.shadow_offset = Vector2(0.0, 5.0)
	t.set_stylebox("panel", "DialogPanel", dialog)

	# Text entry
	t.set_stylebox("normal", "LineEdit", box(C.BG_SECOND, C.BORDER, C.RADIUS, 1, 14.0, 10.0))
	t.set_stylebox("focus", "LineEdit", box(C.BG_SECOND, C.ACCENT, C.RADIUS, 1, 14.0, 10.0))
	t.set_stylebox("read_only", "LineEdit", box(C.BG_SECOND, C.BORDER, C.RADIUS, 1, 14.0, 10.0))
	t.set_color("font_color", "LineEdit", C.TEXT)
	t.set_color("font_uneditable_color", "LineEdit", C.TEXT_2)
	t.set_color("font_placeholder_color", "LineEdit", C.TEXT_2)
	t.set_color("caret_color", "LineEdit", C.ACCENT)
	t.set_color("selection_color", "LineEdit", Color(C.ACCENT, 0.35))
	t.set_font_size("font_size", "LineEdit", C.FONT_BODY)
	t.set_constant("caret_width", "LineEdit", 2)

	# Sliders (large round handle so a thumb can grab it)
	t.set_stylebox("slider", "HSlider", box(C.BG_SECOND, C.BORDER, 4, 1, 0.0, 3.0))
	t.set_stylebox("grabber_area", "HSlider", box(C.ACCENT, C.ACCENT, 4, 0, 0.0, 3.0))
	t.set_stylebox("grabber_area_highlight", "HSlider",
			box(C.ACCENT.lightened(0.12), C.ACCENT, 4, 0, 0.0, 3.0))
	t.set_icon("grabber", "HSlider", _circle_texture(32, C.TEXT, C.ACCENT))
	t.set_icon("grabber_highlight", "HSlider", _circle_texture(32, C.TEXT, C.ACCENT.lightened(0.2)))
	t.set_icon("grabber_disabled", "HSlider", _circle_texture(32, C.TEXT_2, C.BORDER))

	# Scroll bars (thin)
	for bar in ["VScrollBar", "HScrollBar"]:
		t.set_stylebox("scroll", bar, box(C.BG_SECOND, C.BG_SECOND, 4, 0, 4.0, 4.0))
		t.set_stylebox("grabber", bar, box(C.BORDER, C.BORDER, 4, 0, 4.0, 4.0))
		t.set_stylebox("grabber_highlight", bar, box(C.ACCENT_2, C.ACCENT_2, 4, 0, 4.0, 4.0))
		t.set_stylebox("grabber_pressed", bar, box(C.ACCENT, C.ACCENT, 4, 0, 4.0, 4.0))

	return t


static func _label_variation(t: Theme, type_name: String, size: int, color: Color) -> void:
	t.set_type_variation(type_name, "Label")
	t.set_font_size("font_size", type_name, size)
	t.set_color("font_color", type_name, color)


static func _button_styles(t: Theme, type_name: String, bg: Color, fg: Color, border: Color) -> void:
	var dim := C.TEXT_2.darkened(0.25)
	t.set_stylebox("normal", type_name, box(bg, border))
	t.set_stylebox("hover", type_name, box(bg.lightened(0.10), border.lightened(0.10)))
	t.set_stylebox("pressed", type_name, box(bg.darkened(0.15), border))
	t.set_stylebox("hover_pressed", type_name, box(bg.darkened(0.10), border))
	t.set_stylebox("disabled", type_name, box(C.BG_SECOND, C.BORDER))
	t.set_stylebox("focus", type_name, StyleBoxEmpty.new())
	t.set_color("font_color", type_name, fg)
	t.set_color("font_hover_color", type_name, fg)
	t.set_color("font_pressed_color", type_name, fg)
	t.set_color("font_hover_pressed_color", type_name, fg)
	t.set_color("font_focus_color", type_name, fg)
	t.set_color("font_disabled_color", type_name, dim)
	t.set_font_size("font_size", type_name, C.FONT_BODY)
	t.set_constant("h_separation", type_name, 10)


static func _toggle_styles(t: Theme) -> void:
	var type_name := "ToggleButton"
	t.set_stylebox("normal", type_name, box(C.PANEL, C.BORDER, C.RADIUS, 1, 12.0, 8.0))
	t.set_stylebox("hover", type_name, box(C.PANEL.lightened(0.10), C.BORDER.lightened(0.10), C.RADIUS, 1, 12.0, 8.0))
	t.set_stylebox("pressed", type_name, box(C.ACCENT, C.ACCENT, C.RADIUS, 1, 12.0, 8.0))
	t.set_stylebox("hover_pressed", type_name, box(C.ACCENT.lightened(0.10), C.ACCENT, C.RADIUS, 1, 12.0, 8.0))
	t.set_stylebox("disabled", type_name, box(C.BG_SECOND, C.BORDER, C.RADIUS, 1, 12.0, 8.0))
	t.set_stylebox("focus", type_name, StyleBoxEmpty.new())
	t.set_color("font_color", type_name, C.TEXT_2)
	t.set_color("font_hover_color", type_name, C.TEXT)
	t.set_color("font_pressed_color", type_name, C.BG_MAIN)
	t.set_color("font_hover_pressed_color", type_name, C.BG_MAIN)
	t.set_color("font_disabled_color", type_name, C.TEXT_2.darkened(0.25))
	t.set_font_size("font_size", type_name, C.FONT_SMALL + 2)


## Round slider handle drawn once into a small texture (soft 1 px edge).
static func _circle_texture(diameter: int, fill: Color, ring: Color) -> ImageTexture:
	var img := Image.create(diameter, diameter, false, Image.FORMAT_RGBA8)
	var center := (diameter - 1) / 2.0
	var radius := diameter / 2.0
	for y in diameter:
		for x in diameter:
			var dist := Vector2(x - center, y - center).length()
			var color: Color = ring if dist > radius - 4.0 else fill
			color.a = clampf(radius - dist, 0.0, 1.0)
			img.set_pixel(x, y, color)
	return ImageTexture.create_from_image(img)