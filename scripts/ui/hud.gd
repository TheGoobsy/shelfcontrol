class_name HUD
extends CanvasLayer
## 2D overlay: top navigation bar, bottom action bar, tray, toasts and bottom sheets.

signal prev_pressed()
signal next_pressed()
signal back_pressed()
signal add_book_pressed()
signal import_pressed()
signal style_pressed()
signal room_menu_pressed()
signal shelf_menu_pressed()
signal tray_chip_pressed(book_id: String)
signal title_pressed()
signal settings_pressed()
signal books_pressed()
signal edit_pressed()

var main: Node
var style: Dictionary = {}
var root: Control
var top_bar: PanelContainer
var prev_btn: Button
var next_btn: Button
var title_btn: Button
var title_lbl: Label
var sub_lbl: Label
var bottom_bar: PanelContainer
var bottom_row: HBoxContainer
var back_btn: Button
var tray_panel: PanelContainer
var tray_scroll: ScrollContainer
var tray_box: HBoxContainer
var tray_hint: Label
var side_box: VBoxContainer
var side_buttons: Array = []
var toast_panel: PanelContainer
var toast_lbl: Label
var dimmer: ColorRect
var sheet: PanelContainer
var sheet_title: Label
var sheet_content: VBoxContainer
var sheet_scroll: ScrollContainer
var dialogs: Dialogs

var sans: Font
var sans_bold: Font
var serif_bold: Font
var mode_shelf := false
var placing_id := ""
var _toast_tween: Tween
var _drag_tray := false

func setup(m: Node) -> void:
	main = m
	layer = 5
	sans = load("res://fonts/NotoSans-Regular.ttf")
	sans_bold = load("res://fonts/NotoSans-Bold.ttf")
	serif_bold = load("res://fonts/NotoSerif-Bold.ttf")
	root = Control.new()
	root.name = "HUDRoot"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_build_top()
	_build_side()
	_build_bottom()
	_build_toast()
	_build_sheet()
	dialogs = Dialogs.new(self)
	get_viewport().size_changed.connect(_layout)
	get_tree().node_added.connect(_on_node_added)
	_layout()

## Controls inside a sheet must PASS pointer events so the ScrollContainer can scroll by touch-drag.
func _on_node_added(node: Node) -> void:
	if node is Control and sheet_content != null and sheet_content.is_ancestor_of(node):
		if node.mouse_filter == Control.MOUSE_FILTER_STOP:
			node.mouse_filter = Control.MOUSE_FILTER_PASS

# ---------------------------------------------------------------- theme

