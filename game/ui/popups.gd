extends RefCounted
## Ready-made dialogs (all static). Every dialog opens through the ScreenManager.
##
## show_dialog() builds the standard layout: a title, an optional message and a row of
## buttons. Each button is a dictionary:
##   {"text": String, "variation": "" / "PrimaryButton" / "DangerButton",
##    "action": Callable (optional), "close": bool (default true)}

const C = preload("res://game/autoload/config.gd")
const Widgets = preload("res://game/ui/widgets.gd")
const Screens = preload("res://game/ui/screen_manager.gd")


static func show_dialog(title: String, message: String, buttons: Array,
		dismissible: bool = true, title_variation: String = "HeadingLabel") -> Control:
	var panel := PanelContainer.new()
	panel.theme_type_variation = "DialogPanel"
	panel.custom_minimum_size = Vector2(520.0, 0.0)

	var column := Widgets.vbox(18)
	panel.add_child(column)
	column.add_child(Widgets.label(title, title_variation, HORIZONTAL_ALIGNMENT_CENTER, true))
	if message != "":
		var body := Widgets.label(message, "", HORIZONTAL_ALIGNMENT_CENTER, true)
		body.add_theme_color_override("font_color", C.TEXT_2)
		column.add_child(body)

	var row := Widgets.hbox(12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(row)

	var wrapper: Control = Screens.instance.open_popup(panel, dismissible)
	for spec in buttons:
		row.add_child(_dialog_button(wrapper, spec))
	return wrapper


static func _dialog_button(wrapper: Control, spec: Dictionary) -> Button:
	var action: Callable = spec.get("action", Callable())
	var close_it: bool = bool(spec.get("close", true))
	var handler := func() -> void:
		if close_it:
			Screens.instance.close_popup(wrapper)
		if action.is_valid():
			action.call()
	return Widgets.button(String(spec["text"]), handler, String(spec.get("variation", "")), 180.0)


# ---- General -----------------------------------------------------------------------------

static func info(title: String, message: String = "", button_text: String = "CLOSE") -> Control:
	return show_dialog(title, message, [{"text": button_text, "variation": "PrimaryButton"}])


static func confirm(title: String, message: String, confirm_text: String, on_confirm: Callable,
		cancel_text: String = "CANCEL", danger: bool = false) -> Control:
	return show_dialog(title, message, [
		{"text": cancel_text},
		{"text": confirm_text, "variation": "DangerButton" if danger else "PrimaryButton",
			"action": on_confirm},
	])


# ---- Named dialogs from the design ---------------------------------------------------------

static func no_game_found() -> Control:
	return info("NO HOSTED GAME FOUND",
			"Make sure the host's hotspot is on and this phone is connected to it.")


static func open_hotspot() -> Control:
	return info("OPEN HOTSPOT",
			"Turn on this phone's hotspot (or join a shared Wi-Fi network) before hosting a game.")


## Shown to everyone when the host leaves or the network drops. Cannot be dismissed.
static func connection_lost(on_quit: Callable) -> Control:
	return show_dialog("CONNECTION LOST", "", [
		{"text": "QUIT", "variation": "PrimaryButton", "action": on_quit},
	], false, "WarningLabel")


static func confirm_quit_match(on_quit: Callable) -> Control:
	return confirm("ARE YOU SURE YOU WANT TO QUIT THIS MATCH?", "", "QUIT", on_quit, "CANCEL", true)


static func confirm_quit_app(on_quit: Callable) -> Control:
	return confirm("QUIT THE GAME?", "", "QUIT", on_quit, "CANCEL", true)