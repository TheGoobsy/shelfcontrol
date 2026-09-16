class_name Dialogs
extends RefCounted
## All bottom-sheet dialogs. Built on top of HUD.open_sheet().

var hud: HUD
var _file_dialog: FileDialog
var _file_cb: Callable
var _search_gen := 0
var _import_status: Label
var _import_progress: ProgressBar

func _init(h: HUD) -> void:
	hud = h
	BookAPI.cover_progress.connect(_on_cover_progress)

func main() -> Node:
	return hud.main

func on_closed() -> void:
	_search_gen += 1
	main().on_sheet_closed()

func _bold_label(text: String, size := 30) -> Label:
	var l := hud.label(text)
	l.add_theme_font_override("font", hud.sans_bold)
	l.add_theme_font_size_override("font_size", size)
	return l

const CardRowScript := preload("res://scripts/ui/card_row.gd")

## Small muted chevron for rows that open something, vertically centred in its row.
func _chevron() -> Control:
	var t := TextureRect.new()
	t.texture = load("res://icons/chevron_right.svg")
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.custom_minimum_size = Vector2(34, 34)
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	t.modulate = hud.muted()
	return t

func _card_button(content: Control, min_h: float) -> PanelContainer:
	return CardRowScript.new(content, min_h)

func _ignore_mouse(c: Node) -> void:
	for ch in c.get_children():
		if ch is Control:
			ch.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_ignore_mouse(ch)

# ---------------------------------------------------------------- add book


func open_add_book() -> void:
	var c := hud.open_sheet("Add a book", 0.88)
	var search_box := VBoxContainer.new()
	search_box.add_theme_constant_override("separation", 12)
	var manual_box := VBoxContainer.new()
	manual_box.add_theme_constant_override("separation", 12)
	manual_box.visible = false
	hud.segmented(c, [["search", "Search online"], ["manual", "Enter by hand"]], "search", func(k):
		search_box.visible = k == "search"
		manual_box.visible = k == "manual"
		if k == "manual" and manual_box.get_child_count() == 0:
			_manual_form(manual_box))
	c.add_child(search_box)
	c.add_child(manual_box)
	var r := hud.row()
	var field := LineEdit.new()
	field.placeholder_text = tr("Title, author or ISBN")
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	field.custom_minimum_size = Vector2(0, 88)
	field.clear_button_enabled = true
	r.add_child(field)
	var go := hud.button("Search", "AccentButton")
	go.custom_minimum_size = Vector2(190, 88)
	r.add_child(go)
	search_box.add_child(r)
	var status := hud.label("Searches Google Books, then Open Library. New books go to the current room.", "MutedLabel")
	search_box.add_child(status)
	var results := VBoxContainer.new()
	results.add_theme_constant_override("separation", 10)
	search_box.add_child(results)

	var do_search := func() -> void:
		var q := field.text.strip_edges()
		if q == "":
			return
		_search_gen += 1
		var gen := _search_gen
		status.text = tr("Searching…")
		for ch in results.get_children():
			ch.queue_free()
		var list: Array = []
		var digits := q.replace("-", "").replace(" ", "")
		if digits.is_valid_int() and (digits.length() == 10 or digits.length() == 13):
			var one: Dictionary = await BookAPI.lookup_isbn(digits)
			if not one.is_empty():
				list = [one]
		else:
			list = await BookAPI.search(q)
		if gen != _search_gen or not hud.is_dialog_open():
			return
		if list.is_empty():
			status.text = tr("No results. Check the spelling or your connection.")
			return
		status.text = tr("1 result · tap Add") if list.size() == 1 else tr("%d results · tap Add") % list.size()
		for info in list:
			results.add_child(_result_row(info))
	go.pressed.connect(do_search)
	field.text_submitted.connect(func(_t): do_search.call())
	field.grab_focus()

func _result_row(info: Dictionary) -> Control:
	var card := PanelContainer.new()
	card.theme_type_variation = "Card"
	var h := hud.row(16)
	var thumb := Control.new()
	thumb.custom_minimum_size = Vector2(96, 144)
	thumb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	thumb.clip_contents = true
	var ph := ColorRect.new()
	var mu := hud.muted()
	ph.color = Color(mu.r, mu.g, mu.b, 0.25)
	ph.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	thumb.add_child(ph)
	h.add_child(thumb)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	v.add_theme_constant_override("separation", 2)
	var title_lbl := _bold_label(str(info.get("title", "")), 28)
	title_lbl.max_lines_visible = 2
	title_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	v.add_child(title_lbl)
	var meta: Array = []
	var authors: Array = info.get("authors", [])
	if not authors.is_empty():
		meta.append(_short_authors(authors))
	if str(info.get("year", "")) != "":
		meta.append(str(info["year"]))
	if int(info.get("pages", 0)) > 0:
		meta.append(tr("%d pages") % int(info["pages"]))
	var meta_lbl := hud.label(" · ".join(PackedStringArray(meta)), "SubLabel")
	meta_lbl.max_lines_visible = 2
	meta_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	v.add_child(meta_lbl)
	h.add_child(v)
	var add := hud.button("Add", "AccentButton")
	add.custom_minimum_size = Vector2(150, 84)
	add.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	add.add_theme_font_size_override("font_size", 26)
	if _existing_id(info) != "":
		add.text = tr("In library")
		add.theme_type_variation = ""
		add.disabled = true
	add.pressed.connect(func():
		_add_info(info)
		add.text = tr("Added")
		add.theme_type_variation = ""
		add.disabled = true)
	h.add_child(add)
	card.add_child(h)
	if str(info.get("cover_url", "")) != "":
		_load_thumb(thumb, str(info["cover_url"]))
	return card

