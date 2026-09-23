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
signal edit_room_pressed()
signal edit_view_pressed()
signal plan_band_changed()
signal edit_done_pressed()
signal furniture_picked(kind: String)
signal furniture_rotate_pressed()
signal furniture_place_pressed()
signal furniture_cancel_pressed()
signal furniture_remove_pressed()
signal place_prev_pressed()
signal place_next_pressed()
signal place_confirm_pressed()
signal place_cancel_pressed()

var main: Node
var style: Dictionary = {}
var root: Control
var top_bar: PanelContainer
var prev_btn: Button
var next_btn: Button
var top_prev: Button
var top_next: Button
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
var sheet_header_box: VBoxContainer
var dialogs: Dialogs

var sans: Font
var sans_bold: Font
var serif_bold: Font
var mode_shelf := false
var placing_id := ""
var placing_shelf := false
var editing := false
var edit_panel: PanelContainer
var edit_view_btn: Button
var edit_browse: VBoxContainer     # categories + the pieces in one
var edit_place_row: HBoxContainer  # rotate / place / cancel, while one is in hand
var edit_hint: Label
var edit_cat_box: HBoxContainer
var edit_item_box: HBoxContainer
var edit_place_btn: Button
var edit_remove_btn: Button
var edit_cat := "functional"
var thumbs: FurnitureThumbs
var _thumb_tiles: Dictionary = {}   # kind -> the tile waiting for its picture
var place_panel: PanelContainer
var place_where: Label
var place_count: Label
var place_warn: Label
var _has_multiple := false
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
	# has to exist before the editing bar, which asks it for its first pictures
	thumbs = FurnitureThumbs.new()
	add_child(thumbs)
	thumbs.ready_for.connect(_on_thumb)
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
	if thumbs != null:
		thumbs.set_style(st, str(Library.get_style_id()))
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

	# top-bar arrows: same panel colour and radius as the title bar
	th.set_type_variation("BarIconButton", "Button")
	th.set_stylebox("normal", "BarIconButton", _flat(bg(), 30, Vector2(0, 0)))
	th.set_stylebox("hover", "BarIconButton", _flat(bg().lightened(0.06), 30, Vector2(0, 0)))
	th.set_stylebox("pressed", "BarIconButton", _flat(bg().lightened(0.14), 30, Vector2(0, 0)))
	th.set_stylebox("disabled", "BarIconButton", _flat(bg(), 30, Vector2(0, 0)))
	th.set_stylebox("focus", "BarIconButton", empty)
	th.set_color("icon_normal_color", "BarIconButton", f)
	th.set_color("icon_hover_color", "BarIconButton", f)
	th.set_color("icon_pressed_color", "BarIconButton", f)
	th.set_color("icon_focus_color", "BarIconButton", f)
	th.set_color("icon_disabled_color", "BarIconButton", Color(f.r, f.g, f.b, 0.3))
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

	# action tiles (icon above label) and segmented chips
	for v in ["Tile", "AccentTile", "SegOn", "SegOff", "Link", "DangerLink"]:
		th.set_type_variation(v, "Button")
	th.set_stylebox("normal", "Tile", _flat(softer, 20, Vector2(10, 12)))
	th.set_stylebox("hover", "Tile", _flat(soft, 20, Vector2(10, 12)))
	th.set_stylebox("pressed", "Tile", _flat(Color(f.r, f.g, f.b, 0.2), 20, Vector2(10, 12)))
	th.set_stylebox("disabled", "Tile", _flat(Color(f.r, f.g, f.b, 0.03), 20, Vector2(10, 12)))
	th.set_font_size("font_size", "Tile", 23)
	th.set_constant("icon_max_width", "Tile", 40)
	th.set_constant("h_separation", "Tile", 6)
	th.set_color("icon_normal_color", "Tile", f)
	th.set_color("icon_hover_color", "Tile", f)
	th.set_color("icon_pressed_color", "Tile", f)
	th.set_color("icon_disabled_color", "Tile", Color(f.r, f.g, f.b, 0.3))
	th.set_stylebox("normal", "AccentTile", _flat(a, 20, Vector2(10, 12)))
	th.set_stylebox("hover", "AccentTile", _flat(a.lightened(0.08), 20, Vector2(10, 12)))
	th.set_stylebox("pressed", "AccentTile", _flat(a.darkened(0.2), 20, Vector2(10, 12)))
	th.set_font_size("font_size", "AccentTile", 23)
	th.set_font("font", "AccentTile", sans_bold)
	th.set_constant("h_separation", "AccentTile", 6)
	th.set_color("font_color", "AccentTile", on_accent())
	th.set_color("font_hover_color", "AccentTile", on_accent())
	th.set_color("font_pressed_color", "AccentTile", on_accent())
	th.set_color("icon_normal_color", "AccentTile", on_accent())
	th.set_color("icon_hover_color", "AccentTile", on_accent())
	th.set_color("icon_pressed_color", "AccentTile", on_accent())
	th.set_stylebox("normal", "SegOff", _flat(softer, 40, Vector2(22, 8)))
	th.set_stylebox("hover", "SegOff", _flat(soft, 40, Vector2(22, 8)))
	th.set_stylebox("pressed", "SegOff", _flat(soft, 40, Vector2(22, 8)))
	th.set_font_size("font_size", "SegOff", 26)
	th.set_stylebox("normal", "SegOn", _flat(a, 40, Vector2(22, 8)))
	th.set_stylebox("hover", "SegOn", _flat(a, 40, Vector2(22, 8)))
	th.set_stylebox("pressed", "SegOn", _flat(a, 40, Vector2(22, 8)))
	th.set_font_size("font_size", "SegOn", 26)
	th.set_font("font", "SegOn", sans_bold)
	th.set_color("font_color", "SegOn", on_accent())
	th.set_color("font_hover_color", "SegOn", on_accent())
	th.set_color("font_pressed_color", "SegOn", on_accent())
	th.set_stylebox("normal", "Link", _flat(Color(0, 0, 0, 0), 12, Vector2(10, 4)))
	th.set_stylebox("hover", "Link", _flat(softer, 12, Vector2(10, 4)))
	th.set_stylebox("pressed", "Link", _flat(soft, 12, Vector2(10, 4)))
	th.set_font_size("font_size", "Link", 26)
	th.set_color("font_color", "Link", mu)
	th.set_color("font_hover_color", "Link", f)
	th.set_color("font_pressed_color", "Link", f)
	th.set_stylebox("normal", "DangerLink", _flat(Color(0, 0, 0, 0), 12, Vector2(10, 4)))
	th.set_stylebox("hover", "DangerLink", _flat(Color(0.72, 0.22, 0.2, 0.15), 12, Vector2(10, 4)))
	th.set_stylebox("pressed", "DangerLink", _flat(Color(0.72, 0.22, 0.2, 0.3), 12, Vector2(10, 4)))
	th.set_font_size("font_size", "DangerLink", 26)
	th.set_color("font_color", "DangerLink", Color(0.90, 0.42, 0.38))
	th.set_color("font_hover_color", "DangerLink", Color(0.95, 0.5, 0.45))
	th.set_color("font_pressed_color", "DangerLink", Color(0.95, 0.5, 0.45))
	th.set_stylebox("normal", "DangerButton", _flat(Color(0.72, 0.22, 0.20)))
	th.set_stylebox("hover", "DangerButton", _flat(Color(0.78, 0.26, 0.24)))
	th.set_stylebox("pressed", "DangerButton", _flat(Color(0.55, 0.16, 0.15)))
	th.set_color("font_color", "DangerButton", Color.WHITE)
	th.set_color("font_hover_color", "DangerButton", Color.WHITE)
	th.set_color("font_pressed_color", "DangerButton", Color.WHITE)

	th.set_stylebox("normal", "GhostButton", _flat(Color(0, 0, 0, 0), 18, Vector2(12, 6)))
	th.set_stylebox("hover", "GhostButton", _flat(softer, 18, Vector2(12, 6)))
	th.set_stylebox("pressed", "GhostButton", _flat(soft, 18, Vector2(12, 6)))

	# CardButton is the transparent tap layer on top of a CardRow (the Card panel draws the background)
	th.set_stylebox("normal", "CardButton", _flat(Color(0, 0, 0, 0), 20, Vector2(0, 0)))
	th.set_stylebox("hover", "CardButton", _flat(softer, 20, Vector2(0, 0)))
	th.set_stylebox("pressed", "CardButton", _flat(Color(f.r, f.g, f.b, 0.14), 20, Vector2(0, 0)))
	th.set_stylebox("focus", "CardButton", empty)

	th.set_stylebox("panel", "PanelContainer", _flat(bg(), 30, Vector2(22, 18)))
	th.set_type_variation("Card", "PanelContainer")
	th.set_stylebox("panel", "Card", _flat(softer, 20, Vector2(20, 16)))
	th.set_type_variation("AccentCard", "PanelContainer")
	th.set_stylebox("panel", "AccentCard", _flat(Color(a.r, a.g, a.b, 0.18), 20, Vector2(20, 16), a, 3))

	th.set_color("font_color", "Label", f)
	for v in ["TitleLabel", "SubLabel", "HeadLabel", "SmallLabel", "MutedLabel", "SectionLabel"]:
		th.set_type_variation(v, "Label")
	th.set_font("font", "SectionLabel", sans_bold)
	th.set_font_size("font_size", "SectionLabel", 24)
	th.set_color("font_color", "SectionLabel", a)
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
	th.set_font_size("font_size", "OptionButton", 30)
	th.set_constant("h_separation", "OptionButton", 14)
	var popup_bg := Color(bg().r, bg().g, bg().b, 1.0)
	th.set_stylebox("panel", "PopupMenu", _flat(popup_bg, 20, Vector2(12, 14), Color(f.r, f.g, f.b, 0.15), 2))
	th.set_stylebox("hover", "PopupMenu", _flat(Color(a.r, a.g, a.b, 0.3), 14, Vector2(16, 10)))
	th.set_color("font_color", "PopupMenu", f)
	th.set_color("font_hover_color", "PopupMenu", f)
	th.set_font_size("font_size", "PopupMenu", 32)
	th.set_constant("v_separation", "PopupMenu", 30)
	th.set_constant("item_start_padding", "PopupMenu", 26)
	th.set_constant("item_end_padding", "PopupMenu", 26)

	th.set_stylebox("background", "ProgressBar", _flat(soft, 8, Vector2(0, 0)))
	th.set_stylebox("fill", "ProgressBar", _flat(a, 8, Vector2(0, 0)))
	th.set_stylebox("panel", "ScrollContainer", empty)

	th.set_color("icon_normal_color", "IconButton", f)
	th.set_color("icon_hover_color", "IconButton", f)
	th.set_color("icon_pressed_color", "IconButton", f)
	th.set_color("icon_focus_color", "IconButton", f)
	root.theme = th
	# The placement bar sits over the open room, including the bright rug, so it gets an
	# opaque back of its own rather than the translucent card the tray can afford.
	var solid := bg()
	var solid_box := _flat(Color(solid.r, solid.g, solid.b, 0.97), 24, Vector2(24, 18))
	if place_panel != null:
		place_panel.add_theme_stylebox_override("panel", solid_box)
	# the inventory stands over the room itself in room view, where a translucent card
	# leaves the pieces to be read against the floorboards
	if edit_panel != null:
		edit_panel.add_theme_stylebox_override("panel", solid_box)
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
	_bottom_inset = bottom_inset
	_top_inset = top_inset
	top_bar.offset_top = top_inset + 24
	top_bar.offset_bottom = top_inset + 24
	# arrows are panels of the same height as the title bar, standing beside it
	var bar_h := top_bar.get_combined_minimum_size().y
	var arrow_w := 112.0
	top_bar.offset_left = 24 + arrow_w + 14
	top_bar.offset_right = -(24 + arrow_w + 14)
	top_prev.position = Vector2(24, top_inset + 24)
	top_prev.size = Vector2(arrow_w, bar_h)
	top_next.position = Vector2(canvas_size.x - 24 - arrow_w, top_inset + 24)
	top_next.size = Vector2(arrow_w, bar_h)
	bottom_bar.offset_bottom = -(bottom_inset + 24)
	bottom_bar.offset_right = -(24 + 108 + 16) if mode_shelf else -24
	if place_panel != null:
		place_panel.offset_bottom = -(bottom_inset + 24)
	if edit_panel != null:
		edit_panel.offset_bottom = -(bottom_inset + 24)
	back_btn.offset_bottom = -(bottom_inset + 24)
	toast_panel.offset_top = top_inset + 190
	side_box.offset_top = top_inset + 24 + top_bar.get_combined_minimum_size().y + 18
	plan_band_changed.emit()