func _flat(bg: Color, radius := 18, margins := Vector2(24, 14), border := Color(0, 0, 0, 0), border_w := 0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = margins.x
	sb.content_margin_right = margins.x
	sb.content_margin_top = margins.y
	sb.content_margin_bottom = margins.y
	if border_w > 0:
		sb.border_color = border
		sb.set_border_width_all(border_w)
	return sb

func fg() -> Color:
	return style.get("ui_fg", Color.WHITE)

func accent() -> Color:
	return style.get("ui_accent", Color(0.9, 0.6, 0.3))

func muted() -> Color:
	return style.get("ui_muted", Color(0.7, 0.7, 0.7))

func bg() -> Color:
	return style.get("ui_bg", Color(0.1, 0.1, 0.1, 0.9))

func on_accent() -> Color:
	return Color(0.1, 0.08, 0.06) if accent().get_luminance() > 0.5 else Color.WHITE

func apply_style(st: Dictionary) -> void:
	style = st
	var th := Theme.new()
	th.default_font = sans
	th.default_font_size = 30
	var f := fg()
	var a := accent()
	var mu := muted()
	var soft := Color(f.r, f.g, f.b, 0.10)
	var softer := Color(f.r, f.g, f.b, 0.06)
	var empty := StyleBoxEmpty.new()

	th.set_stylebox("normal", "Button", _flat(soft))
	th.set_stylebox("hover", "Button", _flat(Color(f.r, f.g, f.b, 0.16)))
	th.set_stylebox("pressed", "Button", _flat(Color(f.r, f.g, f.b, 0.26)))
	th.set_stylebox("disabled", "Button", _flat(Color(f.r, f.g, f.b, 0.04)))
	th.set_stylebox("focus", "Button", empty)
	th.set_color("font_color", "Button", f)
	th.set_color("font_hover_color", "Button", f)
	th.set_color("font_pressed_color", "Button", f)
	th.set_color("font_focus_color", "Button", f)
	th.set_color("font_disabled_color", "Button", Color(f.r, f.g, f.b, 0.35))
	th.set_font_size("font_size", "Button", 30)

	for v in ["AccentButton", "IconButton", "ChipButton", "DangerButton", "GhostButton", "CardButton"]:
		th.set_type_variation(v, "Button")
	th.set_stylebox("normal", "AccentButton", _flat(a))
	th.set_stylebox("hover", "AccentButton", _flat(a.lightened(0.08)))
	th.set_stylebox("pressed", "AccentButton", _flat(a.darkened(0.2)))
	th.set_stylebox("disabled", "AccentButton", _flat(Color(a.r, a.g, a.b, 0.35)))
	th.set_color("font_color", "AccentButton", on_accent())
	th.set_color("font_hover_color", "AccentButton", on_accent())
	th.set_color("font_pressed_color", "AccentButton", on_accent())
	th.set_color("font_focus_color", "AccentButton", on_accent())
	th.set_font("font", "AccentButton", sans_bold)

	th.set_stylebox("normal", "IconButton", _flat(soft, 44, Vector2(0, 0)))
	th.set_stylebox("hover", "IconButton", _flat(Color(f.r, f.g, f.b, 0.16), 44, Vector2(0, 0)))
	th.set_stylebox("pressed", "IconButton", _flat(Color(f.r, f.g, f.b, 0.26), 44, Vector2(0, 0)))
	th.set_stylebox("disabled", "IconButton", _flat(Color(f.r, f.g, f.b, 0.03), 44, Vector2(0, 0)))
	th.set_font_size("font_size", "IconButton", 46)

	th.set_type_variation("AccentIconButton", "Button")
	th.set_stylebox("normal", "AccentIconButton", _flat(a, 44, Vector2(0, 0)))
	th.set_stylebox("hover", "AccentIconButton", _flat(a.lightened(0.08), 44, Vector2(0, 0)))
	th.set_stylebox("pressed", "AccentIconButton", _flat(a.darkened(0.2), 44, Vector2(0, 0)))
	th.set_stylebox("disabled", "AccentIconButton", _flat(Color(a.r, a.g, a.b, 0.35), 44, Vector2(0, 0)))
	th.set_stylebox("focus", "AccentIconButton", empty)
	th.set_color("icon_normal_color", "AccentIconButton", on_accent())
	th.set_color("icon_hover_color", "AccentIconButton", on_accent())
	th.set_color("icon_pressed_color", "AccentIconButton", on_accent())
	th.set_color("icon_focus_color", "AccentIconButton", on_accent())

	th.set_stylebox("normal", "ChipButton", _flat(softer, 16, Vector2(0, 0)))
	th.set_stylebox("hover", "ChipButton", _flat(soft, 16, Vector2(0, 0)))
	th.set_stylebox("pressed", "ChipButton", _flat(soft, 16, Vector2(0, 0)))

	th.set_stylebox("normal", "DangerButton", _flat(Color(0.72, 0.22, 0.20)))
	th.set_stylebox("hover", "DangerButton", _flat(Color(0.78, 0.26, 0.24)))
	th.set_stylebox("pressed", "DangerButton", _flat(Color(0.55, 0.16, 0.15)))
	th.set_color("font_color", "DangerButton", Color.WHITE)
	th.set_color("font_hover_color", "DangerButton", Color.WHITE)
	th.set_color("font_pressed_color", "DangerButton", Color.WHITE)

	th.set_stylebox("normal", "GhostButton", _flat(Color(0, 0, 0, 0), 18, Vector2(12, 6)))
	th.set_stylebox("hover", "GhostButton", _flat(softer, 18, Vector2(12, 6)))
	th.set_stylebox("pressed", "GhostButton", _flat(soft, 18, Vector2(12, 6)))

	th.set_stylebox("normal", "CardButton", _flat(softer, 22, Vector2(22, 18)))
	th.set_stylebox("hover", "CardButton", _flat(soft, 22, Vector2(22, 18)))
	th.set_stylebox("pressed", "CardButton", _flat(Color(f.r, f.g, f.b, 0.2), 22, Vector2(22, 18)))

	th.set_stylebox("panel", "PanelContainer", _flat(bg(), 30, Vector2(22, 18)))
	th.set_type_variation("Card", "PanelContainer")
	th.set_stylebox("panel", "Card", _flat(softer, 20, Vector2(20, 16)))
	th.set_type_variation("AccentCard", "PanelContainer")
	th.set_stylebox("panel", "AccentCard", _flat(Color(a.r, a.g, a.b, 0.18), 20, Vector2(20, 16), a, 3))

	th.set_color("font_color", "Label", f)
	for v in ["TitleLabel", "SubLabel", "HeadLabel", "SmallLabel", "MutedLabel"]:
		th.set_type_variation(v, "Label")
	th.set_font("font", "TitleLabel", serif_bold)
	th.set_font_size("font_size", "TitleLabel", 48)
	th.set_font_size("font_size", "SubLabel", 25)
	th.set_color("font_color", "SubLabel", mu)
	th.set_font("font", "HeadLabel", sans_bold)
	th.set_font_size("font_size", "HeadLabel", 34)
	th.set_font_size("font_size", "SmallLabel", 24)
	th.set_font_size("font_size", "MutedLabel", 27)
	th.set_color("font_color", "MutedLabel", mu)

	var field := _flat(soft, 16, Vector2(20, 16))
	var field_focus := _flat(soft, 16, Vector2(20, 16), a, 3)
	th.set_stylebox("normal", "LineEdit", field)
	th.set_stylebox("focus", "LineEdit", field_focus)
	th.set_stylebox("read_only", "LineEdit", field)
	th.set_color("font_color", "LineEdit", f)
	th.set_color("font_placeholder_color", "LineEdit", mu)
	th.set_color("caret_color", "LineEdit", a)
	th.set_color("selection_color", "LineEdit", Color(a.r, a.g, a.b, 0.4))
	th.set_font_size("font_size", "LineEdit", 30)
	th.set_stylebox("normal", "TextEdit", field)
	th.set_stylebox("focus", "TextEdit", field_focus)
	th.set_color("font_color", "TextEdit", f)
	th.set_color("font_placeholder_color", "TextEdit", mu)
	th.set_color("caret_color", "TextEdit", a)
	th.set_color("background_color", "TextEdit", Color(0, 0, 0, 0))
	th.set_font_size("font_size", "TextEdit", 26)

	th.set_color("font_color", "CheckBox", f)
	th.set_color("font_hover_color", "CheckBox", f)
	th.set_color("font_pressed_color", "CheckBox", f)
	th.set_color("font_focus_color", "CheckBox", f)
	th.set_font_size("font_size", "CheckBox", 28)
	th.set_stylebox("normal", "CheckBox", _flat(Color(0, 0, 0, 0), 0, Vector2(8, 10)))
	th.set_stylebox("hover", "CheckBox", _flat(Color(0, 0, 0, 0), 0, Vector2(8, 10)))
	th.set_stylebox("pressed", "CheckBox", _flat(Color(0, 0, 0, 0), 0, Vector2(8, 10)))
	th.set_stylebox("focus", "CheckBox", empty)

	th.set_stylebox("normal", "OptionButton", _flat(soft))
	th.set_stylebox("hover", "OptionButton", _flat(Color(f.r, f.g, f.b, 0.16)))
	th.set_stylebox("pressed", "OptionButton", _flat(Color(f.r, f.g, f.b, 0.26)))
	th.set_stylebox("focus", "OptionButton", empty)
	th.set_color("font_color", "OptionButton", f)
	th.set_color("font_hover_color", "OptionButton", f)
	th.set_color("font_pressed_color", "OptionButton", f)
	th.set_color("font_focus_color", "OptionButton", f)
	th.set_font_size("font_size", "OptionButton", 28)
	var popup_bg := Color(bg().r, bg().g, bg().b, 1.0)
	th.set_stylebox("panel", "PopupMenu", _flat(popup_bg, 16, Vector2(8, 8), Color(f.r, f.g, f.b, 0.15), 2))
	th.set_stylebox("hover", "PopupMenu", _flat(Color(a.r, a.g, a.b, 0.3), 10, Vector2(12, 8)))
	th.set_color("font_color", "PopupMenu", f)
	th.set_color("font_hover_color", "PopupMenu", f)
	th.set_font_size("font_size", "PopupMenu", 28)

	th.set_stylebox("background", "ProgressBar", _flat(soft, 8, Vector2(0, 0)))
	th.set_stylebox("fill", "ProgressBar", _flat(a, 8, Vector2(0, 0)))
	th.set_stylebox("panel", "ScrollContainer", empty)

	th.set_color("icon_normal_color", "IconButton", f)
	th.set_color("icon_hover_color", "IconButton", f)
	th.set_color("icon_pressed_color", "IconButton", f)
	th.set_color("icon_focus_color", "IconButton", f)
	root.theme = th
	refresh_tray()
	_layout()

# ---------------------------------------------------------------- layout

func _layout() -> void:
	var vp := get_viewport()
	var win := DisplayServer.window_get_size()
	var canvas_size := vp.get_visible_rect().size
	var scale_y: float = canvas_size.y / maxf(1.0, float(win.y))
	var top_inset := 0.0
	var bottom_inset := 0.0
	if OS.has_feature("mobile"):
		var safe := DisplayServer.get_display_safe_area()
		top_inset = maxf(0.0, float(safe.position.y)) * scale_y
		bottom_inset = maxf(0.0, float(win.y - safe.end.y)) * scale_y
	top_bar.offset_top = top_inset + 24
	top_bar.offset_bottom = top_inset + 24
	bottom_bar.offset_bottom = -(bottom_inset + 24)
	bottom_bar.offset_right = -(24 + 108 + 16) if mode_shelf else -24
	back_btn.offset_bottom = -(bottom_inset + 24)
	toast_panel.offset_top = top_inset + 190
	side_box.offset_top = top_inset + 24 + top_bar.get_combined_minimum_size().y + 18

func _build_top() -> void:
	top_bar = PanelContainer.new()
	top_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_bar.offset_left = 24
	top_bar.offset_right = -24
	top_bar.grow_vertical = Control.GROW_DIRECTION_END
	root.add_child(top_bar)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 12)
	top_bar.add_child(hb)
	prev_btn = _icon_button("res://icons/chevron_left.svg", 44)
	prev_btn.pressed.connect(func(): prev_pressed.emit())
	hb.add_child(prev_btn)
	title_btn = Button.new()
	title_btn.theme_type_variation = "GhostButton"
	title_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_btn.pressed.connect(func(): title_pressed.emit())
	hb.add_child(title_btn)
	var vb := VBoxContainer.new()
	vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 0)
	title_btn.add_child(vb)
	title_lbl = Label.new()
	title_lbl.theme_type_variation = "TitleLabel"
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(title_lbl)
	sub_lbl = Label.new()
	sub_lbl.theme_type_variation = "SubLabel"
	sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	sub_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(sub_lbl)
	next_btn = _icon_button("res://icons/chevron_right.svg", 44)
	next_btn.pressed.connect(func(): next_pressed.emit())
	hb.add_child(next_btn)