func _short_authors(authors: Array, max_names := 2) -> String:
	var names: Array = []
	for a in authors:
		var n := str(a).strip_edges()
		if n != "" and not names.has(n):
			names.append(n)
	if names.size() <= max_names:
		return ", ".join(PackedStringArray(names))
	var shown: Array = names.slice(0, max_names)
	return "%s and %d more" % [", ".join(PackedStringArray(shown)), names.size() - max_names]

func _existing_id(info: Dictionary) -> String:
	for key in ["isbn13", "isbn"]:
		var found := Library.find_by_isbn(str(info.get(key, "")))
		if found != "":
			return found
	var author := ""
	var authors: Array = info.get("authors", [])
	if authors.size() > 0:
		author = str(authors[0])
	return Library.find_by_title_author(str(info.get("title", "")), author)

func _load_thumb(holder: Control, url: String) -> void:
	var tex: Texture2D = await BookAPI.get_thumbnail(url)
	if tex == null or not is_instance_valid(holder):
		return
	var tr := TextureRect.new()
	tr.texture = tex
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	tr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.add_child(tr)

func _add_info(info: Dictionary) -> void:
	var id := Library.add_book(info)
	var loc := Library.auto_place(id, main().current_room_id(), true, false, main().active_shelf_id())
	BookAPI.request_cover(id)
	hud.toast(tr("Added “%s” to %s") % [str(info.get("title", "")), Library.location_label(loc)])

func _manual_form(parent: VBoxContainer) -> void:
	for ch in parent.get_children():
		ch.queue_free()
	var title := LineEdit.new()
	title.placeholder_text = tr("Title")
	title.custom_minimum_size = Vector2(0, 84)
	var author := LineEdit.new()
	author.placeholder_text = tr("Author")
	author.custom_minimum_size = Vector2(0, 84)
	var pages := LineEdit.new()
	pages.placeholder_text = tr("Pages (optional)")
	pages.custom_minimum_size = Vector2(0, 84)
	pages.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
	parent.add_child(title)
	parent.add_child(author)
	parent.add_child(pages)
	var add := hud.button("Add to library", "AccentButton")
	add.pressed.connect(func():
		if title.text.strip_edges() == "":
			hud.toast("Please enter a title")
			return
		_add_info({"title": title.text, "authors": [author.text.strip_edges()] if author.text.strip_edges() != "" else [], "pages": int(pages.text), "source": "manual"})
		hud.close_sheet())
	parent.add_child(add)
	title.grab_focus()

# ---------------------------------------------------------------- import


func open_import() -> void:
	var c := hud.open_sheet("Import from Goodreads", 0.9)
	c.add_child(hud.label("On goodreads.com open My Books → Import and export → Export Library, download the CSV, then choose it here.", "MutedLabel"))
	var opt_box := hud.section(c, "Which books")
	var state := {"shelf": "", "skip": true, "faceout": true}
	hud.segmented(opt_box, [["", "All"], ["read", "Read"], ["currently-reading", "Reading"], ["to-read", "Want to read"]], "", func(k): state["shelf"] = k, true)
	var skip := CheckBox.new()
	skip.text = tr("Skip books already in my library")
	skip.button_pressed = true
	skip.toggled.connect(func(on: bool): state["skip"] = on)
	opt_box.add_child(skip)
	var faceout := CheckBox.new()
	faceout.text = tr("Turn some covers to face out")
	faceout.button_pressed = true
	faceout.toggled.connect(func(on: bool): state["faceout"] = on)
	opt_box.add_child(faceout)
	var src := hud.section(c, "Source")
	var paste_box := VBoxContainer.new()
	paste_box.add_theme_constant_override("separation", 10)
	paste_box.visible = false
	hud.tiles(src, [
		{"label": "Choose CSV file", "icon": "download", "accent": true, "cb": func():
			_pick_file(func(path: String):
				_import_status.text = tr("Reading %s…") % path.get_file()
				_run_import(GoodreadsImport.parse_file(path), state.duplicate()))},
		{"label": "Paste CSV text", "icon": "pencil", "cb": func(): paste_box.visible = not paste_box.visible},
	], 2)
	src.add_child(paste_box)
	var te := TextEdit.new()
	te.placeholder_text = tr("Paste the CSV contents here")
	te.custom_minimum_size = Vector2(0, 320)
	te.wrap_mode = TextEdit.LINE_WRAPPING_NONE
	paste_box.add_child(te)
	var go := hud.button("Import pasted text", "AccentButton")
	go.pressed.connect(func(): _run_import(GoodreadsImport.parse_text(te.text), state.duplicate()))
	paste_box.add_child(go)
	_import_status = hud.label("", "MutedLabel")
	c.add_child(_import_status)
	_import_progress = ProgressBar.new()
	_import_progress.custom_minimum_size = Vector2(0, 14)
	_import_progress.show_percentage = false
	_import_progress.visible = false
	c.add_child(_import_progress)

func _pick_file(cb: Callable) -> void:
	_file_cb = cb
	if _file_dialog == null:
		_file_dialog = FileDialog.new()
		_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
		_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
		_file_dialog.filters = PackedStringArray(["*.csv ; CSV files", "*.txt ; Text files", "* ; All files"])
		_file_dialog.use_native_dialog = true
		_file_dialog.title = "Choose your Goodreads export"
		_file_dialog.size = Vector2i(980, 1500)
		_file_dialog.file_selected.connect(func(path: String):
			if _file_cb.is_valid():
				_file_cb.call(path))
		hud.root.add_child(_file_dialog)
	_file_dialog.popup_centered()

