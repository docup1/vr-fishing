extends RefCounted

const MapMarker = preload("res://map_marker.gd")
var game

func _init(owner):
	game = owner

func _build_ui() -> void:
	var layer = CanvasLayer.new()
	layer.layer = 2
	if game.vr_active and not game.vr_simulator:
		game.vr_ui_viewport = SubViewport.new()
		game.vr_ui_viewport.size = Vector2i(1280, 720)
		game.vr_ui_viewport.transparent_bg = true
		game.vr_ui_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		game.add_child(game.vr_ui_viewport)
		game.vr_ui_viewport.add_child(layer)
		var ui_screen = MeshInstance3D.new()
		var quad = QuadMesh.new()
		quad.size = Vector2(2.4, 1.35)
		ui_screen.mesh = quad
		var material = StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.albedo_texture = game.vr_ui_viewport.get_texture()
		material.no_depth_test = true
		material.render_priority = 120
		ui_screen.material_override = material
		ui_screen.position = Vector3(0, 0, -2.0)
		game.camera.add_child(ui_screen)
	else:
		game.add_child(layer)
	game.ui_root = Control.new()
	game.ui_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	game.ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(game.ui_root)
	game.hud_background = _panel(Color(0.055, 0.13, 0.14, 0.93), Color(0.54, 0.60, 0.45, 0.8))
	game.hud_title = _label(game.ui_root, Vector2.ZERO, 13)
	game.hud_title.text = "Р Ы Б А Ц К И Й   Д Н Е В Н И К"
	game.hud_title.add_theme_color_override("font_color", Color(0.80, 0.77, 0.59))
	game.hud = _label(game.ui_root, Vector2.ZERO, 19)
	game.hud.add_theme_color_override("font_color", Color(0.96, 0.95, 0.85))
	game.prompt_background = _panel(Color(0.055, 0.13, 0.14, 0.93), Color(0.54, 0.60, 0.45, 0.7))
	game.prompt = _label(game.ui_root, Vector2.ZERO, 18)
	game.prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	game.prompt.add_theme_color_override("font_color", Color(0.95, 0.93, 0.82))
	game.info_background = _panel(Color(0.08, 0.16, 0.15, 0.94), Color(0.68, 0.65, 0.45, 0.8))
	game.info = _label(game.ui_root, Vector2.ZERO, 18)
	game.info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	game.info.add_theme_color_override("font_color", Color(1.0, 0.94, 0.77))
	game.overlay_background = _panel(Color(0.91, 0.87, 0.74, 0.98), Color(0.57, 0.47, 0.31))
	game.overlay = _label(game.ui_root, Vector2.ZERO, 21)
	game.overlay.add_theme_color_override("font_color", Color(0.17, 0.20, 0.17))
	game.overlay.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	game.overlay.visible = false
	game.bar = ProgressBar.new()
	game.bar.show_percentage = false
	game.bar.add_theme_stylebox_override("background", _panel_style(Color(0.04, 0.12, 0.12, 0.95), Color(0.66, 0.69, 0.54), 6))
	game.bar.add_theme_stylebox_override("fill", _panel_style(Color(0.63, 0.77, 0.55), Color(0.63, 0.77, 0.55), 6))
	game.bar.visible = false
	game.ui_root.add_child(game.bar)
	game.progress_title = _label(game.ui_root, Vector2.ZERO, 13)
	game.progress_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	game.progress_title.text = "В Ы В А Ж И В А Н И Е"
	game.progress_title.add_theme_color_override("font_color", Color(0.98, 0.95, 0.82))
	_build_map()
	_layout_ui()

func _build_map() -> void:
	game.map_background = _panel(Color(0.055, 0.13, 0.14, 0.98), Color(0.70, 0.66, 0.45))
	game.map_title = _label(game.ui_root, Vector2.ZERO, 23)
	game.map_title.text = "КАРТА ПРУДА"
	game.map_title.add_theme_color_override("font_color", Color(0.97, 0.94, 0.80))
	game.map_legend = _label(game.ui_root, Vector2.ZERO, 18)
	game.map_legend.text = "ОРИЕНТИРЫ\n\n▲  Вы и направление взгляда\n\nКамышовая заводь — север\nСтарый причал — запад\nКоряжник — восток\nДом — у южного причала\n\nM — закрыть карту"
	game.map_legend.add_theme_color_override("font_color", Color(0.92, 0.90, 0.75))
	game.map_legend.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	game.map_footer = _label(game.ui_root, Vector2.ZERO, 16)
	game.map_footer.text = "M  —  закрыть карту"
	game.map_footer.add_theme_color_override("font_color", Color(0.83, 0.80, 0.62))
	game.map_viewport = SubViewport.new()
	game.map_viewport.size = Vector2i(640, 640)
	game.map_viewport.own_world_3d = false
	game.map_viewport.world_3d = game.get_viewport().world_3d
	game.map_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	game.ui_root.add_child(game.map_viewport)
	game.map_camera = Camera3D.new()
	game.map_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	game.map_camera.size = 104.0
	game.map_camera.position = Vector3(0, 120, 0)
	game.map_camera.far = 220.0
	game.map_camera.rotation_degrees = Vector3(-90, 0, 0)
	game.map_camera.current = true
	game.map_viewport.add_child(game.map_camera)
	game.map_image = TextureRect.new()
	game.map_image.texture = game.map_viewport.get_texture()
	game.map_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	game.map_image.stretch_mode = TextureRect.STRETCH_SCALE
	game.map_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	game.ui_root.add_child(game.map_image)
	game.map_marker = MapMarker.new()
	game.map_marker.tracked_camera = game.camera
	game.map_marker.map_camera = game.map_camera
	game.map_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	game.ui_root.add_child(game.map_marker)

