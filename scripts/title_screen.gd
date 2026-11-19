extends Node3D
## The title screen (the project's main scene). Behind the menu: the real
## Great Tree island, display only (no player, no collision), with the
## distant islands (sky map), clouds and haze, in warm golden-hour light.
## A camera drifts slowly round it on a smooth loop, pushing in and out a
## little and swaying gently; leaves and light dust float past the lens.
## In front: "Skyroot", a subtitle and three buttons (Play, Settings,
## Quit). Mouse, arrow keys or W / S, Enter or E, and a gamepad all work.
## Play fades to black and starts the game exactly as before.
##
## Debug: skip straight to the game with the launch argument
## `-- --skip-title`, or the project setting application/run/skip_title.

const GAME_SCENE := "res://scenes/pebblenook.tscn"
const TITLE := "Skyroot"
const SUBTITLE := "Bring joy back to the Great Tree"
const CREAM := Color(1.0, 0.93, 0.76)
const GOLD := Color(1.0, 0.82, 0.48)
const INK := Color(0.24, 0.13, 0.06)
## Camera loop: seconds per full circle, orbit radius (pushes in by
## PUSH_IN at the middle of the loop), height and where it looks.
const LOOP_TIME := 160.0
const ORBIT := 84.0
const PUSH_IN := 10.0
const HEIGHT := 26.0
const LOOK_HEIGHT := 46.0
const FOV := 60.0

var island: Node3D
var camera: Camera3D
var menu: VBoxContainer
var settings: PanelContainer
var fullscreen_toggle: CheckButton
var title_letters: Array[Label] = []
var subtitle: Label
var buttons: Array[Button] = []
var _time := 0.0
var _busy := false


## The launch argument or project setting that skips the title screen.
static func skip_requested(args: PackedStringArray) -> bool:
	return "--skip-title" in args or bool(ProjectSettings.get_setting("application/run/skip_title", false))


func _ready() -> void:
	if skip_requested(OS.get_cmdline_user_args()):
		get_tree().change_scene_to_file.call_deferred(GAME_SCENE)
		return
	_build_world()
	_build_camera()
	_build_ui()
	_fade_in()


func _process(delta: float) -> void:
	_time += delta
	if camera:
		camera.transform = camera_transform(_time)
	for i in title_letters.size():
		var l := title_letters[i]
		l.position.y = l.get_meta("base_y") + sin(_time * 0.9 + i * 0.55) * 5.0
		l.rotation = deg_to_rad(l.get_meta("tilt") + sin(_time * 0.7 + i) * 0.8)
	if subtitle:
		subtitle.position.y = subtitle.get_meta("base_y") + sin(_time * 0.9 + 2.0) * 2.5
	if fullscreen_toggle:
		fullscreen_toggle.set_pressed_no_signal(WindowControls.is_fullscreen())


# ---------------------------------------------------------------- world

func _build_world() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := PanoramaSkyMaterial.new()
	sky_mat.panorama = preload("res://Assets/Skyboxes/Skyboxes/skybox-day.png")
	sky_mat.energy_multiplier = 1.25
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.2
	env.tonemap_white = 6.0
	env.glow_enabled = true
	env.glow_intensity = 0.35
	env.glow_bloom = 0.1
	env.ssao_enabled = true
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = Color(0.98, 0.86, 0.68)
	env.fog_density = 0.6
	env.fog_depth_curve = 1.4
	env.fog_depth_begin = 160.0
	env.fog_depth_end = 1100.0
	env.fog_sky_affect = 0.0
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.08
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = env
	add_child(we)
	# Golden hour: a low, warm sun.
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-17.0, -125.0, 0.0)
	sun.light_color = Color(1.0, 0.76, 0.5)
	sun.light_energy = 1.35
	sun.light_angular_distance = 4.0
	sun.shadow_enabled = true
	sun.shadow_blur = 2.0
	sun.directional_shadow_max_distance = 220.0
	add_child(sun)
	# The real Great Tree island, display only.
	island = Node3D.new()
	island.name = "Island"
	island.set_script(preload("res://scripts/great_tree_island.gd"))
	island.set("island_id", "great_tree")
	island.set("display_only", true)
	add_child(island)
	var clouds := Node3D.new()
	clouds.name = "Clouds"
	clouds.set_script(preload("res://scripts/clouds.gd"))
	clouds.set("seed_value", 23)
	add_child(clouds)