## Round button showing a centred SVG icon (no text, so no baseline offset).
func _icon_button(icon_path: String, icon_px := 50) -> Button:
	var b := Button.new()
	b.theme_type_variation = "IconButton"
	b.custom_minimum_size = Vector2(96, 96)
	b.icon = load(icon_path)
	b.expand_icon = true
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	b.add_theme_constant_override("icon_max_width", icon_px)
	return b

func _side_button(icon_path: String, tip: String, sig: Signal) -> Button:
	var b := _icon_button(icon_path, 50)
	b.tooltip_text = tip
	b.pressed.connect(func(): sig.emit())
	side_box.add_child(b)
	side_buttons.append(b)
	return b

func _build_side() -> void:
	side_box = VBoxContainer.new()
	side_box.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	side_box.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	side_box.grow_vertical = Control.GROW_DIRECTION_END
	side_box.offset_right = -24
	side_box.add_theme_constant_override("separation", 14)
	root.add_child(side_box)
	_side_button("res://icons/gear.svg", "Settings", settings_pressed)
	_side_button("res://icons/list.svg", "All books", books_pressed)
	_side_button("res://icons/pencil.svg", "Edit room or shelf", edit_pressed)
	var add := _side_button("res://icons/plus.svg", "Add a book", add_book_pressed)
	add.theme_type_variation = "AccentIconButton"

