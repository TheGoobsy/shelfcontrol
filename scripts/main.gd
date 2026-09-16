extends Node3D
## App root: owns the room, camera and HUD; routes touch input by mode.

enum Mode { ROOM, SHELF }

const ROOM_PIVOT := Vector3(0, 1.5, 0.3)
const ROOM_ORBIT := 1.7
const ROOM_FOV := 78.0
const SHELF_FOV := 58.0
const TAP_SLOP := 16.0

var mode: Mode = Mode.ROOM
var room_index := 0
var room3d: Room3D
var rig: CameraRig
var hud: HUD
var fade: ColorRect
var style: Dictionary = {}

var yaw := 0.0
var pitch := -0.02

var active_shelf: Shelf3D
var shelf_zoom := 1.0
var shelf_pan := Vector2.ZERO

var pressing := false
var press_pos := Vector2.ZERO
var last_pos := Vector2.ZERO
var drag_started := false
var camera_dragging := false
var press_book := ""
var drag_book: Book3D
var drag_row := -1
var drag_index := -1
var drag_fits := true
var drag_over_tray := false
var _last_preview := ""
var _night_now := false
var _last_tap_time := 0
var _last_tap_pos := Vector2.ZERO

var demo := false
var shot_path := ""
var shot_mode := ""
var shot_style := ""

func _ready() -> void:
	_parse_args()
	rig = CameraRig.new()
	add_child(rig)
	room3d = Room3D.new()
	add_child(room3d)
	hud = HUD.new()
	add_child(hud)
	hud.setup(self)
	var fade_layer := CanvasLayer.new()
	fade_layer.layer = 20
	add_child(fade_layer)
	fade = ColorRect.new()
	fade.color = Color.BLACK
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade.modulate.a = 0.0
	fade_layer.add_child(fade)

	hud.prev_pressed.connect(func(): _step(-1))
	hud.next_pressed.connect(func(): _step(1))
	hud.back_pressed.connect(exit_shelf)
	hud.add_book_pressed.connect(func(): hud.dialogs.open_add_book())
	hud.import_pressed.connect(func(): hud.dialogs.open_import())
	hud.style_pressed.connect(func(): hud.dialogs.open_style())
	hud.room_menu_pressed.connect(func(): hud.dialogs.open_room_menu())
	hud.shelf_menu_pressed.connect(func():
		if active_shelf:
			hud.dialogs.open_shelf_menu(active_shelf.shelf_id))
	hud.title_pressed.connect(func():
		if mode == Mode.SHELF and active_shelf:
			hud.dialogs.open_shelf_menu(active_shelf.shelf_id)
		else:
			hud.dialogs.open_room_menu())
	hud.tray_chip_pressed.connect(_on_tray_chip)
	hud.settings_pressed.connect(func(): hud.dialogs.open_settings())
	hud.books_pressed.connect(func(): hud.dialogs.open_all_books())
	hud.edit_pressed.connect(func():
		if mode == Mode.SHELF and active_shelf:
			hud.dialogs.open_shelf_menu(active_shelf.shelf_id)
		else:
			hud.dialogs.open_room_menu())
	Settings.changed.connect(func(key: String):
		if key == "spine_top_down" or key == "night_mode":
			_on_structure_changed())
	_night_now = Settings.is_night()
	var clock := Timer.new()
	clock.wait_time = 60.0
	clock.autostart = true
	clock.timeout.connect(func():
		if Settings.is_night() != _night_now:
			_night_now = Settings.is_night()
			_on_structure_changed())
	add_child(clock)

	Library.structure_changed.connect(_on_structure_changed)
	Library.placement_changed.connect(_on_placement_changed)
	Library.book_updated.connect(_on_book_updated)
	Library.tray_changed.connect(func(): hud.refresh_tray())
	BookAPI.cover_ready.connect(func(_id, _tex): hud.refresh_tray())

	if demo:
		DemoData.populate()
		if shot_style != "":
			Library.data["style"] = shot_style
	_apply_style()
	_load_room(0)
	hud.refresh_tray()
	BookAPI.request_missing_covers()
	if shot_path != "":
		_run_shot()

func _parse_args() -> void:
	for a in OS.get_cmdline_user_args():
		if a == "--demo":
			demo = true
		elif a.begins_with("--shot="):
			shot_path = a.trim_prefix("--shot=")
		elif a.begins_with("--mode="):
			shot_mode = a.trim_prefix("--mode=")
		elif a.begins_with("--style="):
			shot_style = a.trim_prefix("--style=")
		elif a == "--night":
			Settings.data["night_mode"] = "on"
		elif a.begins_with("--lang="):
			Settings.data["language"] = a.trim_prefix("--lang=")
			Settings.apply_language()
		elif a == "--apitest":
			_run_api_test.call_deferred()
		elif a.begins_with("--csvtest="):
			_run_csv_test.call_deferred(a.trim_prefix("--csvtest="))

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if hud.is_dialog_open():
			hud.close_sheet()
		elif mode == Mode.SHELF:
			exit_shelf()
		else:
			get_tree().quit()