## Where the backdrop camera looks from (world space): round the tree's
## trunk, pushed in a little in the middle of each loop.
func _tree_centre() -> Vector3:
	var tree = island.get("tree") if island else null
	return (tree as Node3D).global_position if tree else Vector3.ZERO


## The camera at time t: one slow circle per LOOP_TIME, a gentle push in and
## out, a soft rise and fall, and a little sway. Smooth and seamless: t and
## t + LOOP_TIME give the same view.
func camera_transform(t: float) -> Transform3D:
	var k := TAU * t / LOOP_TIME
	var centre := _tree_centre()
	var radius := ORBIT - PUSH_IN * 0.5 * (1.0 - cos(k))
	var pos := centre + Vector3(sin(k) * radius, HEIGHT + 3.0 * sin(2.0 * k), cos(k) * radius)
	var look := centre + Vector3(sin(3.0 * k) * 2.0, LOOK_HEIGHT + 2.0 * sin(2.0 * k + 1.0), cos(3.0 * k) * 2.0)
	var xf := Transform3D(Basis(), pos).looking_at(look, Vector3.UP)
	return xf.rotated_local(Vector3.FORWARD, deg_to_rad(0.8 * sin(5.0 * k)))


func _build_camera() -> void:
	camera = Camera3D.new()
	camera.name = "Camera"
	camera.fov = FOV
	camera.far = 4000.0
	add_child(camera)
	camera.current = true
	camera.transform = camera_transform(0.0)
	_add_particles()