## The strip of screen the floor plan has to itself: under the title bar, over the
## editing bar. The plan is framed to this, so the whole room is on screen whatever
## shape the phone is and whatever the bars take.
##
## The bar is measured at its tallest — the inventory open — even while a piece is in
## hand and the shorter place row is showing, so the map does not jump a size every time
## something is picked up.
##
## Both bars are measured by what they actually cover, not by what they ask for: a label
## that wraps reports a wild height until it has been given its width, and the plan would
## otherwise be framed around a bar the size of the screen.
func plan_band() -> Vector2:
	var h: float = get_viewport().get_visible_rect().size.y
	var top := _top_inset + 24.0 + _height_of(top_bar) + 18.0
	var bar := edit_panel.size.y
	if bar > 1.0 and edit_browse.visible:
		_plan_bar_h = bar
	bar = maxf(bar, _plan_bar_h)
	return Vector2(top, maxf(top, h - (_bottom_inset + 24.0 + bar + 18.0)))

## What a bar covers on screen, falling back to what it asks for before it is laid out.
func _height_of(c: Control) -> float:
	return c.size.y if c.size.y > 1.0 else c.get_combined_minimum_size().y

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
	title_btn = Button.new()
	title_btn.theme_type_variation = "GhostButton"
	title_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_btn.custom_minimum_size = Vector2(0, 96)
	title_btn.pressed.connect(func():
		if not editing:
			title_pressed.emit())
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
	# arrow buttons standing left and right of the title panel (positioned in _layout)
	top_prev = _icon_button("res://icons/chevron_left.svg", 44)
	top_prev.theme_type_variation = "BarIconButton"
	top_prev.pressed.connect(func(): prev_pressed.emit())
	root.add_child(top_prev)
	top_next = _icon_button("res://icons/chevron_right.svg", 44)
	top_next.theme_type_variation = "BarIconButton"
	top_next.pressed.connect(func(): next_pressed.emit())
	root.add_child(top_next)
	# the same navigation again as bare chevrons at mid-height on the screen edges
	prev_btn = _nav_chevron("res://icons/chevron_left.svg", Control.PRESET_CENTER_LEFT)
	prev_btn.pressed.connect(func(): prev_pressed.emit())
	next_btn = _nav_chevron("res://icons/chevron_right.svg", Control.PRESET_CENTER_RIGHT)
	next_btn.pressed.connect(func(): next_pressed.emit())