# ---------------------------------------------------------------- rooms & style

func _apply_style() -> void:
	style = Styles.get_style(Library.get_style_id())
	hud.apply_style(style)

func current_room() -> Dictionary:
	return Library.get_room_at(room_index)

func current_room_id() -> String:
	return str(current_room().get("id", ""))

## Swing the door open, fade, and arrive in the next room facing away from the door you came through.
func _go_through_door(to_rid: String) -> void:
	var idx := Library.room_index(to_rid)
	if idx < 0 or rig.moving:
		return
	var from_rid := current_room_id()
	var dn: Node3D = room3d.doors.get(to_rid)
	if dn != null:
		var hinge := dn.get_node_or_null("Hinge")
		if hinge != null:
			var tw := create_tween()
			tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			tw.tween_property(hinge, "rotation:y", -1.35, 0.4)
			await get_tree().create_timer(0.28).timeout
	var back := Library.door_to(to_rid, from_rid)
	var face: float = Styles.facing_from_wall(int(back["wall"])) if not back.is_empty() else yaw
	_fade_to(func(): _load_room(idx, face))

func _load_room(index: int, face_yaw := INF) -> void:
	room_index = clamp(index, 0, max(0, Library.room_count() - 1))
	if is_finite(face_yaw):
		yaw = face_yaw
		pitch = -0.02
	var room := current_room()
	room3d.build(room, style)
	mode = Mode.ROOM
	active_shelf = null
	rig.snap(_room_eye(), _room_basis(), ROOM_FOV)
	_update_room_hud()

func _update_room_hud() -> void:
	var room := current_room()
	var shelves: Array = room.get("shelves", [])
	var n_books := Library.room_book_count(str(room.get("id", "")))
	var sub := (tr("1 shelf") if shelves.size() == 1 else tr("%d shelves") % shelves.size()) + " · " + (tr("1 book") if n_books == 1 else tr("%d books") % n_books)
	if shelves.is_empty():
		sub = tr("No shelves yet · tap the pencil to add one")
	elif n_books == 0:
		sub += tr(" · tap a shelf to open it")
	if Library.room_count() > 1:
		sub = tr("Room %d of %d") % [room_index + 1, Library.room_count()] + " · " + sub
	hud.set_room_mode(str(room.get("name", "Room")), sub, Library.room_count() > 1)

func _room_basis() -> Basis:
	return Basis.from_euler(Vector3(pitch, yaw, 0))

## Eye position for the room view: orbits the room centre opposite to the look direction.
func _room_eye() -> Vector3:
	var fwd := Vector3(-sin(yaw), 0.0, -cos(yaw))
	return ROOM_PIVOT - fwd * ROOM_ORBIT

func _step(delta: int) -> void:
	if mode == Mode.SHELF:
		_shelf_step(delta)
		return
	if Library.room_count() < 2:
		return
	var target := wrapi(room_index + delta, 0, Library.room_count())
	_fade_to(func(): _load_room(target))

func go_to_room_id(rid: String) -> void:
	var idx := Library.room_index(rid)
	if idx < 0:
		return
	if idx == room_index and mode == Mode.ROOM:
		return
	_fade_to(func(): _load_room(idx))

func _fade_to(cb: Callable) -> void:
	var tw := create_tween()
	tw.tween_property(fade, "modulate:a", 1.0, 0.22)
	tw.tween_callback(cb)
	tw.tween_property(fade, "modulate:a", 0.0, 0.3)

func _on_structure_changed() -> void:
	_prop_focused = false
	if drag_book:
		_cancel_drag()
	_apply_style()
	var keep_shelf := active_shelf.shelf_id if active_shelf else ""
	var was_shelf := mode == Mode.SHELF
	room_index = clamp(room_index, 0, max(0, Library.room_count() - 1))
	room3d.build(current_room(), style)
	if was_shelf and room3d.shelves.has(keep_shelf):
		active_shelf = room3d.shelves[keep_shelf]
		mode = Mode.SHELF
		var view := _shelf_view(active_shelf)
		rig.snap(view[0], view[1], SHELF_FOV)
		_update_shelf_hud()
	else:
		mode = Mode.ROOM
		active_shelf = null
		rig.snap(_room_eye(), _room_basis(), ROOM_FOV)
		_update_room_hud()
	hud.refresh_tray()

