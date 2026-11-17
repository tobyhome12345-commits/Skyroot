extends CanvasLayer
## Destination menu (autoload "TravelMenu"), opened from a launch point.
## Lists every island in data/islands.json. Known islands can be picked;
## unknown ones are greyed out as "Unknown"; the one you're on is greyed out
## with a "You are here" tag.
## Arrows / W S move, E / Enter / Space or a click pick, Esc closes.

const CREAM := Color(0.99, 0.95, 0.86)
const BORDER := Color(0.55, 0.36, 0.22)
const INK := Color(0.29, 0.19, 0.13)
const TAG := Color(0.85, 0.5, 0.3)
const GREY_BG := Color(0.88, 0.85, 0.8)
const GREY_INK := Color(0.6, 0.56, 0.52)

const PANEL_WIDTH := 560.0

var _root: Control
var _list: VBoxContainer
var _buttons: Array[Button] = []
var _open := false


func _ready() -> void:
	layer = 55
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_root.visible = false


func is_open() -> bool:
	return _open


## The menu's entries, for tests: [{id, name, enabled, text}, ...].
func entries() -> Array:
	var out := []
	for b in _buttons:
		var tag := b.get_node_or_null("Tag") as Label
		out.append({"id": b.get_meta("id"), "name": b.get_meta("name"), "enabled": not b.disabled,
				"text": b.text, "tag": tag.text if tag else "", "here": b.get_meta("here", false)})
	return out


func open(from_island: String) -> void:
	if _open or Game.input_locked:
		return
	for b in _buttons:
		b.queue_free()
	_buttons.clear()
	for island: Dictionary in Game.islands():
		var here: bool = island["id"] == from_island
		var known: bool = island.get("known", false) and island.has("scene")
		var b := _make_button(island["name"], known and not here, "You are here" if here else ("" if known else "Unknown"), here)
		b.set_meta("id", island["id"])
		b.set_meta("name", island["name"])
		b.set_meta("here", here)
		if known and not here:
			b.pressed.connect(_choose.bind(island["id"]))
		_list.add_child(b)
		_buttons.append(b)
	_open = true
	Game.input_locked = true
	_root.visible = true
	for b in _buttons:
		if not b.disabled:
			b.grab_focus()
			break


func close() -> void:
	if not _open:
		return
	_open = false
	_root.visible = false
	var focus := _root.get_viewport().gui_get_focus_owner()
	if focus:
		focus.release_focus()
	Game.input_locked = false


## Picks the entry with this id (as if clicked). Used by E and by tests.
func choose(island_id: String) -> bool:
	for b in _buttons:
		if b.get_meta("id") == island_id and not b.disabled:
			b.pressed.emit()
			return true
	return false


func _choose(island_id: String) -> void:
	close()
	Game.glide_to(island_id)


func _input(event: InputEvent) -> void:
	if not _open:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()
	elif event.is_action_pressed(Game.INTERACT) and not event.is_echo():
		get_viewport().set_input_as_handled()
		var f := get_viewport().gui_get_focus_owner()
		if f is Button and not (f as Button).disabled:
			(f as Button).pressed.emit()
	elif event.is_action_pressed("move_up") or event.is_action_pressed("move_down"):
		if event is InputEventKey and (event as InputEventKey).physical_keycode in [KEY_W, KEY_S]:
			get_viewport().set_input_as_handled()
			_move_focus(-1 if event.is_action_pressed("move_up") else 1)


func _move_focus(step: int) -> void:
	var enabled := _buttons.filter(func(b: Button) -> bool: return not b.disabled)
	if enabled.is_empty():
		return
	var i := enabled.find(get_viewport().gui_get_focus_owner())
	i = wrapi(i + step, 0, enabled.size())
	(enabled[i] as Button).grab_focus()


# ---------------------------------------------------------------- layout

func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0.1, 0.06, 0.04, 0.35)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(PANEL_WIDTH, 0.0)
	var box := StyleBoxFlat.new()
	box.bg_color = CREAM
	box.border_color = BORDER
	box.set_border_width_all(6)
	box.set_corner_radius_all(28)
	box.shadow_color = Color(0.0, 0.0, 0.0, 0.25)
	box.shadow_size = 14
	box.shadow_offset = Vector2(0, 6)
	box.content_margin_left = 40
	box.content_margin_right = 40
	box.content_margin_top = 30
	box.content_margin_bottom = 26
	panel.add_theme_stylebox_override("panel", box)
	center.add_child(panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	panel.add_child(col)
	var title := Label.new()
	title.text = "Where to?"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 44)
	title.add_theme_color_override("font_color", TAG)
	title.add_theme_color_override("font_outline_color", BORDER)
	title.add_theme_constant_override("outline_size", 8)
	col.add_child(title)
	var sub := Label.new()
	sub.text = "Pick an island to glide to"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 24)
	sub.add_theme_color_override("font_color", INK)
	col.add_child(sub)

	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 10)
	col.add_child(_list)

	var hint := Label.new()
	hint.text = "E / Enter  pick      Esc  close"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 20)
	hint.add_theme_color_override("font_color", GREY_INK)
	col.add_child(hint)


## One menu entry. `tag` is the small label on the right ("Unknown", or the
## orange "You are here" pill on the current island).
func _make_button(island_name: String, enabled: bool, tag := "", here := false) -> Button:
	var b := Button.new()
	b.text = island_name
	b.disabled = not enabled
	b.custom_minimum_size = Vector2(0.0, 64.0)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.focus_mode = Control.FOCUS_ALL if enabled else Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 32)
	b.add_theme_color_override("font_color", INK)
	b.add_theme_color_override("font_hover_color", CREAM)
	b.add_theme_color_override("font_focus_color", CREAM)
	b.add_theme_color_override("font_pressed_color", CREAM)
	b.add_theme_color_override("font_hover_pressed_color", CREAM)
	b.add_theme_color_override("font_disabled_color", GREY_INK)
	b.add_theme_stylebox_override("normal", _style(CREAM, BORDER))
	b.add_theme_stylebox_override("hover", _style(TAG, BORDER))
	b.add_theme_stylebox_override("focus", _style(TAG, BORDER))
	b.add_theme_stylebox_override("pressed", _style(TAG.darkened(0.1), BORDER))
	b.add_theme_stylebox_override("disabled", _style(GREY_BG, GREY_INK))
	if tag != "":
		var label := Label.new()
		label.name = "Tag"
		label.text = tag
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
		label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		label.grow_vertical = Control.GROW_DIRECTION_BOTH
		label.offset_right = -18.0
		label.offset_left = -18.0
		if here:
			# A small orange pill, so you can see at a glance where you are.
			label.add_theme_font_size_override("font_size", 20)
			label.add_theme_color_override("font_color", CREAM)
			var pill := StyleBoxFlat.new()
			pill.bg_color = TAG
			pill.set_corner_radius_all(14)
			pill.content_margin_left = 14
			pill.content_margin_right = 14
			pill.content_margin_top = 3
			pill.content_margin_bottom = 4
			label.add_theme_stylebox_override("normal", pill)
		else:
			label.add_theme_font_size_override("font_size", 24)
			label.add_theme_color_override("font_color", GREY_INK)
		b.add_child(label)
	return b


func _style(bg: Color, border: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(4)
	s.set_corner_radius_all(18)
	s.content_margin_left = 24
	s.content_margin_right = 24
	return s