func _run_import(list: Array, opts: Dictionary) -> void:
	if list.is_empty():
		_import_status.text = tr("Could not read any books from that file. Is it a Goodreads export?")
		return
	var filter_shelf := str(opts.get("shelf", ""))
	var skip_dupes := bool(opts.get("skip", true))
	var faceout := bool(opts.get("faceout", true))
	var room_id: String = main().current_room_id()
	var added := 0
	var skipped := 0
	var new_ids: Array = []
	Library.no_save = true
	var i := 0
	for info in list:
		if filter_shelf != "" and str(info.get("exclusive_shelf", "")) != filter_shelf:
			continue
		if skip_dupes:
			var author := ""
			if info["authors"].size() > 0:
				author = str(info["authors"][0])
			if Library.find_by_isbn(str(info.get("isbn13", ""))) != "" or Library.find_by_isbn(str(info.get("isbn", ""))) != "" or Library.find_by_title_author(str(info["title"]), author) != "":
				skipped += 1
				continue
		if faceout and added % 7 == 3:
			info["face_out"] = true
		var id := Library.add_book(info)
		Library.auto_place(id, room_id, true, true, main().active_shelf_id())
		new_ids.append(id)
		added += 1
		i += 1
		if i % 25 == 0:
			_import_status.text = tr("Importing… %d books") % added
			await main().get_tree().process_frame
	Library.no_save = false
	Library.notify_bulk_change()
	Library.save()
	if added == 0:
		_import_status.text = tr("Nothing new to import (%d already in your library).") % skipped
		return
	_import_status.text = tr("Imported %d books (%d skipped). Fetching covers in the background…") % [added, skipped]
	_import_progress.visible = true
	_import_progress.value = 0
	for id in new_ids:
		BookAPI.request_cover(id)
	hud.toast("Imported %d books" % added)

func _on_cover_progress(done: int, total: int) -> void:
	if _import_progress == null or not is_instance_valid(_import_progress) or not _import_progress.visible:
		return
	if total <= 0:
		return
	_import_progress.value = 100.0 * done / total
	if done >= total:
		_import_status.text = tr("Done. Covers fetched for your new books.")
	else:
		_import_status.text = tr("Fetching covers… %d / %d") % [done, total]

# ---------------------------------------------------------------- style


func open_style() -> void:
	var c := hud.open_sheet("Library style", 0.8)
	c.add_child(hud.label("Walls, floor, shelves and colours for the whole library. Furniture is chosen per room (Room type).", "MutedLabel"))
	var current := Library.get_style_id()
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 12)
	g.add_theme_constant_override("v_separation", 12)
	for id in Styles.ids():
		var st: Dictionary = Styles.get_style(id)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 8)
		var sw := HBoxContainer.new()
		sw.add_theme_constant_override("separation", 4)
		for col in [_spec_color(st.get("wall", {})), _spec_color(st.get("floor", {})), st.get("shelf", {}).get("color_a", Color.GRAY), st.get("ui_accent", Color.WHITE)]:
			var cr := ColorRect.new()
			cr.color = col
			cr.custom_minimum_size = Vector2(0, 48)
			cr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			sw.add_child(cr)
		v.add_child(sw)
		v.add_child(_bold_label(tr(str(st["name"])), 28))
		var bl := hud.label(str(st.get("blurb", "")), "SubLabel")
		bl.max_lines_visible = 3
		bl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		v.add_child(bl)
		var b := _card_button(v, 200)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if id == current:
			b.theme_type_variation = "AccentCard"
		var sid := str(id)
		b.pressed.connect(func():
			Library.set_style(sid)
			hud.close_sheet()
			hud.toast(tr("Style: %s") % tr(str(st["name"]))))
		g.add_child(b)
	c.add_child(g)

func _spec_color(spec: Dictionary) -> Color:
	if spec.has("pbr"):
		return spec.get("tint", Color.WHITE) * Color(0.50, 0.36, 0.26)
	if spec.has("color"):
		return spec["color"]
	if spec.has("color_a"):
		return spec["color_a"]
	return Color.GRAY

# ---------------------------------------------------------------- settings


func _toggle(parent: Control, text: String, hint: String, key: String) -> void:
	var h := hud.row(14)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	v.add_theme_constant_override("separation", 2)
	v.add_child(_bold_label(text, 28))
	v.add_child(hud.label(hint, "SubLabel"))
	h.add_child(v)
	var cb := Button.new()
	cb.toggle_mode = true
	cb.button_pressed = bool(Settings.get_value(key))
	cb.text = tr("On") if cb.button_pressed else tr("Off")
	cb.theme_type_variation = "SegOn" if cb.button_pressed else "SegOff"
	cb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cb.custom_minimum_size = Vector2(120, 72)
	cb.focus_mode = Control.FOCUS_NONE
	cb.toggled.connect(func(on: bool):
		Settings.set_value(key, on)
		cb.text = tr("On") if on else tr("Off")
		cb.theme_type_variation = "SegOn" if on else "SegOff")
	h.add_child(cb)
	parent.add_child(h)