func _on_placement_changed(shelf_ids: Array) -> void:
	for sid in shelf_ids:
		if room3d.shelves.has(sid):
			room3d.shelves[sid].rebuild_books(true)
	if mode == Mode.SHELF:
		_update_shelf_hud()
	else:
		_update_room_hud()

func _on_book_updated(id: String) -> void:
	room3d.refresh_props()
	if drag_book and drag_book.book_id == id:
		return
	var sh := room3d.shelf_for_book(id)
	if sh:
		sh.refresh_book(id)

# ---------------------------------------------------------------- shelf mode

func _shelf_view(sh: Shelf3D) -> Array:
	var vp := get_viewport().get_visible_rect().size
	var aspect: float = vp.x / maxf(vp.y, 1.0)
	var half_fov := deg_to_rad(SHELF_FOV) / 2.0
	# the HUD covers roughly the top 8% and bottom 22% of the screen; frame the case in between
	var d_v := (Styles.SHELF_H / 2.0 + 0.18) / (tan(half_fov) * 0.70)
	var d_h: float = (Styles.SHELF_W / 2.0 + 0.08) / (tan(half_fov) * aspect)
	var dist: float = max(d_v, d_h) * shelf_zoom
	var fwd := sh.forward_world()
	var right := sh.global_transform.basis.x.normalized()
	var center := sh.center_world() + right * shelf_pan.x + Vector3.UP * (shelf_pan.y - 0.16 * shelf_zoom)
	var pos := center + fwd * dist + Vector3.UP * 0.02
	return [pos, CameraRig.look_basis(pos, center)]

func enter_shelf(sh: Shelf3D) -> void:
	if sh == null:
		return
	_prop_focused = false
	mode = Mode.SHELF
	active_shelf = sh
	shelf_zoom = 1.0
	shelf_pan = Vector2.ZERO
	var view := _shelf_view(sh)
	rig.go_to(view[0], view[1], SHELF_FOV, 0.65)
	_update_shelf_hud()

func enter_shelf_by_id(sid: String) -> void:
	var room := Library.get_shelf_room(sid)
	if room.is_empty():
		return
	var idx := Library.room_index(str(room["id"]))
	if idx != room_index:
		_fade_to(func():
			_load_room(idx)
			if room3d.shelves.has(sid):
				enter_shelf(room3d.shelves[sid]))
	elif room3d.shelves.has(sid):
		enter_shelf(room3d.shelves[sid])

func active_shelf_id() -> String:
	return active_shelf.shelf_id if active_shelf else ""

func _update_shelf_hud() -> void:
	if active_shelf == null:
		return
	var s := Library.get_shelf(active_shelf.shelf_id)
	var n := Library.shelf_book_count(active_shelf.shelf_id)
	var sub := str(current_room().get("name", "")) + " · " + (tr("1 book") if n == 1 else tr("%d books") % n) + tr(" · drag to rearrange")
	if n == 0:
		sub = str(current_room().get("name", "")) + tr(" · empty · tap + or pick from the tray")
	var shelves: Array = current_room().get("shelves", [])
	hud.set_shelf_mode(str(s.get("name", "Shelf")), sub, shelves.size() > 1)

func exit_shelf() -> void:
	if mode != Mode.SHELF:
		return
	if drag_book:
		_cancel_drag()
	if active_shelf:
		var d := active_shelf.center_world() - ROOM_PIVOT
		yaw = atan2(-d.x, -d.z)
		pitch = -0.02
	mode = Mode.ROOM
	active_shelf = null
	hud.set_placing("")
	rig.go_to(_room_eye(), _room_basis(), ROOM_FOV, 0.6)
	_update_room_hud()

func _shelf_step(delta: int) -> void:
	var shelves: Array = Styles.around_room(current_room().get("shelves", []))
	if shelves.size() < 2 or active_shelf == null:
		return
	var idx := -1
	for i in shelves.size():
		if shelves[i]["id"] == active_shelf.shelf_id:
			idx = i
	var next: Dictionary = shelves[wrapi(idx + delta, 0, shelves.size())]
	if room3d.shelves.has(next["id"]):
		enter_shelf(room3d.shelves[next["id"]])

func _update_shelf_camera(animate: bool) -> void:
	if active_shelf == null:
		return
	var view := _shelf_view(active_shelf)
	if animate:
		rig.go_to(view[0], view[1], SHELF_FOV, 0.2)
	else:
		rig.snap(view[0], view[1], SHELF_FOV)

func _zoom(factor: float) -> void:
	if mode != Mode.SHELF:
		return
	shelf_zoom = clamp(shelf_zoom * factor, 0.42, 1.25)
	_clamp_pan()
	_update_shelf_camera(false)