func _panel_style(color: Color, border: Color, radius: int = 10) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.shadow_color = Color(0, 0, 0, 0.22)
	style.shadow_size = 5
	style.shadow_offset = Vector2(0, 2)
	return style

func _panel(color: Color, border: Color) -> Panel:
	var panel = Panel.new()
	panel.add_theme_stylebox_override("panel", _panel_style(color, border))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	game.ui_root.add_child(panel)
	return panel

func _label(parent: Node, pos: Vector2, font_size: int) -> Label:
	var label = Label.new()
	label.position = pos
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	parent.add_child(label)
	return label

func _layout_ui() -> void:
	var screen = Vector2(game.vr_ui_viewport.size) if is_instance_valid(game.vr_ui_viewport) else game.get_viewport().get_visible_rect().size
	var margin = 24.0
	var small_screen = screen.x < 980.0 or screen.y < 560.0
	game.prompt.add_theme_font_size_override("font_size", 14 if small_screen else 18)
	game.hud.add_theme_font_size_override("font_size", 15 if small_screen else 19)
	game.overlay.add_theme_font_size_override("font_size", 16 if small_screen else 21)
	game.info.add_theme_font_size_override("font_size", 15 if small_screen else 18)
	var hud_width = minf(510.0, screen.x - margin * 2.0)
	game.hud_background.position = Vector2(margin, margin)
	game.hud_background.size = Vector2(hud_width, 112)
	game.hud_title.position = game.hud_background.position + Vector2(20, 13)
	game.hud_title.size = Vector2(hud_width - 40, 20)
	game.hud.position = game.hud_background.position + Vector2(20, 39)
	game.hud.size = Vector2(hud_width - 40, 58)
	var prompt_width = minf(1050.0, screen.x - margin * 2.0)
	game.prompt_background.position = Vector2((screen.x - prompt_width) * 0.5, screen.y - 73)
	game.prompt_background.size = Vector2(prompt_width, 49)
	game.prompt.position = game.prompt_background.position + Vector2(14, 12)
	game.prompt.size = Vector2(prompt_width - 28, 26)
	var notice_width = minf(770.0, screen.x - margin * 2.0)
	game.info_background.position = Vector2((screen.x - notice_width) * 0.5, screen.y - 141)
	game.info_background.size = Vector2(notice_width, 48)
	game.info.position = game.info_background.position + Vector2(12, 11)
	game.info.size = Vector2(notice_width - 24, 27)
	var progress_width = minf(420.0, screen.x - margin * 2.0)
	game.bar.position = Vector2((screen.x - progress_width) * 0.5, screen.y - 121)
	game.bar.size = Vector2(progress_width, 12)
	game.progress_title.position = game.bar.position + Vector2(0, -23)
	game.progress_title.size = Vector2(progress_width, 20)
	var dialogue = game.state == "dialogue"
	var panel_width = minf(960.0 if dialogue else 860.0, screen.x - margin * 2.0)
	var panel_height = 205.0 if dialogue else minf(390.0, screen.y - margin * 2.0)
	var panel_y = screen.y - panel_height - margin if dialogue else (screen.y - panel_height) * 0.5
	game.overlay_background.position = Vector2((screen.x - panel_width) * 0.5, panel_y)
	game.overlay_background.size = Vector2(panel_width, panel_height)
	game.overlay.position = game.overlay_background.position + Vector2(32, 24)
	game.overlay.size = Vector2(panel_width - 64, panel_height - 48)
	var map_width = minf(940.0, screen.x - margin * 2.0)
	var map_height = minf(660.0, screen.y - margin * 2.0)
	game.map_background.position = Vector2((screen.x - map_width) * 0.5, (screen.y - map_height) * 0.5)
	game.map_background.size = Vector2(map_width, map_height)
	game.map_title.position = game.map_background.position + Vector2(24, 16)
	var side = minf(map_height - 104.0, map_width * 0.62)
	game.map_image.position = game.map_background.position + Vector2(24, 58)
	game.map_image.size = Vector2(side, side)
	game.map_marker.position = game.map_image.position
	game.map_marker.size = game.map_image.size
	game.map_legend.position = game.map_image.position + Vector2(side + 22, 4)
	game.map_legend.size = Vector2(maxf(100.0, map_width - side - 70), side)
	game.map_legend.add_theme_font_size_override("font_size", 14 if small_screen else 18)
	game.map_footer.position = game.map_background.position + Vector2(24, map_height - 35)