func open_settings() -> void:
	var c := hud.open_sheet("Settings", 0.9)
	var cam := hud.section(c, "Camera")
	_toggle(cam, "Invert horizontal look", "Room view: swipe right to turn left, like grabbing the room.", "invert_look_x")
	_toggle(cam, "Invert vertical look", "Room view: swipe down to look up.", "invert_look_y")
	_toggle(cam, "Invert shelf panning", "Zoomed-in shelf: swipe moves the camera instead of the shelf.", "invert_pan")
	var sens_lbl := _bold_label(tr("Look sensitivity  %d%%") % int(float(Settings.get_value("look_sensitivity")) * 100.0), 28)
	cam.add_child(sens_lbl)
	var slider := HSlider.new()
	slider.min_value = 0.4
	slider.max_value = 2.0
	slider.step = 0.1
	slider.value = float(Settings.get_value("look_sensitivity"))
	slider.custom_minimum_size = Vector2(0, 60)
	slider.value_changed.connect(func(v: float):
		Settings.set_value("look_sensitivity", v)
		sens_lbl.text = tr("Look sensitivity  %d%%") % int(v * 100.0))
	cam.add_child(slider)

	var scene := hud.section(c, "Scene")
	scene.add_child(_bold_label("Night mode", 28))
	scene.add_child(hud.label("Dark sky outside, moonlight, lamps and fire carry the room.", "SubLabel"))
	hud.segmented(scene, [["off", "Off"], ["on", "On"], ["auto", "Auto (19–07)"]], str(Settings.get_value("night_mode")), func(k): Settings.set_value("night_mode", k))

	var lang := hud.section(c, "Language")
	hud.segmented(lang, [["system", "System"], ["en", "English"], ["de", "Deutsch"]], str(Settings.get_value("language")), func(k):
		Settings.set_value("language", k)
		Settings.apply_language()
		main()._on_structure_changed()
		open_settings())

	var books := hud.section(c, "Books")
	_toggle(books, "Spine titles read top to bottom", "Off: titles read bottom to top, as on many European books.", "spine_top_down")
	books.add_child(_bold_label("Google Books API key (optional)", 28))
	books.add_child(hud.label("Without a key, search falls back to Open Library once Google's shared quota is used up.", "SubLabel"))
	var key_field := LineEdit.new()
	key_field.text = str(Settings.get_value("google_api_key"))
	key_field.placeholder_text = "AIza…"
	key_field.custom_minimum_size = Vector2(0, 76)
	key_field.text_changed.connect(func(t: String): Settings.set_value("google_api_key", t.strip_edges()))
	books.add_child(key_field)

	var data := hud.section(c, "Data", tr("%d books · %d rooms · covers cached in the app's private storage.") % [Library.book_count(), Library.room_count()])
	hud.tiles(data, [
		{"label": "Import from Goodreads", "icon": "download", "accent": true, "cb": open_import},
		{"label": "Fetch missing covers", "icon": "refresh", "cb": func():
			BookAPI.request_missing_covers()
			hud.toast("Looking for covers in the background")},
	], 2)
	hud.links(c, [
		["Reset settings", func():
			Settings.reset()
			Settings.apply_language()
			open_settings()],
		["Delete all books and rooms", func():
			confirm("Delete everything?", tr("All %d books, every room and shelf are removed. Settings are kept. This cannot be undone.") % Library.book_count(), "Delete all", func():
				Library.reset_all()
				hud.toast("Library reset")), true],
	])
	var ver := hud.label("Shelf Control 0.1.0 · Godot %s" % Engine.get_version_info()["string"], "SubLabel")
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	c.add_child(ver)

# ---------------------------------------------------------------- room menu


func open_room_menu() -> void:
	var rid: String = main().current_room_id()
	var room := Library.get_room(rid)
	if room.is_empty():
		return
	var c := hud.open_sheet(str(room["name"]), 0.9)
	var shelves: Array = Styles.around_room(room.get("shelves", []))
	var n_books := Library.room_book_count(rid)
	var summary := (tr("1 shelf") if shelves.size() == 1 else tr("%d shelves") % shelves.size()) + " · " + (tr("1 book") if n_books == 1 else tr("%d books") % n_books)
	c.add_child(hud.label(summary, "MutedLabel"))

	c.add_child(hud.label("Shelves", "SectionLabel"))
	for sh in shelves:
		var h := hud.row(14)
		var v := VBoxContainer.new()
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		v.add_theme_constant_override("separation", 2)
		v.add_child(_bold_label(str(sh["name"]), 29))
		var nb := Library.shelf_book_count(sh["id"])
		v.add_child(hud.label(tr("%s wall · spot %d") % [tr(Styles.WALL_NAMES[int(sh["wall"])]), int(sh["slot"]) + 1] + " · " + (tr("1 book") if nb == 1 else tr("%d books") % nb), "SubLabel"))
		h.add_child(v)
		h.add_child(_chevron())
		var b := _card_button(h, 104)
		var sid := str(sh["id"])
		b.pressed.connect(func():
			hud.close_sheet()
			main().enter_shelf_by_id(sid))
		c.add_child(b)
	var doors: Array = room.get("doors", [])
	var door_parts: Array = []
	for d in doors:
		door_parts.append(tr("%s wall → %s") % [tr(Styles.WALL_NAMES[int(d["wall"])]), str(Library.get_room(str(d["to"])).get("name", "?"))])
	if not door_parts.is_empty():
		c.add_child(hud.label(tr("Doors: ") + " · ".join(PackedStringArray(door_parts)), "SubLabel"))

	c.add_child(hud.spacer(6))
	c.add_child(hud.label("Furniture", "SectionLabel"))
	var type_opts: Array = []
	for tid in Styles.room_type_ids():
		type_opts.append([tid, Styles.room_type(tid)["name"]])
	hud.segmented(c, type_opts, str(room.get("type", "living")), func(k):
		Library.set_room_type(rid, k)
		hud.toast(tr("%s is now a %s") % [str(room.get("name", "")), tr(Styles.room_type(k)["name"]).to_lower()]), true)
	c.add_child(hud.spacer(6))
	c.add_child(hud.label("This room", "SectionLabel"))
	hud.tiles(c, [
		{"label": "Add shelf", "icon": "shelf", "accent": true, "cb": func(): _add_shelf_picker(rid)},
		{"label": "Rename", "icon": "pencil", "cb": func():
			prompt("Rename room", str(room["name"]), "Room name", func(t: String): Library.rename_room(rid, t))},
		{"label": "New room", "icon": "door", "cb": func():
			prompt("New room", "", "e.g. Study", func(t: String):
				var nrid := Library.add_room(t)
				Library.add_shelf(nrid, 0, 1)
				main().go_to_room_id(nrid))},
		{"label": "Style", "icon": "palette", "cb": open_style},
	], 4)
	hud.links(c, [["Delete this room", func():
		confirm(tr("Delete “%s”?") % str(room["name"]), tr("Its shelves are removed and all %d books move to the tray.") % Library.room_book_count(rid), "Delete room", func():
			Library.remove_room(rid)
			hud.toast("Room deleted · books are in the tray")), true]])


