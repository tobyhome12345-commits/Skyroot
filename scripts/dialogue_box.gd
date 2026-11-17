extends CanvasLayer
## The dialogue box (autoload "DialogueBox"): a cozy panel at the bottom of
## the screen with the speaker's name and the text typed out letter by letter.
## E finishes the typing, then goes to the next page, then closes the box.
## The player can't move while it's open.

const CHARS_PER_SECOND := 45.0
const PANEL_WIDTH := 1240.0
const PANEL_HEIGHT := 230.0
const BOTTOM_MARGIN := 48.0

const CREAM := Color(0.99, 0.95, 0.86)
const BORDER := Color(0.55, 0.36, 0.22)
const INK := Color(0.29, 0.19, 0.13)
const TAG := Color(0.85, 0.5, 0.3)

signal closed

var _panel: PanelContainer
var _name_tag: PanelContainer
var _name_label: Label
var _text: Label
var _more: Label
var _pages: Array = []
var _page := 0
var _shown := 0.0
var _open := false
var _blink := 0.0
## Was the player already locked (e.g. by a cutscene) when the box opened?
var _was_locked := false


func _ready() -> void:
	layer = 50  # above the game and tilt-shift, below the fade
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_set_visible(false)


func is_open() -> bool:
	return _open


## Current page text and speaker, for tests.
func current_text() -> String:
	return _text.text


func current_name() -> String:
	return _name_label.text


func is_typing() -> bool:
	return _open and _text.visible_characters < _text.get_total_character_count()


## Opens the box: `pages` is an array of strings shown one after another.
func open(speaker: String, pages: Array) -> void:
	if pages.is_empty():
		return
	_pages = pages
	_page = 0
	_name_label.text = speaker
	_was_locked = Game.input_locked and not _open
	_open = true
	Game.input_locked = true
	_set_visible(true)
	_show_page()


func _show_page() -> void:
	_text.text = _pages[_page]
	_text.visible_characters = 0
	_shown = 0.0
	_more.visible = false


func _process(delta: float) -> void:
	if not _open:
		return
	var total := _text.get_total_character_count()
	if _text.visible_characters < total:
		_shown += CHARS_PER_SECOND * delta
		_text.visible_characters = mini(int(_shown), total)
	else:
		_blink += delta
		_more.visible = fmod(_blink, 1.0) < 0.6


func _unhandled_input(event: InputEvent) -> void:
	if not _open:
		return
	if event.is_action_pressed(Game.INTERACT) and not event.is_echo():
		get_viewport().set_input_as_handled()
		advance()


## What pressing E does: finish typing, else next page, else close.
func advance() -> void:
	if is_typing():
		_text.visible_characters = _text.get_total_character_count()
		_shown = float(_text.visible_characters)
		return
	_page += 1
	if _page < _pages.size():
		_show_page()
	else:
		_close()


func _close() -> void:
	_open = false
	_set_visible(false)
	Game.input_locked = _was_locked
	closed.emit()


## Closes the box straight away (e.g. when a cutscene is skipped).
func close_now() -> void:
	if _open:
		_close()


func _set_visible(on: bool) -> void:
	_panel.visible = on
	_name_tag.visible = on


# ---------------------------------------------------------------- layout

func _build() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_panel = PanelContainer.new()
	_panel.name = "Panel"
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.anchor_left = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_top = 1.0
	_panel.anchor_bottom = 1.0
	_panel.offset_left = -PANEL_WIDTH / 2.0
	_panel.offset_right = PANEL_WIDTH / 2.0
	_panel.offset_top = -PANEL_HEIGHT - BOTTOM_MARGIN
	_panel.offset_bottom = -BOTTOM_MARGIN
	var box := StyleBoxFlat.new()
	box.bg_color = CREAM
	box.border_color = BORDER
	box.set_border_width_all(6)
	box.set_corner_radius_all(26)
	box.shadow_color = Color(0.0, 0.0, 0.0, 0.25)
	box.shadow_size = 12
	box.shadow_offset = Vector2(0, 6)
	box.content_margin_left = 44
	box.content_margin_right = 44
	box.content_margin_top = 40
	box.content_margin_bottom = 28
	_panel.add_theme_stylebox_override("panel", box)
	root.add_child(_panel)

	_text = Label.new()
	_text.name = "Text"
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_text.add_theme_font_size_override("font_size", 34)
	_text.add_theme_color_override("font_color", INK)
	_text.add_theme_constant_override("line_spacing", 6)
	_panel.add_child(_text)

	_more = Label.new()
	_more.name = "More"
	_more.text = "▼"
	_more.add_theme_font_size_override("font_size", 26)
	_more.add_theme_color_override("font_color", BORDER)
	_more.size_flags_horizontal = Control.SIZE_SHRINK_END
	_more.size_flags_vertical = Control.SIZE_SHRINK_END
	_panel.add_child(_more)

	_name_tag = PanelContainer.new()
	_name_tag.name = "NameTag"
	_name_tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_name_tag.anchor_left = 0.5
	_name_tag.anchor_right = 0.5
	_name_tag.anchor_top = 1.0
	_name_tag.anchor_bottom = 1.0
	# Zero-size anchor point at the panel's top-left; the tag grows right and
	# down just enough to fit the name.
	_name_tag.offset_left = -PANEL_WIDTH / 2.0 + 36.0
	_name_tag.offset_right = _name_tag.offset_left
	_name_tag.offset_top = -PANEL_HEIGHT - BOTTOM_MARGIN - 30.0
	_name_tag.offset_bottom = _name_tag.offset_top
	_name_tag.grow_horizontal = Control.GROW_DIRECTION_END
	_name_tag.grow_vertical = Control.GROW_DIRECTION_END
	var tag := StyleBoxFlat.new()
	tag.bg_color = TAG
	tag.border_color = BORDER
	tag.set_border_width_all(5)
	tag.set_corner_radius_all(18)
	tag.content_margin_left = 26
	tag.content_margin_right = 26
	tag.content_margin_top = 6
	tag.content_margin_bottom = 8
	_name_tag.add_theme_stylebox_override("panel", tag)
	root.add_child(_name_tag)

	_name_label = Label.new()
	_name_label.name = "Name"
	_name_label.add_theme_font_size_override("font_size", 30)
	_name_label.add_theme_color_override("font_color", CREAM)
	_name_label.add_theme_color_override("font_outline_color", BORDER)
	_name_label.add_theme_constant_override("outline_size", 6)
	_name_tag.add_child(_name_label)