func _update_ui() -> void:
	_layout_ui()
	var total_minutes = int(game.clock_minutes) % (24 * 60)
	game.hud.text = "%02d:%02d     Энергия  %d / 100\nИстория  %d / 6     Главари  %d / 6     Улов  %d" % [total_minutes / 60, total_minutes % 60, int(game.energy), game.story_zones.size(), game.caught_bosses.size(), game.pending_fish.size()]
	game.info.text = game.message
	game.info.visible = not game.message.is_empty() and game.state != "dialogue" and not game.book_open and not game.map_open
	game.info_background.visible = game.info.visible
	game.prompt.text = "WASD — движение   |   Мышь — обзор   |   E — действие   |   Tab — книга   |   M — карта"
	game.bar.visible = game.state == "reeling"
	game.progress_title.visible = game.bar.visible
	game.fish_display.visible = game.state == "dialogue"
	game.fish_model.visible = game.current_type != "boss"
	game.boss_model.visible = game.current_type == "boss"
	game.prompt.visible = game.state != "dialogue" and not game.map_open
	game.prompt_background.visible = game.prompt.visible
	game.hud.visible = not game.map_open
	game.hud_title.visible = not game.map_open
	game.hud_background.visible = not game.map_open
	game.overlay.visible = game.book_open or game.state == "dialogue"
	game.overlay_background.visible = game.overlay.visible
	game.map_background.visible = game.map_open
	game.map_title.visible = game.map_open
	game.map_legend.visible = game.map_open
	game.map_footer.visible = game.map_open
	game.map_image.visible = game.map_open
	game.map_marker.visible = game.map_open
	game.map_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if game.map_open else SubViewport.UPDATE_DISABLED
	if game.map_open:
		game.map_marker.queue_redraw()
	if game.book_open:
		game.overlay.text = "КНИГА РЫБАКА\n\nКузовок помогал рыбам находить путь домой.\nИсследуй камыши, старый причал и коряжник.\n\nЧастей истории: %d / 6     Главарей: %d / 6\nРыб в колбах дома: %d\n\nTab — закрыть книгу" % [game.story_zones.size(), game.caught_bosses.size(), game.stored_fish.size()]
	elif game.state == "dialogue":
		var speech = "Кузовок помогал рыбам. Отпусти меня — расскажу, что знаю."
		if game.current_type == "boss": speech = "Я охраняю этот участок пруда! Отпусти меня, рыбак!"
		if game.current_type == "other": speech = "Хороший сегодня день, чтобы поплавать."
		game.overlay.text = "%s\n\n«%s»\n\n1 — отпустить     2 — забрать в ящик" % [game.current_fish, speech]
	if game.state == "reeling":
		game.bar.value = game.progress * 100.0
	if game.riding and game.state == "idle":
		var zone_index = game._nearest_fishing_zone()
		var location_name: String = game.ZONES[zone_index].name if zone_index >= 0 else "Озеро"
		game.prompt.text = "%s   •   WASD — плыть   |   F — ловить   |   M — карта   |   E — к дому" % location_name
	elif game.state == "bite":
		game.prompt.text = "ПОКЛЁВКА! Нажми F сейчас"
	elif game.state == "casting":
		game.prompt.text = "Заброс: леска летит к воде"
	elif game.state == "reeling":
		game.prompt.text = "Мышь — веди круг за рыбой на воде   |   Пробел — сматывать"
	if game.vr_active:
		game.map_legend.text = "ОРИЕНТИРЫ\n\n▲  Вы и направление взгляда\n\nКамышовая заводь — север\nСтарый причал — запад\nКоряжник — восток\nДом — у южного причала\n\nY — закрыть карту"
		game.prompt.text = "Левый стик — движение   |   X — действие   |   Y — карта   |   A — книга"
		if game.riding and game.state == "idle":
			game.prompt.text = "Возьмись за рукоятки и греби назад   |   Курок — заброс   |   Y — карта   |   X — выйти"
		elif game.state == "bite":
			game.prompt.text = "ПОКЛЁВКА! Нажми правый курок"
		elif game.state == "reeling":
			game.prompt.text = "Правый стик — веди круг за рыбой   |   Держи курок — сматывать"
		if game.state == "dialogue":
			game.overlay.text = game.overlay.text.replace("1 — отпустить     2 — забрать в ящик", "A — отпустить     B — забрать в ящик")
		elif game.book_open:
			game.overlay.text = game.overlay.text.replace("Tab — закрыть книгу", "A — закрыть книгу")
		game.map_footer.text = "Y — закрыть карту"
		if game.vr_simulator and game.state != "dialogue":
			game.prompt.text = "SIM: WASD / мышь  |  X — действие  |  Q/E — хват  |  I/K и ↑/↓ — гребок  |  Пробел — удочка"

func _show_message(text: String, duration: float) -> void:
	if game.vr_active:
		text = text.replace("Нажми F", "Нажми правый курок")
		text = text.replace("клавишей M", "кнопкой Y")
		text = text.replace("E: книга", "X: книга")
	game.message = text
	game.message_time = duration