func open_room_type(_rid: String) -> void:
	# kept for callers; the room menu now offers the furniture chips inline
	open_room_menu()


func _add_shelf_picker(rid: String) -> void:
	var c := hud.open_sheet("Add a shelf", 0.85)
	c.add_child(hud.label("Pick a free spot along a wall. Spots are numbered left to right as seen from the middle of the room. Doors, the window and the fireplace keep their spots.", "MutedLabel"))
	var any := false
	for wall in 4:
		var sec := hud.section(c, tr("%s wall") % tr(Styles.WALL_NAMES[wall]))
		var g := GridContainer.new()
		g.columns = 5
		g.add_theme_constant_override("h_separation", 10)
		g.add_theme_constant_override("v_separation", 10)
		for slot in Styles.slot_count(wall):
			var b := hud.button(tr("Spot %d") % (slot + 1), "", 80)
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			b.add_theme_font_size_override("font_size", 25)
			var free := Library.is_slot_free(rid, wall, slot)
			b.disabled = not free
			if not free:
				b.text = tr("taken")
			else:
				any = true
			var w := wall
			var sl := slot
			b.pressed.connect(func():
				var sid := Library.add_shelf(rid, w, sl)
				hud.close_sheet()
				hud.toast(tr("Shelf added on the %s wall") % tr(Styles.WALL_NAMES[w]).to_lower())
				if sid != "":
					main().enter_shelf_by_id(sid))
			g.add_child(b)
		sec.add_child(g)
	if not any:
		c.add_child(hud.label("This room is full. Create a new room from the room menu.", "MutedLabel"))

# ---------------------------------------------------------------- shelf menu


func open_shelf_menu(sid: String) -> void:
	var sh := Library.get_shelf(sid)
	if sh.is_empty():
		return
	var c := hud.open_sheet(str(sh["name"]), 0.7)
	var nb := Library.shelf_book_count(sid)
	c.add_child(hud.label(tr("%s wall") % tr(Styles.WALL_NAMES[int(sh["wall"])]) + " · " + (tr("1 book") if nb == 1 else tr("%d books") % nb), "MutedLabel"))
	hud.tiles(c, [
		{"label": "Rename", "icon": "pencil", "cb": func():
			prompt("Rename shelf", str(sh["name"]), "Shelf name", func(t: String): Library.rename_shelf(sid, t))},
		{"label": "Covers out", "icon": "flip", "cb": func():
			var n := _set_face_out_all(sid, true)
			hud.close_sheet()
			hud.toast(tr("1 cover turned out") if n == 1 else tr("%d covers turned out") % n)},
		{"label": "Spines out", "icon": "book", "cb": func():
			_set_face_out_all(sid, false)
			hud.close_sheet()},
		{"label": "Empty to tray", "icon": "tray", "cb": func():
			confirm("Empty this shelf?", tr("All %d books move to the tray so you can place them elsewhere.") % Library.shelf_book_count(sid), "Empty shelf", func():
				var ids: Array = []
				for row in Library.get_shelf(sid)["rows"]:
					ids.append_array(row)
				for id in ids:
					Library.to_tray(id)
				hud.toast("Shelf emptied into the tray"))},
	], 4)
	hud.links(c, [["Delete shelf", func():
		confirm(tr("Delete “%s”?") % str(sh["name"]), tr("Its %d books move to the tray.") % Library.shelf_book_count(sid), "Delete shelf", func():
			Library.remove_shelf(sid)
			hud.toast("Shelf deleted · books are in the tray")), true]])

func _set_face_out_all(sid: String, face_out: bool) -> int:
	var s := Library.get_shelf(sid)
	var n := 0
	for ri in s["rows"].size():
		var row: Array = s["rows"][ri]
		for id in row:
			var b := Library.get_book(id)
			if bool(b.get("face_out", false)) == face_out:
				continue
			if face_out:
				var extra := float(b["width"]) - float(b["thickness"])
				if Library.row_free_width(sid, ri) < extra:
					continue
			b["face_out"] = face_out
			n += 1
	Library.placement_changed.emit([sid])
	Library.save()
	return n

# ---------------------------------------------------------------- book detail