func _nav_chevron(icon_path: String, preset: int) -> Button:
	var b := Button.new()
	b.theme_type_variation = "GhostButton"
	b.icon = load(icon_path)
	b.expand_icon = true
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	b.add_theme_constant_override("icon_max_width", 72)
	b.custom_minimum_size = Vector2(120, 260)
	b.modulate = Color(1, 1, 1, 0.28)
	b.focus_mode = Control.FOCUS_NONE
	b.set_anchors_and_offsets_preset(preset)
	b.offset_top = -130
	b.offset_bottom = 130
	if preset == Control.PRESET_CENTER_LEFT:
		b.offset_left = 4
		b.offset_right = 124
	else:
		b.offset_left = -124
		b.offset_right = -4
	root.add_child(b)
	return b

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
	tray_hint.text = tr("Tray")
	tray_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tray_hint.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tray_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tv.add_child(tray_hint)
	tray_scroll = ScrollContainer.new()
	tray_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	tray_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tray_scroll.custom_minimum_size = Vector2(0, 200)
	tv.add_child(tray_scroll)
	watch_scroll(tray_scroll)
	tray_box = HBoxContainer.new()
	tray_box.add_theme_constant_override("separation", 12)
	tray_box.mouse_filter = Control.MOUSE_FILTER_PASS
	tray_scroll.add_child(tray_box)
	back_btn = _icon_button("res://icons/back.svg", 52)
	back_btn.theme_type_variation = "AccentIconButton"
	back_btn.custom_minimum_size = Vector2(108, 108)
	back_btn.tooltip_text = tr("Back to room")
	back_btn.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	back_btn.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	back_btn.grow_vertical = Control.GROW_DIRECTION_BEGIN
	back_btn.offset_right = -24
	back_btn.pressed.connect(func(): back_pressed.emit())
	root.add_child(back_btn)
	_build_place_bar()
	_build_edit_bar()