## A few leaves and soft motes of light drifting past, just in front of
## the lens (they move with the camera). Small counts, no shadows.
func _add_particles() -> void:
	var leaves := CPUParticles3D.new()
	leaves.name = "Leaves"
	leaves.amount = 14
	leaves.lifetime = 14.0
	leaves.preprocess = 14.0
	leaves.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	leaves.emission_box_extents = Vector3(7.0, 4.0, 2.0)
	leaves.position = Vector3(0.0, 0.0, -7.0)
	leaves.direction = Vector3(1.0, -0.4, 0.0)
	leaves.spread = 30.0
	leaves.initial_velocity_min = 0.25
	leaves.initial_velocity_max = 0.6
	leaves.gravity = Vector3(0.05, -0.12, 0.0)
	leaves.angular_velocity_min = -40.0
	leaves.angular_velocity_max = 40.0
	leaves.angle_max = 360.0
	leaves.scale_amount_min = 0.7
	leaves.scale_amount_max = 1.3
	leaves.mesh = _leaf_mesh()
	leaves.color_initial_ramp = _gradient([Color(0.62, 0.74, 0.42), Color(0.95, 0.78, 0.4), Color(0.88, 0.55, 0.3)])
	leaves.color_ramp = _gradient([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	leaves.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	camera.add_child(leaves)
	var dust := CPUParticles3D.new()
	dust.name = "LightDust"
	dust.amount = 36
	dust.lifetime = 9.0
	dust.preprocess = 9.0
	dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	dust.emission_box_extents = Vector3(6.0, 3.5, 2.5)
	dust.position = Vector3(0.0, 0.0, -6.0)
	dust.direction = Vector3(0.2, 1.0, 0.0)
	dust.spread = 60.0
	dust.initial_velocity_min = 0.05
	dust.initial_velocity_max = 0.15
	dust.gravity = Vector3.ZERO
	var quad := QuadMesh.new()
	quad.size = Vector2(0.035, 0.035)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	quad.material = mat
	dust.mesh = quad
	dust.color_ramp = _gradient([Color(1, 0.92, 0.7, 0), Color(1, 0.92, 0.7, 0.8), Color(1, 0.92, 0.7, 0)])
	dust.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	camera.add_child(dust)


## A small leaf (a pointed diamond with a fold), coloured per particle.
func _leaf_mesh() -> Mesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts := [Vector3(0, 0.07, 0), Vector3(0.04, 0, 0.008), Vector3(0, -0.07, 0), Vector3(-0.04, 0, 0.008)]
	for k in [0, 1, 2, 0, 2, 3]:
		st.set_normal(Vector3.BACK)
		st.add_vertex(pts[k])
	var mesh := st.commit()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.surface_set_material(0, mat)
	return mesh


func _gradient(colours: Array) -> Gradient:
	var g := Gradient.new()
	var offsets := PackedFloat32Array()
	var cols := PackedColorArray()
	for i in colours.size():
		offsets.append(float(i) / (colours.size() - 1))
		cols.append(colours[i])
	g.offsets = offsets
	g.colors = cols
	return g


# ---------------------------------------------------------------- UI

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.name = "UI"
	add_child(layer)
	var ui := Control.new()
	ui.name = "Root"
	ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(ui)
	# A soft warm shade at the top and behind the menu, so text reads over
	# any part of the backdrop.
	var shade := TextureRect.new()
	shade.name = "Shade"
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var grad := GradientTexture2D.new()
	grad.gradient = _gradient([Color(0.16, 0.08, 0.03, 0.5), Color(0.16, 0.08, 0.03, 0.08), Color(0.16, 0.08, 0.03, 0.22), Color(0.16, 0.08, 0.03, 0.45)])
	grad.fill_from = Vector2(0.5, 0.0)
	grad.fill_to = Vector2(0.5, 1.0)
	shade.texture = grad
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	ui.add_child(shade)
	_build_title(ui)
	_build_menu(ui)
	_build_settings(ui)


## "Skyroot": each letter its own label, set by hand with a slight tilt,
## floating up and down in a gentle wave.
func _build_title(ui: Control) -> void:
	var font := FontVariation.new()
	font.base_font = ThemeDB.fallback_font
	font.variation_embolden = 0.9
	font.spacing_glyph = 4
	var settings_big := LabelSettings.new()
	settings_big.font = font
	settings_big.font_size = 168
	settings_big.font_color = CREAM
	settings_big.outline_size = 14
	settings_big.outline_color = INK
	settings_big.shadow_size = 18
	settings_big.shadow_color = Color(0.12, 0.06, 0.02, 0.55)
	settings_big.shadow_offset = Vector2(6, 10)
	var title := Control.new()
	title.name = "Title"
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(title)
	# A zero-size anchor at the top middle of the screen; the letters sit
	# round it.
	title.anchor_left = 0.5
	title.anchor_right = 0.5
	title.anchor_top = 0.0
	title.anchor_bottom = 0.0
	var widths: Array[float] = []
	var total := 0.0
	for ch in TITLE:
		var w := font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, settings_big.font_size).x + 6.0
		widths.append(w)
		total += w
	var x := -total / 2.0
	var tilts := [-3.0, 2.0, -1.5, 2.5, -2.0, 1.5, -2.5]
	for i in TITLE.length():
		var l := Label.new()
		l.name = "Letter%d" % i
		l.text = TITLE[i]
		l.label_settings = settings_big
		l.position = Vector2(x, 150.0)
		l.size = Vector2(widths[i], 200.0)
		l.pivot_offset = Vector2(widths[i] / 2.0, 110.0)
		l.set_meta("base_y", 150.0)
		l.set_meta("tilt", tilts[i % tilts.size()])
		l.rotation = deg_to_rad(tilts[i % tilts.size()])
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		title.add_child(l)
		title_letters.append(l)
		x += widths[i]
	var small := LabelSettings.new()
	small.font = font
	small.font_size = 40
	small.font_color = Color(1.0, 0.9, 0.72)
	small.outline_size = 8
	small.outline_color = INK
	small.shadow_size = 8
	small.shadow_color = Color(0.12, 0.06, 0.02, 0.5)
	small.shadow_offset = Vector2(3, 5)
	subtitle = Label.new()
	subtitle.name = "Subtitle"
	subtitle.text = SUBTITLE
	subtitle.label_settings = small
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.size = Vector2(1200.0, 60.0)
	subtitle.position = Vector2(-600.0, 372.0)
	subtitle.set_meta("base_y", 372.0)
	subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.add_child(subtitle)


func _button_styles(b: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.3, 0.18, 0.1, 0.62)
	normal.border_color = Color(1.0, 0.9, 0.7, 0.45)
	normal.set_border_width_all(3)
	normal.set_corner_radius_all(26)
	normal.content_margin_top = 14
	normal.content_margin_bottom = 14
	# The same box in every state, so nothing snaps: the highlight is a
	# separate glow that fades in, plus a gentle grow.
	for state in ["normal", "hover", "pressed", "focus", "hover_pressed"]:
		b.add_theme_stylebox_override(state, normal)
	var font := FontVariation.new()
	font.base_font = ThemeDB.fallback_font
	font.variation_embolden = 0.6
	b.add_theme_font_override("font", font)
	b.add_theme_font_size_override("font_size", 44)
	for c in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(c, CREAM)
	b.add_theme_color_override("font_outline_color", INK)
	b.add_theme_constant_override("outline_size", 6)


## A button with a soft gold glow behind it that fades in when selected.
func _make_button(text: String) -> Button:
	var b := Button.new()
	b.name = text
	b.text = text
	b.custom_minimum_size = Vector2(440, 92)
	b.focus_mode = Control.FOCUS_ALL
	_button_styles(b)
	_add_glow(b)
	return b


## The soft gold glow behind a button, faded in when it's selected (plus a
## gentle grow), so selection never snaps.
func _add_glow(b: BaseButton) -> void:
	var glow := Panel.new()
	glow.name = "Glow"
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow.set_anchors_preset(Control.PRESET_FULL_RECT)
	glow.show_behind_parent = true
	var gs := StyleBoxFlat.new()
	gs.bg_color = Color(0.62, 0.4, 0.18, 0.85)
	gs.border_color = GOLD
	gs.set_border_width_all(4)
	gs.set_corner_radius_all(26)
	gs.shadow_color = Color(1.0, 0.8, 0.45, 0.55)
	gs.shadow_size = 22
	glow.add_theme_stylebox_override("panel", gs)
	glow.modulate.a = 0.0
	b.add_child(glow)
	b.focus_entered.connect(_highlight.bind(b, true))
	b.focus_exited.connect(_highlight.bind(b, false))
	b.mouse_entered.connect(func() -> void: if not _busy: b.grab_focus())
	b.resized.connect(func() -> void: b.pivot_offset = b.size / 2.0)


func _highlight(b: BaseButton, on: bool) -> void:
	var tw := b.create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(b, "scale", Vector2.ONE * (1.08 if on else 1.0), 0.18)
	tw.tween_property(b.get_node("Glow"), "modulate:a", 1.0 if on else 0.0, 0.18)


func _build_menu(ui: Control) -> void:
	menu = VBoxContainer.new()
	menu.name = "Menu"
	menu.add_theme_constant_override("separation", 26)
	ui.add_child(menu)
	_centre(menu, Vector2(440.0, 3.0 * 92.0 + 2.0 * 26.0), 30.0)
	for t in ["Play", "Settings", "Quit"]:
		var b := _make_button(t)
		menu.add_child(b)
		buttons.append(b)
	buttons[0].pressed.connect(play)
	buttons[1].pressed.connect(open_settings)
	buttons[2].pressed.connect(quit)
	_wrap_focus(buttons)


## Up from the top goes to the bottom, and down from the bottom to the top.
func _wrap_focus(items: Array) -> void:
	for i in items.size():
		var c: Control = items[i]
		c.focus_neighbor_top = c.get_path_to(items[(i - 1 + items.size()) % items.size()])
		c.focus_neighbor_bottom = c.get_path_to(items[(i + 1) % items.size()])
		c.focus_neighbor_left = c.get_path_to(c)
		c.focus_neighbor_right = c.get_path_to(c)


func _build_settings(ui: Control) -> void:
	settings = PanelContainer.new()
	settings.name = "Settings"
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0.22, 0.13, 0.07, 0.88)
	ps.border_color = Color(1.0, 0.88, 0.62, 0.7)
	ps.set_border_width_all(3)
	ps.set_corner_radius_all(30)
	ps.set_content_margin_all(40)
	ps.shadow_color = Color(0, 0, 0, 0.35)
	ps.shadow_size = 18
	settings.add_theme_stylebox_override("panel", ps)
	settings.custom_minimum_size = Vector2(600, 0)
	settings.visible = false
	ui.add_child(settings)
	_centre(settings, Vector2(600.0, 420.0), -20.0)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 26)
	settings.add_child(box)
	var heading := Label.new()
	heading.text = "Settings"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 52)
	heading.add_theme_color_override("font_color", CREAM)
	heading.add_theme_color_override("font_outline_color", INK)
	heading.add_theme_constant_override("outline_size", 8)
	box.add_child(heading)
	fullscreen_toggle = CheckButton.new()
	fullscreen_toggle.name = "Fullscreen"
	fullscreen_toggle.text = "Fullscreen (F11)"
	fullscreen_toggle.custom_minimum_size = Vector2(440, 80)
	_button_styles(fullscreen_toggle)
	fullscreen_toggle.add_theme_font_size_override("font_size", 38)
	box.add_child(fullscreen_toggle)
	_add_glow(fullscreen_toggle)
	fullscreen_toggle.toggled.connect(func(on: bool) -> void:
		if on != WindowControls.is_fullscreen():
			WindowControls.toggle_fullscreen())
	var back := _make_button("Back")
	back.pressed.connect(close_settings)
	box.add_child(back)
	_wrap_focus([fullscreen_toggle, back])