func open_book_detail(id: String) -> void:
	var b := Library.get_book(id)
	if b.is_empty():
		return
	var c := hud.open_sheet("Book", 0.8)
	var h := hud.row(22)
	var cover := hud.make_cover_widget(b, Vector2(230, 345), 26)
	cover.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	h.add_child(cover)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 6)
	v.add_child(_bold_label(str(b["title"]), 32))
	if str(b.get("series", "")) != "":
		v.add_child(hud.label(str(b["series"]), "SubLabel"))
	v.add_child(hud.label(_short_authors(b.get("authors", []), 4) if not b.get("authors", []).is_empty() else tr("Unknown author"), "MutedLabel"))
	var meta: Array = []
	if str(b.get("year", "")) != "":
		meta.append(str(b["year"]))
	if int(b.get("pages", 0)) > 0:
		meta.append(tr("%d pages") % int(b["pages"]))
	if str(b.get("publisher", "")) != "":
		meta.append(str(b["publisher"]))
	if str(b.get("language", "")) != "":
		meta.append(str(b["language"]))
	if not meta.is_empty():
		var ml := hud.label(" · ".join(PackedStringArray(meta)), "SubLabel")
		ml.max_lines_visible = 2
		ml.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		v.add_child(ml)
	var codes: Array = []
	if str(b.get("isbn13", "")) != "":
		codes.append("ISBN-13 " + str(b["isbn13"]))
	if str(b.get("isbn", "")) != "":
		codes.append("ISBN-10 " + str(b["isbn"]))
	if not codes.is_empty():
		var cl := hud.label(" · ".join(PackedStringArray(codes)), "SmallLabel")
		v.add_child(cl)
	var rating := int(b.get("rating", 0))
	var avg := float(b.get("avg_rating", 0.0))
	var rating_bits: Array = []
	if rating > 0:
		rating_bits.append(tr("My rating %d / 5") % rating)
	if avg > 0.0:
		var cnt := int(b.get("ratings_count", 0))
		rating_bits.append(tr("Average %.1f") % avg + (" (%d)" % cnt if cnt > 0 else ""))
	if not rating_bits.is_empty():
		var sl := hud.label(" · ".join(PackedStringArray(rating_bits)), "SmallLabel")
		sl.add_theme_color_override("font_color", hud.accent())
		v.add_child(sl)
	var status := Library.status_label(b)
	var read := str(b.get("date_read", ""))
	if status != "":
		v.add_child(hud.label(status + (tr(" · finished %s") % read if read != "" else ""), "SmallLabel"))
	v.add_child(hud.spacer(4))
	var loc := Library.find_location(id)
	var where := tr("In the archive box") if str(b.get("status", "")) == "archived" else tr("On: %s") % Library.location_label(loc, id)
	if str(b.get("status", "")) == "currently-reading":
		where += tr(" · also on the reading table")
	v.add_child(hud.label(where, "SmallLabel"))
	h.add_child(v)
	c.add_child(h)
	var chips: Array = []
	for g in b.get("genres", []):
		chips.append([str(g), false])
	for t in b.get("tags", []):
		chips.append([str(t), true])
	if not chips.is_empty():
		c.add_child(_chip_row(chips))
	var desc := str(b.get("description", "")).strip_edges()
	if desc != "":
		var dl := hud.label(desc, "MutedLabel")
		dl.add_theme_font_size_override("font_size", 25)
		dl.max_lines_visible = 4
		dl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		c.add_child(dl)
		if desc.length() > 220:
			var more := hud.button("Read more", "GhostButton", 60)
			more.pressed.connect(func():
				dl.max_lines_visible = -1
				more.visible = false)
			c.add_child(more)
	var review := str(b.get("review", "")).strip_edges()
	if review != "":
		c.add_child(_bold_label("My review", 26))
		var rl := hud.label(review, "MutedLabel")
		rl.add_theme_font_size_override("font_size", 25)
		rl.max_lines_visible = 4
		rl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		c.add_child(rl)
	c.add_child(hud.spacer(4))

	var archived := str(b.get("status", "")) == "archived"
	var reading := str(b.get("status", "")) == "currently-reading"
	var actions: Array = []
	if archived:
		actions.append({"label": "Restore to a shelf", "icon": "restore", "accent": true, "cb": func():
			Library.update_book(id, {"status": ""})
			hud.close_sheet()
			hud.toast(tr("Back on %s") % Library.location_label(Library.find_location(id), id))})
	else:
		actions.append({"label": "Show on shelf", "icon": "eye", "accent": true, "disabled": not loc.has("shelf"), "cb": func():
			hud.close_sheet()
			main().enter_shelf_by_id(str(loc.get("shelf", "")))})
		actions.append({"label": "Spine out" if b.get("face_out", false) else "Cover out", "icon": "flip", "cb": func():
			var want := not bool(b.get("face_out", false))
			if want and loc.has("shelf"):
				var extra := float(b["width"]) - float(b["thickness"])
				if Library.row_free_width(loc["shelf"], loc["row"]) < extra:
					hud.toast("Not enough space on this row to turn the cover out")
					return
			Library.update_book(id, {"face_out": want})
			hud.close_sheet()})
		actions.append({"label": "Move to…", "icon": "move", "cb": func(): open_move_picker(id)})
		actions.append({"label": "Put in tray", "icon": "tray", "cb": func():
			Library.to_tray(id)
			hud.close_sheet()
			hud.toast(tr("“%s” is in the tray") % str(b["title"]))})
		actions.append({"label": "Finished reading" if reading else "Start reading", "icon": "book", "cb": func():
			Library.update_book(id, {"status": "read" if reading else "currently-reading"})
			hud.close_sheet()
			hud.toast("Marked as read" if reading else "On the reading table now")})
		actions.append({"label": "Archive", "icon": "archive", "cb": func():
			Library.update_book(id, {"status": "archived"})
			hud.close_sheet()
			hud.toast(tr("“%s” is in the archive box") % str(b["title"]))})
	actions.append({"label": "Refresh details", "icon": "refresh", "cb": func():
		hud.toast("Refreshing from the catalogue…")
		var err: String = await BookAPI.refresh_book(id)
		if err != "":
			hud.toast(err)
			return
		hud.toast("Details updated from the catalogue")
		if hud.is_dialog_open():
			open_book_detail(id)})
	actions.append({"label": "Edit details", "icon": "pencil", "cb": func(): _edit_book(id)})
	hud.tiles(c, actions, 4)
	hud.links(c, [
		["Fetch cover" if str(b.get("cover_file", "")) == "" else "Refresh cover", func():
			BookAPI.request_cover(id, true)
			hud.close_sheet()
			hud.toast("Looking for a cover…")],
		["Remove from library", func():
			confirm(tr("Remove “%s”?") % str(b["title"]), "The book is deleted from your library.", "Remove", func():
				Library.remove_book(id)
				hud.toast("Removed")), true],
	])

## Genre chips (accent tint) and tag chips (neutral) laid out in a wrapping row.
func _chip_row(chips: Array) -> Control:
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 8)
	flow.add_theme_constant_override("v_separation", 8)
	var a := hud.accent()
	for chip in chips:
		var pc := PanelContainer.new()
		var is_tag: bool = chip[1]
		var bg := Color(a.r, a.g, a.b, 0.22) if not is_tag else Color(hud.fg().r, hud.fg().g, hud.fg().b, 0.08)
		pc.add_theme_stylebox_override("panel", hud._flat(bg, 14, Vector2(14, 5)))
		var l := Label.new()
		l.text = ("#" if is_tag else "") + str(chip[0])
		l.add_theme_font_size_override("font_size", 23)
		pc.add_child(l)
		flow.add_child(pc)
	return flow