## Zoom keeping the shelf point under screen_pos fixed (pinch / wheel / double tap).
func _zoom_at(factor: float, screen_pos: Vector2, animate := false) -> void:
	if mode != Mode.SHELF or active_shelf == null or drag_book != null:
		return
	var prev_pos := rig.position
	var prev_q := rig.quaternion
	var z := active_shelf.spine_plane_z()
	var before = active_shelf.local_from_screen(rig.cam, screen_pos, z)
	shelf_zoom = clamp(shelf_zoom * factor, 0.42, 1.25)
	_clamp_pan()
	_update_shelf_camera(false)
	if before != null:
		var after = active_shelf.local_from_screen(rig.cam, screen_pos, z)
		if after != null:
			shelf_pan += Vector2(before.x - after.x, before.y - after.y)
			_clamp_pan()
			_update_shelf_camera(false)
	if animate:
		var final_pos := rig.position
		var final_q := rig.quaternion
		rig.position = prev_pos
		rig.quaternion = prev_q
		rig.go_to(final_pos, Basis(final_q), SHELF_FOV, 0.28)

func _double_tap_zoom(pos: Vector2) -> void:
	if shelf_zoom > 0.7:
		_zoom_at(0.5 / shelf_zoom, pos, true)
	else:
		shelf_zoom = 1.0
		shelf_pan = Vector2.ZERO
		_update_shelf_camera(true)

func _clamp_pan() -> void:
	var lim_x: float = max(0.0, Styles.SHELF_W * 0.55 * (1.0 - shelf_zoom))
	var lim_y: float = max(0.0, Styles.SHELF_H * 0.55 * (1.0 - shelf_zoom))
	shelf_pan.x = clamp(shelf_pan.x, -lim_x, lim_x)
	shelf_pan.y = clamp(shelf_pan.y, -lim_y, lim_y)

# ---------------------------------------------------------------- input

## While a book is being dragged, take pointer events before the GUI so panels cannot swallow the drop.
func _input(event: InputEvent) -> void:
	if drag_book == null:
		return
	if event is InputEventMouseMotion:
		_on_motion(event.position)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_on_release(event.position)
		get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if hud.is_dialog_open():
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_on_press(event.position)
			else:
				_on_release(event.position)
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_zoom_at(0.9, event.position)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_zoom_at(1.1, event.position)
	elif event is InputEventMouseMotion:
		if pressing:
			_on_motion(event.position)
	elif event is InputEventMagnifyGesture:
		_zoom_at(1.0 / max(event.factor, 0.01), event.position)
	elif event is InputEventPanGesture:
		if mode == Mode.SHELF and not drag_book:
			var sp := -1.0 if Settings.get_value("invert_pan") else 1.0
			shelf_pan += Vector2(-event.delta.x, event.delta.y) * 0.0025 * shelf_zoom * sp
			_clamp_pan()
			_update_shelf_camera(false)

func _on_press(pos: Vector2) -> void:
	pressing = true
	press_pos = pos
	last_pos = pos
	drag_started = false
	camera_dragging = false
	press_book = ""
	if mode == Mode.SHELF and active_shelf and not rig.moving:
		var L = active_shelf.local_from_screen(rig.cam, pos, active_shelf.spine_plane_z())
		if L != null:
			press_book = active_shelf.book_at_local(L.x, L.y)

func _on_motion(pos: Vector2) -> void:
	if not drag_started:
		if pos.distance_to(press_pos) < TAP_SLOP:
			return
		drag_started = true
		if press_book != "" and mode == Mode.SHELF and hud.placing_id == "":
			_begin_book_drag()
		else:
			camera_dragging = true
	if drag_book:
		_update_book_drag(pos)
	elif camera_dragging:
		var rel := pos - last_pos
		var sens: float = 0.0021 * float(Settings.get_value("look_sensitivity"))
		if mode == Mode.ROOM:
			var sx := -1.0 if Settings.get_value("invert_look_x") else 1.0
			var sy := -1.0 if Settings.get_value("invert_look_y") else 1.0
			yaw -= rel.x * sens * sx
			pitch = clamp(pitch - rel.y * sens * sy, -0.85, 0.65)
			rig.snap(_room_eye(), _room_basis(), ROOM_FOV)
		else:
			var sp := -1.0 if Settings.get_value("invert_pan") else 1.0
			shelf_pan += Vector2(-rel.x, rel.y) * 0.0011 * shelf_zoom * sp
			_clamp_pan()
			_update_shelf_camera(false)
	last_pos = pos

func _on_release(pos: Vector2) -> void:
	pressing = false
	if drag_book:
		_end_book_drag(pos)
		return
	if camera_dragging:
		camera_dragging = false
		return
	_on_tap(pos)