func _build_bottom() -> void:
	bottom_bar = PanelContainer.new()
	bottom_bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom_bar.offset_left = 24
	bottom_bar.offset_right = -24
	bottom_bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	root.add_child(bottom_bar)
	bottom_row = HBoxContainer.new()
	bottom_row.add_theme_constant_override("separation", 16)
	bottom_bar.add_child(bottom_row)
	tray_panel = PanelContainer.new()
	tray_panel.theme_type_variation = "Card"
	tray_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom_row.add_child(tray_panel)
	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", 6)
	tray_panel.add_child(tv)
	tray_hint = Label.new()
	tray_hint.theme_type_variation = "SmallLabel"
	tray_hint.text = "Tray"
	tv.add_child(tray_hint)
	tray_scroll = ScrollContainer.new()
	tray_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	tray_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tray_scroll.custom_minimum_size = Vector2(0, 200)
	tv.add_child(tray_scroll)
	tray_box = HBoxContainer.new()
	tray_box.add_theme_constant_override("separation", 12)
	tray_scroll.add_child(tray_box)
	back_btn = _icon_button("res://icons/back.svg", 52)
	back_btn.theme_type_variation = "AccentIconButton"
	back_btn.custom_minimum_size = Vector2(108, 108)
	back_btn.tooltip_text = "Back to room"
	back_btn.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	back_btn.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	back_btn.grow_vertical = Control.GROW_DIRECTION_BEGIN
	back_btn.offset_right = -24
	back_btn.pressed.connect(func(): back_pressed.emit())
	root.add_child(back_btn)