func _edit_book(id: String) -> void:
	var b := Library.get_book(id)
	var c := hud.open_sheet("Edit book", 0.9)
	var mk := func(text: String, placeholder: String, numeric := false) -> LineEdit:
		var e := LineEdit.new()
		e.text = text
		e.placeholder_text = tr(placeholder)
		e.custom_minimum_size = Vector2(0, 80)
		e.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if numeric:
			e.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
		return e
	var about := hud.section(c, "Title & author")
	var title: LineEdit = mk.call(str(b["title"]), "Title")
	var author: LineEdit = mk.call(", ".join(PackedStringArray(b.get("authors", []))), "Author(s), comma separated")
	about.add_child(title)
	about.add_child(author)
	var details := hud.section(c, "Details")
	var r := hud.row()
	var pages: LineEdit = mk.call(str(int(b.get("pages", 0))) if int(b.get("pages", 0)) > 0 else "", "Pages", true)
	var year: LineEdit = mk.call(str(b.get("year", "")), "Year")
	r.add_child(pages)
	r.add_child(year)
	details.add_child(r)
	var series: LineEdit = mk.call(str(b.get("series", "")), "Series, e.g. The Kingkiller Chronicle #1")
	details.add_child(series)
	var cls := hud.section(c, "Genres & tags")
	var genres: LineEdit = mk.call(", ".join(PackedStringArray(b.get("genres", []))), "Genres, comma separated")
	var tags: LineEdit = mk.call(", ".join(PackedStringArray(b.get("tags", []))), "Tags / tropes, comma separated")
	cls.add_child(genres)
	cls.add_child(tags)
	var rd := hud.section(c, "Reading")
	var state := {"status": str(b.get("status", "")), "rating": clamp(int(b.get("rating", 0)), 0, 5)}
	var status_opts: Array = []
	for k in Library.STATUS_KEYS:
		status_opts.append([k, Library.STATUS_LABELS[k] if k != "" else "No status"])
	hud.segmented(rd, status_opts, state["status"], func(k): state["status"] = k, true)
	rd.add_child(hud.label("My rating", "SubLabel"))
	hud.segmented(rd, [[0, "–"], [1, "1"], [2, "2"], [3, "3"], [4, "4"], [5, "5"]], state["rating"], func(k): state["rating"] = k)
	var save := hud.button("Save", "AccentButton")
	save.pressed.connect(func():
		var authors: Array = []
		for a in author.text.split(","):
			if a.strip_edges() != "":
				authors.append(a.strip_edges())
		Library.update_book(id, {
			"title": title.text.strip_edges(), "authors": authors, "pages": int(pages.text), "year": year.text.strip_edges(),
			"series": series.text.strip_edges(), "genres": Library._str_list(genres.text, 8), "tags": Library._str_list(tags.text, 12),
			"status": state["status"], "rating": int(state["rating"]),
		})
		hud.close_sheet()
		hud.toast("Saved"))
	c.add_child(save)

# ---------------------------------------------------------------- move picker


func open_move_picker(id: String) -> void:
	var b := Library.get_book(id)
	var c := hud.open_sheet(tr("Move “%s”") % str(b["title"]), 0.9)
	hud.tiles(c, [{"label": "Put in tray", "icon": "tray", "cb": func():
		Library.to_tray(id)
		hud.close_sheet()
		hud.toast("Moved to the tray")}], 3)
	for room in Library.get_rooms():
		var sec := hud.section(c, str(room["name"]))
		for sh in Styles.around_room(room.get("shelves", [])):
			sec.add_child(hud.label(tr("%s · %s wall") % [str(sh["name"]), tr(Styles.WALL_NAMES[int(sh["wall"])])], "SmallLabel"))
			var g := GridContainer.new()
			g.columns = 5
			g.add_theme_constant_override("h_separation", 8)
			var sid := str(sh["id"])
			for ri in range(sh["rows"].size() - 1, -1, -1):
				var btn := hud.button(tr("Row %d") % Library.row_number(ri) + "\n%d" % sh["rows"][ri].size(), "", 92)
				btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				btn.add_theme_font_size_override("font_size", 23)
				btn.disabled = not Library.fits_in_row(id, sid, ri)
				var row_i: int = ri
				btn.pressed.connect(func():
					if Library.place(id, sid, row_i, 9999):
						hud.close_sheet()
						hud.toast(tr("Moved to %s") % Library.location_label({"shelf": sid, "row": row_i}))
					else:
						hud.toast("That row is full"))
				g.add_child(btn)
			sec.add_child(g)

# ---------------------------------------------------------------- all books

var _books_sort := "title"
var _books_query := ""
var _books_status := "*"