func _on_tap(pos: Vector2) -> void:
	if rig.moving:
		return
	if mode == Mode.ROOM:
		var col := _raycast_collider(pos)
		var sh := room3d.shelf_by_body(col)
		if sh:
			enter_shelf(sh)
			return
		var prop := room3d.prop_by_body(col)
		if prop != "":
			_focus_prop(prop)
			return
		var door_to := room3d.door_by_body(col)
		if door_to != "":
			_go_through_door(door_to)
		return
	if active_shelf == null:
		return
	if hud.placing_id != "":
		var pid := hud.placing_id
		var L = active_shelf.local_from_screen(rig.cam, pos, active_shelf.spine_plane_z())
		if L == null or abs(L.x) > Styles.SHELF_W / 2.0 + 0.1 or L.y < -0.1 or L.y > Styles.SHELF_H + 0.1:
			hud.toast("Tap a row on the shelf to place the book")
			return
		var r := active_shelf.row_at_local_y(L.y)
		var i := active_shelf.index_at_local_x(r, L.x)
		if Library.place(pid, active_shelf.shelf_id, r, i):
			hud.set_placing("")
			hud.toast(tr("Placed on row %d") % Library.row_number(r))
		else:
			hud.toast(tr("Not enough space on row %d") % Library.row_number(r))
		return
	if press_book != "":
		hud.dialogs.open_book_detail(press_book)
		return
	# double tap on empty shelf space toggles zoom on that spot
	var now := Time.get_ticks_msec()
	if now - _last_tap_time < 350 and pos.distance_to(_last_tap_pos) < 90:
		_last_tap_time = 0
		_double_tap_zoom(pos)
	else:
		_last_tap_time = now
		_last_tap_pos = pos

## Fly the camera to the reading table or archive box, then open its sheet. The sheet covers the
## lower part of the screen, so the prop is framed in the upper quarter. Closing flies back out.
var _prop_focused := false

func _focus_prop(prop: String) -> void:
	var node: Node3D = room3d.table if prop == "reading" else room3d.archive
	if node == null:
		return
	var target := node.global_position + (Vector3(0, 0.45, 0) if prop == "reading" else Vector3(0, 0.12, 0))
	var toward_center := (Vector3(0, 0, 0.3) - node.global_position)
	toward_center.y = 0.0
	toward_center = toward_center.normalized() if toward_center.length() > 0.01 else Vector3(0, 0, 1)
	# come in from the side the camera is on when that makes sense, else from the room centre
	var from_cam := (rig.position - node.global_position)
	from_cam.y = 0.0
	var side := from_cam.normalized() if from_cam.length() > 0.5 and prop == "reading" else toward_center
	var eye := target + side * (1.8 if prop == "reading" else 1.7) + Vector3(0, 1.0, 0)
	# aim below the prop so it sits in the upper part of the screen above the sheet
	var aim := target - Vector3(0, 0.62, 0)
	_prop_focused = true
	rig.go_to(eye, CameraRig.look_basis(eye, aim), 48.0, 0.55)
	await get_tree().create_timer(0.45).timeout
	if not _prop_focused or mode != Mode.ROOM:
		return
	if prop == "reading":
		hud.dialogs.open_reading_list()
	else:
		hud.dialogs.open_archive()

func on_sheet_closed() -> void:
	if _prop_focused:
		_prop_focused = false
		if mode == Mode.ROOM:
			rig.go_to(_room_eye(), _room_basis(), ROOM_FOV, 0.55)