func _rebuild_actions() -> void:
	back_btn.visible = mode_shelf
	_layout()

func set_room_mode(room_name: String, subtitle: String, has_multiple: bool) -> void:
	mode_shelf = false
	title_lbl.text = room_name
	sub_lbl.text = subtitle
	prev_btn.disabled = not has_multiple
	next_btn.disabled = not has_multiple
	_rebuild_actions()
	refresh_tray()

func set_shelf_mode(shelf_name: String, subtitle: String, has_multiple: bool) -> void:
	mode_shelf = true
	title_lbl.text = shelf_name
	sub_lbl.text = subtitle
	prev_btn.disabled = not has_multiple
	next_btn.disabled = not has_multiple
	_rebuild_actions()
	refresh_tray()

# ---------------------------------------------------------------- tray

func refresh_tray() -> void:
	for c in tray_box.get_children():
		tray_box.remove_child(c)
		c.queue_free()
	var ids: Array = Library.get_tray()
	if not ids.has(placing_id):
		placing_id = ""
	for id in ids:
		var b := Library.get_book(id)
		if b.is_empty():
			continue
		tray_box.add_child(_make_chip(b, id == placing_id))
	tray_panel.visible = _drag_tray or mode_shelf or not ids.is_empty()
	bottom_bar.visible = tray_panel.visible
	if _drag_tray:
		tray_hint.text = "Drop here to move the book to the tray"
	elif ids.is_empty():
		tray_hint.text = "Tray · drag a book down here to carry it to another shelf"
	elif placing_id != "":
		tray_hint.text = "Tap a spot on the shelf to place the selected book"
	elif mode_shelf:
		tray_hint.text = "Tray · %d book%s · tap one, then tap the shelf" % [ids.size(), "" if ids.size() == 1 else "s"]
	else:
		tray_hint.text = "Tray · %d book%s waiting · open a shelf to place them" % [ids.size(), "" if ids.size() == 1 else "s"]
	tray_scroll.visible = not ids.is_empty()