func open_all_books() -> void:
	var c := hud.open_sheet(tr("All books · %d") % Library.book_count(), 0.92)
	var r := hud.row()
	var field := LineEdit.new()
	field.placeholder_text = tr("Filter by title, author, genre, tag…")
	field.text = _books_query
	field.clear_button_enabled = true
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	field.custom_minimum_size = Vector2(0, 80)
	r.add_child(field)
	var sort := OptionButton.new()
	sort.custom_minimum_size = Vector2(210, 80)
	var sorts := [["title", "Title"], ["author", "Author"], ["newest", "Newest"], ["rating", "Rating"]]
	for i in sorts.size():
		sort.add_item(tr(sorts[i][1]))
		if sorts[i][0] == _books_sort:
			sort.selected = i
	r.add_child(sort)
	c.add_child(r)
	var count := hud.label("", "SubLabel")
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 8)
	var more := hud.button("Show more")
	more.visible = false
	var state := {"limit": 40}
	var refresh := func() -> void:
		for ch in list.get_children():
			list.remove_child(ch)
			ch.queue_free()
		var ids: Array = []
		for bid in Library.sorted_book_ids(_books_sort, _books_query):
			if _books_status == "*" or str(Library.get_book(bid).get("status", "")) == _books_status:
				ids.append(bid)
		count.text = (tr("1 book") if ids.size() == 1 else tr("%d books") % ids.size()) + (tr(" matching") if _books_query != "" or _books_status != "*" else "")
		var shown: int = min(ids.size(), state["limit"])
		for i in shown:
			list.add_child(_book_row(ids[i]))
		more.visible = shown < ids.size()
		more.text = tr("Show more (%d left)") % (ids.size() - shown)
	var status_opts: Array = [["*", "All"]]
	for k in Library.STATUS_KEYS:
		if k != "":
			status_opts.append([k, Library.STATUS_LABELS[k]])
	hud.segmented(c, status_opts, _books_status, func(k):
		_books_status = k
		state["limit"] = 40
		refresh.call(), true)
	c.add_child(count)
	c.add_child(list)
	c.add_child(more)
	field.text_changed.connect(func(t: String):
		_books_query = t
		state["limit"] = 40
		refresh.call())
	sort.item_selected.connect(func(i: int):
		_books_sort = sorts[i][0]
		refresh.call())
	more.pressed.connect(func():
		state["limit"] += 40
		refresh.call())
	refresh.call()

func _book_row(id: String) -> Control:
	var b := Library.get_book(id)
	var h := hud.row(14)
	var cover := hud.make_cover_widget(b, Vector2(64, 96), 14)
	cover.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(cover)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	v.add_theme_constant_override("separation", 0)
	var t := _bold_label(str(b["title"]), 27)
	t.max_lines_visible = 1
	t.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	v.add_child(t)
	var sub := _short_authors(b.get("authors", []), 2)
	var genres: Array = b.get("genres", [])
	if not genres.is_empty():
		sub += " · " + str(genres[0])
	var sl := hud.label(sub, "SubLabel")
	sl.max_lines_visible = 1
	sl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	v.add_child(sl)
	var loc := hud.label(Library.location_label(Library.find_location(id), id), "SubLabel")
	loc.add_theme_font_size_override("font_size", 22)
	loc.max_lines_visible = 1
	loc.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	v.add_child(loc)
	h.add_child(v)
	if int(b.get("rating", 0)) > 0:
		var rl := hud.label("%d/5" % int(b["rating"]), "SmallLabel")
		rl.autowrap_mode = TextServer.AUTOWRAP_OFF
		rl.custom_minimum_size = Vector2(56, 0)
		rl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		rl.add_theme_color_override("font_color", hud.accent())
		h.add_child(rl)
	var btn := _card_button(h, 118)
	btn.pressed.connect(func(): open_book_detail(id))
	return btn

# ---------------------------------------------------------------- reading table & archive box

func open_reading_list() -> void:
	var ids := Library.reading_ids()
	var c := hud.open_sheet(tr("Reading table · %d") % ids.size(), 0.62)
	if ids.is_empty():
		c.add_child(hud.label("Nothing on the table yet.", "SubLabel"))
		c.add_child(hud.label("Open a book and tap “Start reading”, or set its status to Reading. It shows up here and stays in its shelf as a ghost so you know where it belongs.", "MutedLabel"))
		return
	c.add_child(hud.label("These books keep their shelf spot as a ghost. Tap one, then “Show on shelf” or “Finished reading”.", "MutedLabel"))
	for id in ids:
		c.add_child(_book_row(id))

func open_archive() -> void:
	var ids := Library.archived_ids()
	var c := hud.open_sheet(tr("Archive box · %d") % ids.size(), 0.62)
	if ids.is_empty():
		c.add_child(hud.label("The box is empty.", "SubLabel"))
		c.add_child(hud.label("Archive a book from its detail sheet to take it off the shelves without deleting it. Restoring it puts it back on a free spot.", "MutedLabel"))
		return
	c.add_child(hud.label("Archived books are out of the shelves. Restore one to put it back on a free spot.", "MutedLabel"))
	for id in ids:
		var h := hud.row(10)
		var row := _book_row(id)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(row)
		var restore := hud.button("Restore", "GhostButton", 118)
		restore.custom_minimum_size = Vector2(160, 118)
		var bid: String = id
		restore.pressed.connect(func():
			Library.update_book(bid, {"status": ""})
			hud.toast(tr("Back on %s") % Library.location_label(Library.find_location(bid), bid))
			open_archive())
		h.add_child(restore)
		c.add_child(h)

# ---------------------------------------------------------------- generic

func prompt(title: String, initial: String, placeholder: String, cb: Callable) -> void:
	var c := hud.open_sheet(title, 0.42)
	var field := LineEdit.new()
	field.text = initial
	field.placeholder_text = tr(placeholder)
	field.custom_minimum_size = Vector2(0, 88)
	c.add_child(field)
	var r := hud.row()
	var cancel := hud.button("Cancel")
	cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel.pressed.connect(hud.close_sheet)
	r.add_child(cancel)
	var ok := hud.button("Save", "AccentButton")
	ok.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var submit := func():
		var t := field.text.strip_edges()
		if t == "":
			return
		hud.close_sheet()
		cb.call(t)
	ok.pressed.connect(submit)
	field.text_submitted.connect(func(_t): submit.call())
	r.add_child(ok)
	c.add_child(r)
	field.grab_focus()
	field.select_all()

func confirm(title: String, text: String, action: String, cb: Callable) -> void:
	var c := hud.open_sheet(title, 0.4)
	c.add_child(hud.label(text, "MutedLabel"))
	var r := hud.row()
	var cancel := hud.button("Cancel")
	cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel.pressed.connect(hud.close_sheet)
	r.add_child(cancel)
	var ok := hud.button(action, "DangerButton")
	ok.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ok.pressed.connect(func():
		hud.close_sheet()
		cb.call())
	r.add_child(ok)
	c.add_child(r)