func _raycast_collider(pos: Vector2) -> Object:
	var from := rig.cam.project_ray_origin(pos)
	var to := from + rig.cam.project_ray_normal(pos) * 40.0
	var q := PhysicsRayQueryParameters3D.create(from, to, 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return null
	return hit.get("collider")

func _on_tray_chip(id: String) -> void:
	if hud.placing_id == id:
		hud.set_placing("")
		return
	hud.set_placing(id)
	if mode == Mode.ROOM:
		hud.toast("Now open a shelf and tap where the book should go")
	else:
		hud.toast("Tap a spot on the shelf to place it")

# ---------------------------------------------------------------- book drag

func _begin_book_drag() -> void:
	drag_book = active_shelf.book_node(press_book)
	if drag_book == null:
		return
	drag_book.kill_tween()
	drag_book.set_highlight(true)
	drag_book.scale = Vector3(1.03, 1.03, 1.03)
	drag_row = -1
	drag_index = -1
	drag_fits = true
	drag_over_tray = false
	_last_preview = ""
	hud.set_drag_tray(true)

func _update_book_drag(pos: Vector2) -> void:
	var lift_z := active_shelf.spine_plane_z() + 0.12
	var L = active_shelf.local_from_screen(rig.cam, pos, lift_z)
	if L == null:
		return
	drag_over_tray = hud.tray_rect().has_point(pos)
	var r := active_shelf.row_at_local_y(L.y)
	var i := active_shelf.index_at_local_x(r, L.x, drag_book.book_id)
	drag_row = r
	drag_index = i
	drag_fits = Library.row_free_width(active_shelf.shelf_id, r, drag_book.book_id) >= Library.book_shelf_width(drag_book.book) + Shelf3D.GAP
	var y: float = clamp(L.y - drag_book.dims.y * 0.35, -0.05, Styles.SHELF_H)
	drag_book.position = Vector3(L.x, y, lift_z - drag_book.dims.z / 2.0)
	drag_book.rotation = Vector3(0.0, 0.0, 0.05)
	drag_book.scale = Vector3.ONE * (0.7 if drag_over_tray else 1.03)
	var key := "%d:%d:%s:%s" % [r, i, drag_over_tray, drag_fits]
	if key != _last_preview:
		_last_preview = key
		var gap_row := r if (drag_fits and not drag_over_tray) else -1
		active_shelf.layout(true, drag_book.book_id, gap_row, i, drag_book.shelf_width())
		hud.set_tray_hover(drag_over_tray)

func _end_book_drag(_pos: Vector2) -> void:
	var id := drag_book.book_id
	var sid := active_shelf.shelf_id
	drag_book.set_highlight(false)
	var b := drag_book
	drag_book = null
	hud.set_tray_hover(false)
	hud.set_drag_tray(false)
	if drag_over_tray:
		Library.to_tray(id)
		hud.toast("Moved to the tray")
	elif drag_fits and drag_row >= 0:
		if not Library.place(id, sid, drag_row, drag_index):
			active_shelf.layout(true)
	else:
		active_shelf.layout(true)
		if not drag_fits:
			hud.toast(tr("Not enough space on row %d") % Library.row_number(drag_row))
	b.rotation = Vector3.ZERO

func _cancel_drag() -> void:
	if drag_book == null:
		return
	drag_book.set_highlight(false)
	drag_book = null
	hud.set_tray_hover(false)
	hud.set_drag_tray(false)
	if active_shelf:
		active_shelf.layout(true)

# ---------------------------------------------------------------- screenshot harness

func _run_shot() -> void:
	for i in 30:
		await get_tree().process_frame
	match shot_mode:
		"shelf":
			var first: Dictionary = current_room()["shelves"][0]
			enter_shelf(room3d.shelves[first["id"]])
		"shelf2":
			var s: Dictionary = current_room()["shelves"][1]
			enter_shelf(room3d.shelves[s["id"]])
		"detail":
			var first: Dictionary = current_room()["shelves"][0]
			enter_shelf(room3d.shelves[first["id"]])
			hud.dialogs.open_book_detail(_first_book_id(first))
		"detail_isbn":
			hud.dialogs.open_book_detail(Library.sorted_book_ids("title", "Name of the Wind")[0])
		"add":
			hud.dialogs.open_add_book()
		"import":
			hud.dialogs.open_import()
		"style":
			hud.dialogs.open_style()
		"settings":
			hud.dialogs.open_settings()
		"books":
			hud.dialogs.open_all_books()
		"room":
			hud.dialogs.open_room_menu()
		"move":
			var first: Dictionary = current_room()["shelves"][0]
			hud.dialogs.open_move_picker(_first_book_id(first))
		"look":
			yaw = 0.9
			pitch = -0.05
			rig.snap(_room_eye(), _room_basis(), ROOM_FOV)
		"look2":
			yaw = -2.4
			rig.snap(_room_eye(), _room_basis(), ROOM_FOV)
		"study":
			_load_room(1)
			yaw = 2.6
			rig.snap(_room_eye(), _room_basis(), ROOM_FOV)
		"fire":
			rig.snap(Vector3(0.9, 1.3, -0.6), CameraRig.look_basis(Vector3(0.9, 1.3, -0.6), Vector3(0, 0.9, 3.0)), 55.0)
		"cat":
			rig.snap(Vector3(0.6, 1.0, -0.4), CameraRig.look_basis(Vector3(0.6, 1.0, -0.4), Vector3(-0.75, 0.1, 0.85)), 40.0)
		"office", "bedroom", "fantasy":
			Library.get_rooms()[0]["type"] = shot_mode
			_on_structure_changed()
			yaw = 2.6 if shot_mode != "fantasy" else -2.5
			pitch = -0.1
			rig.snap(_room_eye(), _room_basis(), ROOM_FOV)
		"office2":
			Library.get_rooms()[0]["type"] = "office"
			_on_structure_changed()
			var eye := Vector3(0.2, 1.4, -0.2)
			rig.snap(eye, CameraRig.look_basis(eye, Vector3(1.7, 0.8, 1.4)), 50.0)
		"fantasy2":
			Library.get_rooms()[0]["type"] = "fantasy"
			_on_structure_changed()
			var eye := Vector3(-0.3, 1.3, 1.2)
			rig.snap(eye, CameraRig.look_basis(eye, Vector3(0.6, 0.9, -1.2)), 55.0)
		"window":
			var eye := Vector3(0.4, 1.5, -0.6)
			rig.snap(eye, CameraRig.look_basis(eye, Vector3(0, 1.7, -3.0)), 50.0)
		"attic":
			_load_room(2, PI / 2.0)
			rig.snap(_room_eye(), _room_basis(), ROOM_FOV)
		"attic_n":
			_load_room(2, 0.0)
			pitch = -0.05
			rig.snap(_room_eye(), _room_basis(), ROOM_FOV)
		"door":
			# stand in the room looking at the east wall door
			yaw = -PI / 2.0
			pitch = -0.02
			rig.snap(_room_eye(), _room_basis(), ROOM_FOV)
		"door_go":
			yaw = -PI / 2.0
			rig.snap(_room_eye(), _room_basis(), ROOM_FOV)
			for i in 5:
				await get_tree().process_frame
			var d: Node3D = room3d.doors.values()[0]
			var p := rig.cam.unproject_position(d.global_position + Vector3(0, 1.0, 0))
			_send_mouse(p, true)
			await get_tree().process_frame
			_send_mouse(p, false)
			for i in 90:
				await get_tree().process_frame
			print("DOOR_RESULT room=", current_room().get("name", ""), " yaw=%.2f" % yaw)
		"chair":
			var eye := Vector3(0.0, 1.3, -0.5)
			rig.snap(eye, CameraRig.look_basis(eye, Vector3(1.75, 0.5, 1.25)), 45.0)
		"table":
			var eye := Vector3(1.1, 1.25, 1.35)
			rig.snap(eye, CameraRig.look_basis(eye, Room3D.TABLE_POS + Vector3(0, 0.45, 0)), 42.0)
		"box":
			var eye := Vector3(-0.7, 1.1, 0.9)
			rig.snap(eye, CameraRig.look_basis(eye, Room3D.ARCHIVE_POS + Vector3(0, 0.15, 0)), 38.0)
		"reading":
			hud.dialogs.open_reading_list()
		"archive":
			hud.dialogs.open_archive()
		"focus_table", "focus_box":
			yaw = 0.0 if shot_mode == "focus_table" else -2.5
			pitch = -0.35
			rig.snap(_room_eye(), _room_basis(), ROOM_FOV)
			for i in 5:
				await get_tree().process_frame
			var node: Node3D = room3d.table if shot_mode == "focus_table" else room3d.archive
			var p := rig.cam.unproject_position(node.global_position + Vector3(0, 0.2, 0))
			_send_mouse(p, true)
			await get_tree().process_frame
			_send_mouse(p, false)
			for i in 60:
				await get_tree().process_frame
		"ghost":
			# close-up of the row holding the first book that is being read
			var reading := Library.reading_ids()
			var loc := Library.find_location(reading[0]) if not reading.is_empty() else {}
			if loc.has("shelf"):
				enter_shelf_by_id(str(loc["shelf"]))
				for i in 40:
					await get_tree().process_frame
				shelf_zoom = 0.5
				var sh := active_shelf
				shelf_pan = Vector2(-0.25, sh.rows_y[int(loc["row"])] + 0.12 - Styles.SHELF_H / 2.0)
				_clamp_pan()
				_update_shelf_camera(false)
		"closeup":
			var first: Dictionary = current_room()["shelves"][0]
			enter_shelf(room3d.shelves[first["id"]])
			shelf_zoom = 0.4
			shelf_pan = Vector2(-0.3, -0.55)
			_clamp_pan()
			for i in 45:
				await get_tree().process_frame
			_update_shelf_camera(false)
		"zoomtap":
			var first: Dictionary = current_room()["shelves"][0]
			enter_shelf(room3d.shelves[first["id"]])
			for i in 70:
				await get_tree().process_frame
			# double tap on an empty spot of the second row from the top, left side
			var sh := active_shelf
			var p := rig.cam.unproject_position(sh.to_global(Vector3(-0.35, sh.rows_y[3] + 0.15, sh.spine_plane_z())))
			for k in 2:
				_send_mouse(p, true)
				await get_tree().process_frame
				_send_mouse(p, false)
				for i in 6:
					await get_tree().process_frame
			print("ZOOM_RESULT zoom=%.2f pan=%s" % [shelf_zoom, str(shelf_pan)])
		"drag", "dragtray":
			var first: Dictionary = current_room()["shelves"][0]
			enter_shelf(room3d.shelves[first["id"]])
			for i in 70:
				await get_tree().process_frame
			await _scripted_drag(shot_mode == "dragtray")
	for i in 70:
		await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	img.save_png(shot_path)
	print("SHOT_SAVED ", shot_path)
	get_tree().quit()

## Canvas → window coordinates (parse_input_event expects window space; the stretch transform is applied later).
func _to_window(pos: Vector2) -> Vector2:
	return get_viewport().get_final_transform() * pos

func _send_mouse(pos: Vector2, pressed: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = pressed
	ev.position = _to_window(pos)
	ev.global_position = ev.position
	Input.parse_input_event(ev)

func _send_motion(pos: Vector2, prev: Vector2) -> void:
	var ev := InputEventMouseMotion.new()
	ev.position = _to_window(pos)
	ev.global_position = ev.position
	ev.relative = _to_window(pos) - _to_window(prev)
	ev.button_mask = MOUSE_BUTTON_MASK_LEFT
	Input.parse_input_event(ev)

## Simulates a real touch drag through the input pipeline: first book → top row (or → tray).
func _scripted_drag(to_tray: bool) -> void:
	var sh := active_shelf
	var src_id := ""
	for row in Library.get_shelf(sh.shelf_id)["rows"]:
		if row.size() > 0:
			src_id = row[0]
			break
	if src_id == "":
		return
	var b := sh.book_node(src_id)
	var p0 := rig.cam.unproject_position(b.global_position + b.global_transform.basis.y * 0.08 + sh.forward_world() * 0.08)
	_send_mouse(p0, true)
	for i in 3:
		await get_tree().process_frame
	var p1: Vector2
	if to_tray:
		p1 = hud.bottom_bar.get_global_rect().get_center()
	else:
		p1 = rig.cam.unproject_position(sh.to_global(Vector3(0.1, sh.rows_y[4] + 0.1, sh.spine_plane_z() + 0.12)))
	var steps := 14
	var prev := p0
	for i in steps:
		var p := p0.lerp(p1, float(i + 1) / steps)
		_send_motion(p, prev)
		prev = p
		await get_tree().process_frame
	for i in 25:
		await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	img.save_png(shot_path.replace(".png", "_mid.png"))
	print("SHOT_SAVED ", shot_path.replace(".png", "_mid.png"))
	_send_mouse(p1, false)
	for i in 5:
		await get_tree().process_frame
	print("DRAG_RESULT ", Library.location_label(Library.find_location(src_id)), " dragging=", drag_book != null)

func _run_api_test() -> void:
	print("API: searching…")
	var res: Array = await BookAPI.search("The Name of the Wind Rothfuss")
	print("API: %d results" % res.size())
	for r in res.slice(0, 3):
		print("  - ", r.get("title"), " | ", r.get("authors"), " | ", r.get("isbn13", ""), " | pages=", r.get("pages"), " | cover=", str(r.get("cover_url", "")).left(60))
	var isbn: Dictionary = await BookAPI.lookup_isbn("9780756404741")
	print("API: isbn lookup to ", isbn.get("title", "<none>"), " cover=", isbn.has("cover_url"))
	if res.is_empty():
		print("API: FAILED search")
		get_tree().quit(1)
		return
	var id := Library.add_book(res[0])
	Library.auto_place(id, current_room_id())
	var done := false
	BookAPI.cover_ready.connect(func(bid, tex):
		if bid == id:
			print("API: cover ready ", tex.get_size(), " color=", Library.get_book(id)["color"], " file=", Library.get_book(id)["cover_file"])
			done = true)
	print("API: candidates ", BookAPI._cover_candidates(Library.get_book(id)))
	BookAPI.request_cover(id)
	var t0 := Time.get_ticks_msec()
	while not done and Time.get_ticks_msec() - t0 < 45000:
		await get_tree().create_timer(0.25).timeout
	print("API: cover_tried=", Library.get_book(id).get("cover_tried"), " done=", done, " after ", Time.get_ticks_msec() - t0, "ms")
	get_tree().quit(0 if done else 2)

func _run_csv_test(path: String) -> void:
	var list := GoodreadsImport.parse_file(path)
	print("CSV: parsed %d rows" % list.size())
	for info in list:
		print("  - ", info["title"], " | ", info["authors"], " | isbn=", info["isbn"], " isbn13=", info["isbn13"], " pages=", info["pages"], " year=", info["year"], " rating=", info["rating"], " shelf=", info["exclusive_shelf"], " tags=", info["tags"])
	get_tree().quit()

func _first_book_id(shelf: Dictionary) -> String:
	for row in shelf["rows"]:
		if row.size() > 0:
			return row[0]
	return ""