func make_cover_widget(b: Dictionary, size: Vector2, font_size := 20) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = size
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tex := BookAPI.get_cover_texture(b)
	if tex != null:
		var tr := TextureRect.new()
		tr.texture = tex
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		tr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(tr)
	else:
		var col := Color.html(str(b.get("color", "#555555")))
		var cr := ColorRect.new()
		cr.color = col
		cr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(cr)
		var band := ColorRect.new()
		band.color = col.lightened(0.25)
		band.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
		band.offset_top = size.y * 0.12
		band.offset_bottom = size.y * 0.12 + 4
		band.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(band)
		var lb := Label.new()
		lb.text = str(b.get("title", ""))
		lb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lb.add_theme_font_override("font", sans_bold)
		lb.add_theme_font_size_override("font_size", font_size)
		lb.add_theme_color_override("font_color", Color(0.12, 0.09, 0.06) if col.get_luminance() > 0.5 else Color(0.96, 0.92, 0.82))
		lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lb.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 10)
		lb.clip_text = true
		lb.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		lb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(lb)
	return holder

func _make_chip(b: Dictionary, selected: bool) -> Control:
	var btn := Button.new()
	btn.theme_type_variation = "ChipButton"
	btn.custom_minimum_size = Vector2(130, 190)
	btn.clip_contents = true
	var inner := make_cover_widget(b, Vector2(114, 174))
	inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 8)
	btn.add_child(inner)
	if selected:
		var a := accent()
		btn.add_theme_stylebox_override("normal", _flat(Color(a.r, a.g, a.b, 0.35), 16, Vector2(0, 0), a, 5))
		btn.add_theme_stylebox_override("hover", _flat(Color(a.r, a.g, a.b, 0.4), 16, Vector2(0, 0), a, 5))
		btn.add_theme_stylebox_override("pressed", _flat(Color(a.r, a.g, a.b, 0.5), 16, Vector2(0, 0), a, 5))
	var id := str(b["id"])
	btn.pressed.connect(func(): tray_chip_pressed.emit(id))
	return btn

func set_placing(id: String) -> void:
	placing_id = id
	refresh_tray()

## Drop zone for dragged books: the whole bottom bar while a drag is in progress.
func tray_rect() -> Rect2:
	if _drag_tray:
		var r := bottom_bar.get_global_rect()
		r.position.y -= 40.0
		r.size.y += 40.0
		return r
	if not tray_panel.visible:
		return Rect2()
	return tray_panel.get_global_rect()