## Anchors a control to the middle of the screen, `size` big, its top
## `top` pixels below the middle (base 1920 x 1080 units).
func _centre(c: Control, size: Vector2, top: float) -> void:
	c.anchor_left = 0.5
	c.anchor_right = 0.5
	c.anchor_top = 0.5
	c.anchor_bottom = 0.5
	c.offset_left = -size.x / 2.0
	c.offset_right = size.x / 2.0
	c.offset_top = top
	c.offset_bottom = top + size.y
	c.grow_horizontal = Control.GROW_DIRECTION_BOTH
	c.grow_vertical = Control.GROW_DIRECTION_END


# ---------------------------------------------------------------- actions

func _fade_in() -> void:
	var black := ColorRect.new()
	black.name = "LaunchFade"
	black.color = Color.BLACK
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	black.set_anchors_preset(Control.PRESET_FULL_RECT)
	get_node("UI/Root").add_child(black)
	var title := get_node("UI/Root/Title") as Control
	title.modulate.a = 0.0
	menu.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(black, "modulate:a", 0.0, 1.4)
	tw.parallel().tween_property(title, "modulate:a", 1.0, 2.2).set_delay(0.4)
	tw.parallel().tween_property(menu, "modulate:a", 1.0, 1.2).set_delay(1.4)
	tw.tween_callback(black.queue_free)
	buttons[0].grab_focus()