## Bar shown while a see-through shelf is standing on a candidate spot: step through the
## free spots with the arrows, then commit. Sits where the tray normally is.
func _build_place_bar() -> void:
	place_panel = PanelContainer.new()
	place_panel.theme_type_variation = "Card"
	place_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	place_panel.offset_left = 24
	place_panel.offset_right = -24
	place_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	place_panel.visible = false
	root.add_child(place_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	place_panel.add_child(v)
	place_where = Label.new()
	place_where.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(place_where)
	place_count = Label.new()
	place_count.theme_type_variation = "SmallLabel"
	place_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(place_count)
	place_warn = Label.new()
	place_warn.theme_type_variation = "SmallLabel"
	place_warn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	place_warn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	place_warn.visible = false
	v.add_child(place_warn)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	v.add_child(h)
	var prev := _icon_button("res://icons/chevron_left.svg", 44)
	prev.custom_minimum_size = Vector2(110, 96)
	prev.tooltip_text = tr("Previous spot")
	prev.pressed.connect(func(): place_prev_pressed.emit())
	h.add_child(prev)
	var place := button(tr("Place shelf"), "AccentButton", 96)
	place.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	place.pressed.connect(func(): place_confirm_pressed.emit())
	h.add_child(place)
	var nxt := _icon_button("res://icons/chevron_right.svg", 44)
	nxt.custom_minimum_size = Vector2(110, 96)
	nxt.tooltip_text = tr("Next spot")
	nxt.pressed.connect(func(): place_next_pressed.emit())
	h.add_child(nxt)
	var cancel := button(tr("Cancel"), "GhostButton", 72)
	cancel.pressed.connect(func(): place_cancel_pressed.emit())
	v.add_child(cancel)

## Bar shown while a room is being furnished: switch between the plan and standing in
## the room, and finish. Sits where the tray normally is.
func _build_edit_bar() -> void:
	edit_panel = PanelContainer.new()
	edit_panel.theme_type_variation = "Card"
	edit_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	edit_panel.offset_left = 24
	edit_panel.offset_right = -24
	edit_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	edit_panel.visible = false
	# the plan is framed around this bar, so a change of height reframes it
	edit_panel.resized.connect(func(): plan_band_changed.emit())
	root.add_child(edit_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	edit_panel.add_child(v)

	edit_hint = Label.new()
	edit_hint.theme_type_variation = "SmallLabel"
	edit_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	edit_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(edit_hint)

	# the inventory: a row of categories over the pieces in the one that is open
	edit_browse = VBoxContainer.new()
	edit_browse.add_theme_constant_override("separation", 8)
	v.add_child(edit_browse)
	edit_cat_box = _scroller(edit_browse, 74)
	edit_item_box = _scroller(edit_browse, 190)

	# what replaces the inventory once a piece is in hand
	edit_place_row = HBoxContainer.new()
	edit_place_row.add_theme_constant_override("separation", 12)
	edit_place_row.visible = false
	v.add_child(edit_place_row)
	var rot := _icon_button("res://icons/refresh.svg", 40)
	rot.custom_minimum_size = Vector2(104, 92)
	rot.tooltip_text = tr("Turn")
	rot.pressed.connect(func(): furniture_rotate_pressed.emit())
	edit_place_row.add_child(rot)
	edit_place_btn = button(tr("Place"), "AccentButton", 92)
	edit_place_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit_place_btn.pressed.connect(func(): furniture_place_pressed.emit())
	edit_place_row.add_child(edit_place_btn)
	edit_remove_btn = _icon_button("res://icons/trash.svg", 40)
	edit_remove_btn.custom_minimum_size = Vector2(104, 92)
	edit_remove_btn.tooltip_text = tr("Remove")
	edit_remove_btn.pressed.connect(func(): furniture_remove_pressed.emit())
	edit_place_row.add_child(edit_remove_btn)
	var cancel := _icon_button("res://icons/close.svg", 38)
	cancel.custom_minimum_size = Vector2(104, 92)
	cancel.tooltip_text = tr("Cancel")
	cancel.pressed.connect(func(): furniture_cancel_pressed.emit())
	edit_place_row.add_child(cancel)

	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	v.add_child(h)
	edit_view_btn = button(tr("Room view"), "GhostButton", 88)
	edit_view_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit_view_btn.pressed.connect(func(): edit_view_pressed.emit())
	h.add_child(edit_view_btn)
	var done := button(tr("Done"), "AccentButton", 88)
	done.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	done.pressed.connect(func(): edit_done_pressed.emit())
	h.add_child(done)
	_rebuild_inventory()

## A row that scrolls sideways when it holds more than fits.
func _scroller(parent: Control, height: float) -> HBoxContainer:
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.custom_minimum_size = Vector2(0, height)
	parent.add_child(sc)
	watch_scroll(sc)
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.mouse_filter = Control.MOUSE_FILTER_PASS
	sc.add_child(box)
	return box

## A finger laid on a button is a press the button keeps to itself, which leaves the row
## under it nothing to follow: the row does not scroll. Buttons in a scrolling row are
## therefore set to pass the touch on as well.
func scrollable(c: Control) -> Control:
	c.mouse_filter = Control.MOUSE_FILTER_PASS
	return c

## The row is then dragged by hand, one to one with the finger, and remembers when it
## last moved so that the drag does not also count as a tap on whatever button the finger
## came to rest on.
func watch_scroll(sc: ScrollContainer) -> void:
	sc.get_h_scroll_bar().value_changed.connect(func(_v): _scrolled_at = Time.get_ticks_msec())
	sc.get_v_scroll_bar().value_changed.connect(func(_v): _scrolled_at = Time.get_ticks_msec())
	sc.gui_input.connect(func(e: InputEvent): _drag_row(sc, e))

func _drag_row(sc: ScrollContainer, event: InputEvent) -> void:
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		_touch_input = true   # from here on the mouse is only an echo of the finger
	var by := 0.0
	if event is InputEventScreenDrag:
		by = (event as InputEventScreenDrag).relative.x
	elif event is InputEventMouseMotion and not _touch_input:
		var mm := event as InputEventMouseMotion
		if mm.button_mask & MOUSE_BUTTON_MASK_LEFT:
			by = mm.relative.x
	if absf(by) < 0.5:
		return
	var before := sc.scroll_horizontal
	sc.scroll_horizontal = before - int(round(by))
	if sc.scroll_horizontal != before:
		_scrolled_at = Time.get_ticks_msec()

## True right after a row has moved under the finger, tap or no tap.
func just_scrolled() -> bool:
	return Time.get_ticks_msec() - _scrolled_at < 220

## The categories, and the pieces in whichever one is open.
func _rebuild_inventory() -> void:
	for c in edit_cat_box.get_children():
		edit_cat_box.remove_child(c)
		c.queue_free()
	for c in edit_item_box.get_children():
		edit_item_box.remove_child(c)
		c.queue_free()
	for entry in Furniture.CATEGORIES:
		var cat := str(entry[0])
		var b := button(tr(str(entry[1])), "AccentButton" if cat == edit_cat else "GhostButton", 62)
		b.custom_minimum_size.x = 0
		b.pressed.connect(func():
			if just_scrolled():
				return
			edit_cat = cat
			_rebuild_inventory())
		edit_cat_box.add_child(scrollable(b))
	_thumb_tiles.clear()
	var kinds := Furniture.in_category(edit_cat)
	for kind in kinds:
		var b := button(tr(Furniture.display_name(kind)), "Tile", 176)
		b.custom_minimum_size = Vector2(176, 176)
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.clip_text = true
		b.expand_icon = true
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		b.add_theme_constant_override("icon_max_width", 112)
		b.alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.pressed.connect(func():
			if just_scrolled():
				return
			furniture_picked.emit(kind))
		edit_item_box.add_child(scrollable(b))
		_thumb_tiles[kind] = b
	if thumbs != null:
		thumbs.request(kinds)

## A picture has come back from the thumbnail viewport; put it on its tile, if that tile
## is still the one on screen.
func _on_thumb(kind: String, tex: Texture2D) -> void:
	var b = _thumb_tiles.get(kind)
	if b is Button and is_instance_valid(b):
		b.icon = tex

## Turns the furnishing interface on. The title bar keeps naming the room, so the reader
## can still see which one they are arranging.
func set_editing(on: bool, room_name := "", subtitle := "", top_view := true) -> void:
	editing = on
	edit_panel.visible = on
	if on:
		# the bar is built before the style is known, so the pictures are asked for here
		_rebuild_inventory()
		title_lbl.text = room_name
		sub_lbl.text = subtitle
		edit_view_btn.text = tr("Room view") if top_view else tr("Plan view")
	_rebuild_actions()
	refresh_tray()

## Swaps the inventory for the rotate / place / remove row while a piece is in hand.
## `held` is "" when nothing is, `can_place` drives whether Place is offered at all, and
## `can_remove` is on for a piece already standing in the room rather than a new one.
func set_holding(held: String, can_place := true, can_remove := false, hint := "") -> void:
	var busy := held != ""
	edit_browse.visible = not busy
	edit_place_row.visible = busy
	edit_remove_btn.visible = can_remove
	edit_place_btn.disabled = not can_place
	edit_place_btn.text = tr("Place") if not can_remove else tr("Move here")
	edit_hint.text = hint
	edit_hint.visible = hint != ""
	edit_hint.add_theme_color_override("font_color", accent() if busy and not can_place else muted())
	_layout()

func set_placing_shelf(on: bool) -> void:
	placing_shelf = on
	place_panel.visible = on
	# refresh_tray owns the bottom bar, so it has to re-run to pick the mode up.
	refresh_tray()
	_rebuild_actions()

func set_place_info(where: String, count: String, warn := "") -> void:
	place_where.text = where
	place_count.text = count
	place_warn.text = warn
	place_warn.visible = warn != ""
	place_warn.add_theme_color_override("font_color", accent())

func _rebuild_actions() -> void:
	# While a spot is being chosen the placement bar is the only chrome on screen: the
	# room title, its arrows and the side actions would all navigate away mid-placement.
	var idle := not placing_shelf and not editing
	back_btn.visible = mode_shelf and idle
	# The bottom bar is left to refresh_tray, which hides it when there is nothing to
	# show. Forcing it visible here brought back an empty bar after cancelling.
	side_box.visible = idle
	# the title keeps naming the room being furnished, but its arrows would walk away from it
	top_bar.visible = idle or editing
	top_prev.visible = idle
	top_next.visible = idle
	prev_btn.visible = _has_multiple and idle
	next_btn.visible = _has_multiple and idle
	_layout()

func set_room_mode(room_name: String, subtitle: String, has_multiple: bool) -> void:
	mode_shelf = false
	_has_multiple = has_multiple
	title_lbl.text = room_name
	sub_lbl.text = subtitle
	prev_btn.visible = has_multiple
	next_btn.visible = has_multiple
	top_prev.disabled = not has_multiple
	top_next.disabled = not has_multiple
	_rebuild_actions()
	refresh_tray()

func set_shelf_mode(shelf_name: String, subtitle: String, has_multiple: bool) -> void:
	mode_shelf = true
	_has_multiple = has_multiple
	title_lbl.text = shelf_name
	sub_lbl.text = subtitle
	prev_btn.visible = has_multiple
	next_btn.visible = has_multiple
	top_prev.disabled = not has_multiple
	top_next.disabled = not has_multiple
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
	tray_panel.visible = not placing_shelf and not editing and (_drag_tray or mode_shelf or not ids.is_empty())
	bottom_bar.visible = tray_panel.visible
	# with no books the bar is just the hint; match the floating back button's height
	bottom_bar.custom_minimum_size = Vector2(0, 108 if ids.is_empty() else 0)
	if _drag_tray:
		tray_hint.text = tr("Drop here to move the book to the tray")
	elif ids.is_empty():
		tray_hint.text = tr("Tray · drag a book down here to carry it to another shelf")
	elif placing_id != "":
		tray_hint.text = tr("Tap a spot on the shelf to place the selected book")
	elif mode_shelf:
		tray_hint.text = tr("Tray · %s · tap one, then tap the shelf") % ((tr("1 book") if ids.size() == 1 else tr("%d books") % ids.size()))
	else:
		tray_hint.text = tr("Tray · %s waiting · open a shelf to place them") % ((tr("1 book") if ids.size() == 1 else tr("%d books") % ids.size()))
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
	btn.set_meta("book_id", id)
	btn.pressed.connect(func():
		if just_scrolled():
			return
		tray_chip_pressed.emit(id))
	return scrollable(btn)

func _chip_for(id: String) -> Control:
	for c in tray_box.get_children():
		if c is Control and c.has_meta("book_id") and str(c.get_meta("book_id")) == id:
			return c
	return null

## Where a book flying into the tray should land: the middle of its own chip once the
## tray has laid out, or the near end of the tray until then.
func tray_chip_center(id: String) -> Vector2:
	var c := _chip_for(id)
	if c != null and c.size.x > 1.0:
		return c.get_global_rect().get_center()
	var r := tray_rect()
	if r.size.x <= 0.0:
		return Vector2.ZERO
	return Vector2(r.position.x + 90.0, r.get_center().y)

## Grows the chip in as the 3D book reaches it, so the book appears to become the chip.
func pop_chip(id: String, duration := 0.3) -> void:
	var c := _chip_for(id)
	if c == null:
		return
	c.pivot_offset = c.size / 2.0
	c.scale = Vector2(0.25, 0.25)
	c.modulate.a = 0.0
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(duration * 0.5)
	tw.tween_property(c, "scale", Vector2.ONE, duration * 0.55)
	tw.parallel().tween_property(c, "modulate:a", 1.0, duration * 0.35)

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
	text = tr(text)
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
	sheet_header_box = VBoxContainer.new()
	sheet_header_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sheet_header_box.add_theme_constant_override("separation", 14)
	sheet_header_box.visible = false
	vb.add_child(sheet_header_box)
	sheet_scroll = ScrollContainer.new()
	sheet_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sheet_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(sheet_scroll)
	# a margin below the last row so lists never end flush with the sheet edge
	var pad := MarginContainer.new()
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pad.add_theme_constant_override("margin_bottom", 28)
	pad.add_theme_constant_override("margin_right", 6)
	sheet_scroll.add_child(pad)
	sheet_content = VBoxContainer.new()
	sheet_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sheet_content.add_theme_constant_override("separation", 14)
	pad.add_child(sheet_content)

var _sheet_max_h := 400.0
var _sheet_fixed := false
var _kb_h := 0.0
var _bottom_inset := 0.0
var _top_inset := 0.0
var _plan_bar_h := 0.0   # the editing bar at its tallest, for framing the plan
var _scrolled_at := -10000   # when a scrolling row last moved, in milliseconds
var _touch_input := false    # a finger is driving, so the emulated mouse is ignored

func open_sheet(title: String, height_frac := 0.55, fixed_height := false) -> VBoxContainer:
	for c in sheet_content.get_children():
		sheet_content.remove_child(c)
		c.queue_free()
	for c in sheet_header_box.get_children():
		sheet_header_box.remove_child(c)
		c.queue_free()
	sheet_header_box.visible = false
	_sheet_fixed = fixed_height
	sheet_title.text = tr(title)
	var h := get_viewport().get_visible_rect().size.y * height_frac
	sheet.offset_top = 0
	sheet.offset_bottom = 0
	_sheet_max_h = h - 140
	_kb_h = -1.0
	_fit_sheet()
	sheet_scroll.scroll_vertical = 0
	dimmer.visible = true
	sheet.visible = true
	sheet.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(sheet, "modulate:a", 1.0, 0.15)
	return sheet_content

## Rows that stay put while the rest of the sheet scrolls: search fields, filters, counts.
func sheet_header() -> VBoxContainer:
	sheet_header_box.visible = true
	return sheet_header_box

## Sheets size to their content: no empty space below short menus, a scrollbar for long ones.
## height_frac from open_sheet is the maximum. On phones the on-screen keyboard slides over the
## sheet, so the sheet is lifted by the keyboard height and its maximum shrinks accordingly.
func _fit_sheet() -> void:
	var win_h := float(DisplayServer.window_get_size().y)
	var canvas_h := get_viewport().get_visible_rect().size.y
	var kb := float(DisplayServer.virtual_keyboard_get_height()) * (canvas_h / maxf(1.0, win_h))
	var kb_changed := absf(kb - _kb_h) >= 1.0
	_kb_h = kb
	var lift := maxf(kb, _bottom_inset)
	if absf(sheet.offset_bottom + lift) >= 0.5:
		sheet.offset_bottom = -lift
	var room := canvas_h - lift - 260.0
	var head_h := 0.0
	if sheet_header_box.visible:
		head_h = sheet_header_box.get_combined_minimum_size().y + 14.0
	var content_h := sheet_content.get_combined_minimum_size().y + 28.0
	# fixed_height sheets keep the tallest size they are allowed, so filtering a list
	# never resizes the sheet under the reader's thumb
	var cap := minf(_sheet_max_h, room) - head_h
	var want := clampf(cap if _sheet_fixed else minf(content_h, _sheet_max_h - head_h), 120.0, maxf(120.0, room - head_h))
	if absf(sheet_scroll.custom_minimum_size.y - want) >= 0.5:
		sheet_scroll.custom_minimum_size = Vector2(0, want)
	if kb_changed and kb > 0.0:
		var f := get_viewport().gui_get_focus_owner()
		if f != null and sheet_scroll.is_ancestor_of(f):
			(func(): sheet_scroll.ensure_control_visible(f)).call_deferred()

func _process(_delta: float) -> void:
	if sheet.visible:
		_fit_sheet()

func close_sheet() -> void:
	dimmer.visible = false
	sheet.visible = false
	dialogs.on_closed()

func is_dialog_open() -> bool:
	return sheet.visible

# ---------------------------------------------------------------- widgets

func label(text: String, variation := "") -> Label:
	var l := Label.new()
	l.text = tr(text)
	if variation != "":
		l.theme_type_variation = variation
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l

func button(text: String, variation := "", min_h := 88.0) -> Button:
	var b := Button.new()
	b.text = tr(text)
	if variation != "":
		b.theme_type_variation = variation
	b.custom_minimum_size = Vector2(0, min_h)
	return b

## A titled card grouping related controls. Returns the VBox to fill.
func section(parent: Control, title: String, hint := "") -> VBoxContainer:
	var card := PanelContainer.new()
	card.theme_type_variation = "Card"
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	if title != "":
		var t := label(title, "SectionLabel")
		v.add_child(t)
	if hint != "":
		v.add_child(label(hint, "SubLabel"))
	card.add_child(v)
	parent.add_child(card)
	return v

## Grid of icon-over-label action tiles. actions: [{"label", "icon", "cb", "accent"(bool), "disabled"(bool)}]
func tiles(parent: Control, actions: Array, columns := 4) -> GridContainer:
	var g := GridContainer.new()
	g.columns = columns
	g.add_theme_constant_override("h_separation", 10)
	g.add_theme_constant_override("v_separation", 10)
	for a in actions:
		var b := Button.new()
		b.theme_type_variation = "AccentTile" if bool(a.get("accent", false)) else "Tile"
		b.text = tr(str(a.get("label", "")))
		if a.has("icon"):
			b.icon = load("res://icons/%s.svg" % str(a["icon"]))
			b.expand_icon = true
			b.add_theme_constant_override("icon_max_width", 40)
			b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
			b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		b.alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.clip_text = true
		b.custom_minimum_size = Vector2(0, 124)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.disabled = bool(a.get("disabled", false))
		b.focus_mode = Control.FOCUS_NONE
		if a.has("cb"):
			b.pressed.connect(a["cb"])
		g.add_child(b)
	parent.add_child(g)
	return g

## Row of exclusive chips. options: [[key, label], ...]; cb(key). Returns the container.
func segmented(parent: Control, options: Array, current: Variant, cb: Callable, wrap := false) -> Container:
	var box: Container = HFlowContainer.new() if wrap else HBoxContainer.new()
	box.add_theme_constant_override("h_separation" if wrap else "separation", 8)
	if wrap:
		box.add_theme_constant_override("v_separation", 8)
	var buttons: Array = []
	for o in options:
		var b := Button.new()
		b.text = tr(str(o[1]))
		b.toggle_mode = true
		b.button_pressed = o[0] == current
		b.theme_type_variation = "SegOn" if b.button_pressed else "SegOff"
		b.custom_minimum_size = Vector2(0, 76)
		b.focus_mode = Control.FOCUS_NONE
		if not wrap:
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		buttons.append(b)
		var key = o[0]
		b.pressed.connect(func():
			for other in buttons:
				other.button_pressed = other == b
				other.theme_type_variation = "SegOn" if other == b else "SegOff"
			cb.call(key))
		box.add_child(b)
	parent.add_child(box)
	return box

## Quiet text action for secondary or destructive things (no big bar).
func link(parent: Control, text: String, cb: Callable, danger := false) -> Button:
	var b := Button.new()
	b.text = tr(text)
	b.theme_type_variation = "DangerLink" if danger else "Link"
	b.custom_minimum_size = Vector2(0, 64)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(cb)
	parent.add_child(b)
	return b

## Horizontal row of quiet links, centred.
func links(parent: Control, items: Array) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 26)
	for it in items:
		link(h, str(it[0]), it[1], bool(it[2]) if it.size() > 2 else false)
	parent.add_child(h)
	return h

func row(separation := 12) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", separation)
	return h

func spacer(h := 8.0) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c