func set_tray_hover(on: bool) -> void:
	if on:
		var a := accent()
		tray_panel.add_theme_stylebox_override("panel", _flat(Color(a.r, a.g, a.b, 0.35), 20, Vector2(20, 16), a, 4))
	else:
		tray_panel.remove_theme_stylebox_override("panel")

func set_drag_tray(on: bool) -> void:
	_drag_tray = on
	refresh_tray()

# ---------------------------------------------------------------- toast

func _build_toast() -> void:
	toast_panel = PanelContainer.new()
	toast_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	toast_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	toast_panel.grow_vertical = Control.GROW_DIRECTION_END
	toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_panel.modulate.a = 0.0
	root.add_child(toast_panel)
	toast_lbl = Label.new()
	toast_lbl.theme_type_variation = "MutedLabel"
	toast_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	toast_lbl.custom_minimum_size = Vector2(700, 0)
	toast_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_panel.add_child(toast_lbl)

func toast(text: String, seconds := 2.6) -> void:
	toast_lbl.text = text
	toast_lbl.add_theme_color_override("font_color", fg())
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	toast_panel.modulate.a = 0.0
	_toast_tween = create_tween()
	_toast_tween.tween_property(toast_panel, "modulate:a", 1.0, 0.18)
	_toast_tween.tween_interval(seconds)
	_toast_tween.tween_property(toast_panel, "modulate:a", 0.0, 0.4)

# ---------------------------------------------------------------- sheets

func _build_sheet() -> void:
	dimmer = ColorRect.new()
	dimmer.color = Color(0, 0, 0, 0.5)
	dimmer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
	dimmer.visible = false
	dimmer.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.pressed:
			close_sheet())
	root.add_child(dimmer)
	sheet = PanelContainer.new()
	sheet.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	sheet.offset_left = 0
	sheet.offset_right = 0
	sheet.grow_vertical = Control.GROW_DIRECTION_BEGIN
	sheet.visible = false
	root.add_child(sheet)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	sheet.add_child(vb)
	var head := HBoxContainer.new()
	vb.add_child(head)
	sheet_title = Label.new()
	sheet_title.theme_type_variation = "HeadLabel"
	sheet_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sheet_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	head.add_child(sheet_title)
	var close := _icon_button("res://icons/close.svg", 36)
	close.custom_minimum_size = Vector2(84, 84)
	close.pressed.connect(close_sheet)
	head.add_child(close)
	sheet_scroll = ScrollContainer.new()
	sheet_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sheet_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(sheet_scroll)
	sheet_content = VBoxContainer.new()
	sheet_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sheet_content.add_theme_constant_override("separation", 14)
	sheet_scroll.add_child(sheet_content)

func open_sheet(title: String, height_frac := 0.55) -> VBoxContainer:
	for c in sheet_content.get_children():
		sheet_content.remove_child(c)
		c.queue_free()
	sheet_title.text = title
	var h := get_viewport().get_visible_rect().size.y * height_frac
	sheet.offset_top = 0
	sheet.offset_bottom = 0
	sheet_scroll.custom_minimum_size = Vector2(0, h - 140)
	sheet_scroll.scroll_vertical = 0
	dimmer.visible = true
	sheet.visible = true
	sheet.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(sheet, "modulate:a", 1.0, 0.15)
	return sheet_content

func close_sheet() -> void:
	dimmer.visible = false
	sheet.visible = false
	dialogs.on_closed()

func is_dialog_open() -> bool:
	return sheet.visible

# ---------------------------------------------------------------- widgets

func label(text: String, variation := "") -> Label:
	var l := Label.new()
	l.text = text
	if variation != "":
		l.theme_type_variation = variation
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l

func button(text: String, variation := "", min_h := 88.0) -> Button:
	var b := Button.new()
	b.text = text
	if variation != "":
		b.theme_type_variation = variation
	b.custom_minimum_size = Vector2(0, min_h)
	return b

func row(separation := 12) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", separation)
	return h

func spacer(h := 8.0) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c