func _input(event: InputEvent) -> void:
	if _busy or not (event is InputEventKey or event is InputEventJoypadButton):
		return
	if event.is_echo():
		return
	var focused := get_viewport().gui_get_focus_owner()
	if event is InputEventKey and event.pressed:
		var key := (event as InputEventKey).physical_keycode
		if key == KEY_W or key == KEY_S:
			if focused:
				var path := focused.focus_neighbor_top if key == KEY_W else focused.focus_neighbor_bottom
				var target := focused.get_node_or_null(path) as Control
				if target:
					target.grab_focus()
			get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed(Game.INTERACT) and focused is BaseButton:
		get_viewport().set_input_as_handled()
		_activate(focused as BaseButton)
	elif event.is_action_pressed("ui_cancel") and settings.visible:
		get_viewport().set_input_as_handled()
		close_settings()


## Press a button from the keyboard (E): the same as clicking it.
func _activate(b: BaseButton) -> void:
	if b.toggle_mode:
		b.button_pressed = not b.button_pressed
	else:
		b.pressed.emit()


func open_settings() -> void:
	menu.visible = false
	settings.visible = true
	settings.modulate.a = 0.0
	create_tween().tween_property(settings, "modulate:a", 1.0, 0.25)
	fullscreen_toggle.grab_focus()


func close_settings() -> void:
	settings.visible = false
	menu.visible = true
	buttons[1].grab_focus()


## Fade to black, then start the game exactly as it always has: Pebblenook,
## with the opening lore scene the first time.
func play() -> void:
	if _busy:
		return
	_busy = true
	Game.start_game(GAME_SCENE)


func quit() -> void:
	get_tree().quit()
