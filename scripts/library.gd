extends Node
## Library data model + persistence (autoload "Library").
##
## data = {
##   version, style,
##   rooms: [ { id, name, shelves: [ { id, name, wall, slot, rows: [[book_id, ...], ...] } ] } ],
##   books: { id: { id, title, authors, isbn, isbn13, pages, year, rating, cover_url, cover_file,
##                  color, height, thickness, width, face_out, tags, source } },
##   tray: [book_id, ...]
## }

signal structure_changed()                    # rooms / shelves / style changed → rebuild room
signal placement_changed(shelf_ids: Array)    # books moved within/between shelves
signal book_updated(book_id: String)          # metadata or cover changed
signal tray_changed()

const SAVE_PATH := "user://library.json"
const VERSION := 1
const SHELF_ROWS := 5
const SHELF_INNER_WIDTH := 1.13
const ROW_PADDING := 0.015
const BOOK_GAP := 0.003

const SPINE_PALETTE := [
	"#7a1f1f", "#1f3a5f", "#274e2a", "#c9982a", "#1b1b1f", "#e8dcc4", "#5d1f3a",
	"#1f6b6b", "#5a3a22", "#3b4553", "#8a3b1a", "#2b2b6b", "#6b6b1f", "#9c4a2f",
	"#2f5d8a", "#3d7a4a", "#6b2f8a", "#b8402f", "#d9a441", "#f0e6d2", "#404040",
	"#8c6d46", "#a0522d", "#1c4a3b",
]

var data: Dictionary = {}
var no_save := false
var _save_pending := false

func _ready() -> void:
	load_data()

# ---------------------------------------------------------------- persistence

func _default_data() -> Dictionary:
	return {"version": VERSION, "style": "cozy_cabin", "rooms": [], "books": {}, "tray": []}

func load_data() -> void:
	data = _default_data()
	if FileAccess.file_exists(SAVE_PATH):
		var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
		if f:
			var parsed = JSON.parse_string(f.get_as_text())
			if typeof(parsed) == TYPE_DICTIONARY:
				data = parsed
	_migrate()
	if data["rooms"].is_empty():
		var rid := add_room("Living Room", false)
		add_shelf(rid, 0, 1, false)
		add_shelf(rid, 0, 3, false)
		add_shelf(rid, 3, 1, false)
		add_shelf(rid, 3, 2, false)
	structure_changed.emit()

func _migrate() -> void:
	for k in _default_data().keys():
		if not data.has(k):
			data[k] = _default_data()[k]
	for room in data["rooms"]:
		if not room.has("shelves"):
			room["shelves"] = []
		if not room.has("type"):
			room["type"] = "living"
		for shelf in room["shelves"]:
			if not shelf.has("rows"):
				shelf["rows"] = []
			while shelf["rows"].size() < SHELF_ROWS:
				shelf["rows"].append([])
	# drop dangling ids
	for room in data["rooms"]:
		for shelf in room["shelves"]:
			for row in shelf["rows"]:
				var i := 0
				while i < row.size():
					if not data["books"].has(row[i]):
						row.remove_at(i)
					else:
						i += 1
	var t: Array = data["tray"]
	var i := 0
	while i < t.size():
		if not data["books"].has(t[i]):
			t.remove_at(i)
		else:
			i += 1
	_settle_archived()

func save() -> void:
	if no_save or _save_pending:
		return
	_save_pending = true
	_do_save.call_deferred()

func _do_save() -> void:
	_save_pending = false
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data, "\t"))

func reset_all() -> void:
	data = _default_data()
	var rid := add_room("Living Room", false)
	add_shelf(rid, 0, 1, false)
	add_shelf(rid, 0, 3, false)
	structure_changed.emit()
	tray_changed.emit()
	save()

func _new_id(prefix: String) -> String:
	return "%s_%d_%04x" % [prefix, int(Time.get_unix_time_from_system() * 1000.0) % 1000000000, randi() % 65536]

# ---------------------------------------------------------------- style

func get_style_id() -> String:
	return str(data.get("style", "cozy_cabin"))

func set_style(id: String) -> void:
	data["style"] = id
	structure_changed.emit()
	save()

# ---------------------------------------------------------------- rooms

func get_rooms() -> Array:
	return data["rooms"]

func room_count() -> int:
	return data["rooms"].size()

func get_room_at(index: int) -> Dictionary:
	if index < 0 or index >= data["rooms"].size():
		return {}
	return data["rooms"][index]

func get_room(rid: String) -> Dictionary:
	for r in data["rooms"]:
		if r["id"] == rid:
			return r
	return {}

func room_index(rid: String) -> int:
	for i in data["rooms"].size():
		if data["rooms"][i]["id"] == rid:
			return i
	return -1

func add_room(room_name: String, emit := true, room_type := "living") -> String:
	var r := {"id": _new_id("r"), "name": room_name, "shelves": [], "type": room_type}
	data["rooms"].append(r)
	if emit:
		structure_changed.emit()
		save()
	return r["id"]

func set_room_type(rid: String, room_type: String) -> void:
	var r := get_room(rid)
	if r.is_empty():
		return
	r["type"] = room_type
	structure_changed.emit()
	save()

func rename_room(rid: String, room_name: String) -> void:
	var r := get_room(rid)
	if r.is_empty():
		return
	r["name"] = room_name
	structure_changed.emit()
	save()

func remove_room(rid: String) -> void:
	var idx := room_index(rid)
	if idx < 0:
		return
	var r: Dictionary = data["rooms"][idx]
	for shelf in r["shelves"]:
		for row in shelf["rows"]:
			for bid in row:
				data["tray"].append(bid)
	data["rooms"].remove_at(idx)
	if data["rooms"].is_empty():
		var nrid := add_room("Living Room", false)
		add_shelf(nrid, 0, 1, false)
	structure_changed.emit()
	tray_changed.emit()
	save()

func room_book_count(rid: String) -> int:
	var r := get_room(rid)
	var n := 0
	for shelf in r.get("shelves", []):
		for row in shelf["rows"]:
			n += row.size()
	return n

# ---------------------------------------------------------------- shelves

func get_shelf(sid: String) -> Dictionary:
	for r in data["rooms"]:
		for s in r["shelves"]:
			if s["id"] == sid:
				return s
	return {}

func get_shelf_room(sid: String) -> Dictionary:
	for r in data["rooms"]:
		for s in r["shelves"]:
			if s["id"] == sid:
				return r
	return {}

func is_slot_free(rid: String, wall: int, slot: int) -> bool:
	var r := get_room(rid)
	for s in r.get("shelves", []):
		if int(s["wall"]) == wall and int(s["slot"]) == slot:
			return false
	return true

func free_slots(rid: String) -> Array:
	var out: Array = []
	for wall in 4:
		for slot in Styles.slot_count(wall):
			if is_slot_free(rid, wall, slot):
				out.append({"wall": wall, "slot": slot})
	return out

func add_shelf(rid: String, wall: int, slot: int, emit := true, shelf_name := "") -> String:
	var r := get_room(rid)
	if r.is_empty() or not is_slot_free(rid, wall, slot):
		return ""
	var rows: Array = []
	for i in SHELF_ROWS:
		rows.append([])
	if shelf_name == "":
		shelf_name = "Shelf %d" % (r["shelves"].size() + 1)
	var s := {"id": _new_id("s"), "name": shelf_name, "wall": wall, "slot": slot, "rows": rows}
	r["shelves"].append(s)
	if emit:
		structure_changed.emit()
		save()
	return s["id"]

func rename_shelf(sid: String, shelf_name: String) -> void:
	var s := get_shelf(sid)
	if s.is_empty():
		return
	s["name"] = shelf_name
	structure_changed.emit()
	save()

func remove_shelf(sid: String) -> void:
	var r := get_shelf_room(sid)
	if r.is_empty():
		return
	for i in r["shelves"].size():
		var s: Dictionary = r["shelves"][i]
		if s["id"] == sid:
			for row in s["rows"]:
				for bid in row:
					data["tray"].append(bid)
			r["shelves"].remove_at(i)
			break
	structure_changed.emit()
	tray_changed.emit()
	save()

func shelf_book_count(sid: String) -> int:
	var s := get_shelf(sid)
	var n := 0
	for row in s.get("rows", []):
		n += row.size()
	return n

# ---------------------------------------------------------------- books

func get_book(id: String) -> Dictionary:
	return data["books"].get(id, {})

func has_book(id: String) -> bool:
	return data["books"].has(id)

func all_book_ids() -> Array:
	return data["books"].keys()

func book_count() -> int:
	return data["books"].size()

func _seeded_rng(seed_text: String) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(seed_text)
	return rng

func derive_dimensions(book: Dictionary) -> void:
	var rng := _seeded_rng(str(book.get("title", "")) + str(book.get("isbn13", "")))
	var height := 0.185 + rng.randf() * 0.055
	var pages := int(book.get("pages", 0))
	var thickness: float
	if pages > 0:
		thickness = clamp(0.008 + pages * 0.000065, 0.010, 0.065)
	else:
		thickness = 0.018 + rng.randf() * 0.022
	book["height"] = snapped(height, 0.001)
	book["thickness"] = snapped(thickness, 0.001)
	book["width"] = snapped(clamp(height * 0.64, 0.115, 0.16), 0.001)

func derive_color(book: Dictionary) -> String:
	var rng := _seeded_rng(str(book.get("title", "")) + "|" + str(book.get("authors", [])))
	return SPINE_PALETTE[rng.randi() % SPINE_PALETTE.size()]

func _str_list(v: Variant, limit := 0) -> Array:
	var out: Array = []
	if typeof(v) == TYPE_STRING:
		for part in str(v).split(","):
			if part.strip_edges() != "":
				out.append(part.strip_edges())
	elif typeof(v) == TYPE_ARRAY:
		for x in v:
			var t := str(x).strip_edges()
			if t != "" and not out.has(t):
				out.append(t)
	if limit > 0 and out.size() > limit:
		out = out.slice(0, limit)
	return out

const STATUS_LABELS := {"": "", "read": "Read", "currently-reading": "Reading", "to-read": "Want to read", "archived": "Archived"}
const STATUS_KEYS := ["", "read", "currently-reading", "to-read", "archived"]

func status_label(book: Dictionary) -> String:
	return STATUS_LABELS.get(str(book.get("status", "")), str(book.get("status", "")).capitalize())

## Case-insensitive match against title, authors, genres, tags, series, status, year.
func book_matches(book: Dictionary, query: String) -> bool:
	var q := query.strip_edges().to_lower()
	if q == "":
		return true
	var hay := str(book.get("title", "")).to_lower() + "|" + str(book.get("series", "")).to_lower() + "|" + str(book.get("year", "")) + "|" + status_label(book).to_lower()
	for a in book.get("authors", []):
		hay += "|" + str(a).to_lower()
	for g in book.get("genres", []):
		hay += "|" + str(g).to_lower()
	for t in book.get("tags", []):
		hay += "|" + str(t).to_lower()
	for word in q.split(" "):
		if word != "" and not hay.contains(word):
			return false
	return true

## Sorted list of book ids. sort: "title" | "author" | "newest" | "rating"
func sorted_book_ids(sort: String, query := "") -> Array:
	var ids: Array = []
	for id in data["books"]:
		if book_matches(data["books"][id], query):
			ids.append(id)
	var books: Dictionary = data["books"]
	match sort:
		"author":
			ids.sort_custom(func(a, b):
				var aa := author_line(books[a]).to_lower()
				var bb := author_line(books[b]).to_lower()
				if aa == bb:
					return str(books[a]["title"]).to_lower() < str(books[b]["title"]).to_lower()
				return aa < bb)
		"newest":
			ids.sort_custom(func(a, b): return str(books[a].get("added", "")) > str(books[b].get("added", "")))
		"rating":
			ids.sort_custom(func(a, b):
				var ra := float(books[a].get("rating", 0)) * 10.0 + float(books[a].get("avg_rating", 0.0))
				var rb := float(books[b].get("rating", 0)) * 10.0 + float(books[b].get("avg_rating", 0.0))
				if ra == rb:
					return str(books[a]["title"]).to_lower() < str(books[b]["title"]).to_lower()
				return ra > rb)
		_:
			ids.sort_custom(func(a, b): return str(books[a]["title"]).to_lower() < str(books[b]["title"]).to_lower())
	return ids

func normalize_book(info: Dictionary) -> Dictionary:
	var authors: Array = []
	var a = info.get("authors", [])
	if typeof(a) == TYPE_STRING:
		if a != "":
			authors = [a]
	elif typeof(a) == TYPE_ARRAY:
		for x in a:
			authors.append(str(x))
	var tags: Array = []
	for t in info.get("tags", []):
		tags.append(str(t))
	var b := {
		"id": str(info.get("id", _new_id("b"))),
		"title": str(info.get("title", "Untitled")).strip_edges(),
		"authors": authors,
		"isbn": str(info.get("isbn", "")).strip_edges(),
		"isbn13": str(info.get("isbn13", "")).strip_edges(),
		"pages": int(info.get("pages", 0)),
		"year": str(info.get("year", "")),
		"rating": int(info.get("rating", 0)),
		"cover_url": str(info.get("cover_url", "")),
		"cover_file": str(info.get("cover_file", "")),
		"description": str(info.get("description", "")),
		"publisher": str(info.get("publisher", "")),
		"tags": tags,
		"genres": _str_list(info.get("genres", []), 6),
		"language": str(info.get("language", "")),
		"avg_rating": float(info.get("avg_rating", 0.0)),
		"ratings_count": int(info.get("ratings_count", 0)),
		"series": str(info.get("series", "")),
		"status": str(info.get("status", "")),
		"review": str(info.get("review", "")),
		"date_read": str(info.get("date_read", "")),
		"face_out": bool(info.get("face_out", false)),
		"color": str(info.get("color", "")),
		"source": str(info.get("source", "")),
		"added": Time.get_datetime_string_from_system(),
	}
	if b["title"] == "":
		b["title"] = "Untitled"
	derive_dimensions(b)
	if b["color"] == "":
		b["color"] = derive_color(b)
	return b

## Stores a new book (not placed anywhere). Returns its id.
func add_book(info: Dictionary) -> String:
	var b := normalize_book(info)
	data["books"][b["id"]] = b
	save()
	return b["id"]

func update_book(id: String, fields: Dictionary) -> void:
	var b := get_book(id)
	if b.is_empty():
		return
	var old_status := str(b.get("status", ""))
	for k in fields.keys():
		b[k] = fields[k]
	if fields.has("pages"):
		derive_dimensions(b)
	var new_status := str(b.get("status", ""))
	if new_status == "archived" and old_status != "archived":
		# into the archive box: leaves its shelf slot free
		var prev := detach(id)
		if prev.has("shelf"):
			placement_changed.emit([prev["shelf"]])
		if prev.has("tray"):
			tray_changed.emit()
	elif old_status == "archived" and new_status != "archived" and find_location(id).is_empty():
		auto_place(id)
	book_updated.emit(id)
	if fields.has("face_out"):
		var loc := find_location(id)
		if loc.has("shelf"):
			placement_changed.emit([loc["shelf"]])
	save()

func remove_book(id: String) -> void:
	var loc := find_location(id)
	detach(id)
	data["books"].erase(id)
	if loc.has("shelf"):
		placement_changed.emit([loc["shelf"]])
	tray_changed.emit()
	save()

func find_by_isbn(isbn: String) -> String:
	if isbn == "":
		return ""
	for id in data["books"]:
		var b: Dictionary = data["books"][id]
		if b.get("isbn13", "") == isbn or b.get("isbn", "") == isbn:
			return id
	return ""

func find_by_title_author(title: String, author: String) -> String:
	var t := title.strip_edges().to_lower()
	var a := author.strip_edges().to_lower()
	for id in data["books"]:
		var b: Dictionary = data["books"][id]
		if str(b["title"]).to_lower() == t:
			var ba := ""
			if b["authors"].size() > 0:
				ba = str(b["authors"][0]).to_lower()
			if a == "" or ba == a:
				return id
	return ""

func author_line(book: Dictionary) -> String:
	var authors: Array = book.get("authors", [])
	if authors.is_empty():
		return "Unknown author"
	return ", ".join(PackedStringArray(authors))

# ---------------------------------------------------------------- placement

func book_shelf_width(book: Dictionary) -> float:
	if book.get("face_out", false):
		return float(book.get("width", 0.14))
	return float(book.get("thickness", 0.03))

func row_used_width(sid: String, row: int, exclude_id := "") -> float:
	var s := get_shelf(sid)
	if s.is_empty() or row < 0 or row >= s["rows"].size():
		return INF
	var w := 0.0
	for bid in s["rows"][row]:
		if bid == exclude_id:
			continue
		var b := get_book(bid)
		w += book_shelf_width(b) + BOOK_GAP
	return w

func row_free_width(sid: String, row: int, exclude_id := "") -> float:
	return SHELF_INNER_WIDTH - 2.0 * ROW_PADDING - row_used_width(sid, row, exclude_id)

func fits_in_row(book_id: String, sid: String, row: int) -> bool:
	var b := get_book(book_id)
	if b.is_empty():
		return false
	return row_free_width(sid, row, book_id) >= book_shelf_width(b) + BOOK_GAP

## {"shelf": sid, "row": r, "index": i} | {"tray": true} | {}
func find_location(id: String) -> Dictionary:
	for r in data["rooms"]:
		for s in r["shelves"]:
			for ri in s["rows"].size():
				var idx: int = s["rows"][ri].find(id)
				if idx >= 0:
					return {"shelf": s["id"], "row": ri, "index": idx, "room": r["id"]}
	if data["tray"].has(id):
		return {"tray": true}
	return {}

## Remove a book from wherever it currently is. Returns the previous location.
func detach(id: String) -> Dictionary:
	var loc := find_location(id)
	if loc.has("shelf"):
		var s := get_shelf(loc["shelf"])
		s["rows"][loc["row"]].remove_at(loc["index"])
	elif loc.has("tray"):
		data["tray"].erase(id)
	return loc

## Place a book at shelf/row/index. Returns false (and leaves data unchanged) if it does not fit.
func place(id: String, sid: String, row: int, index: int) -> bool:
	var s := get_shelf(sid)
	var b := get_book(id)
	if s.is_empty() or b.is_empty() or row < 0 or row >= s["rows"].size():
		return false
	if not fits_in_row(id, sid, row):
		return false
	var prev := detach(id)
	var r: Array = s["rows"][row]
	index = clamp(index, 0, r.size())
	r.insert(index, id)
	var affected: Array = [sid]
	if prev.has("shelf") and prev["shelf"] != sid:
		affected.append(prev["shelf"])
	placement_changed.emit(affected)
	if prev.has("tray"):
		tray_changed.emit()
	save()
	return true

func to_tray(id: String) -> void:
	var prev := detach(id)
	if not data["tray"].has(id):
		data["tray"].append(id)
	if prev.has("shelf"):
		placement_changed.emit([prev["shelf"]])
	tray_changed.emit()
	save()

func get_tray() -> Array:
	return data["tray"]

## Finds room for the book, creating shelves/rooms if needed. Returns the location or {} on failure.
## Order: the preferred shelf (top row first), then the preferred room's shelves, then everything else.
func auto_place(id: String, prefer_room_id := "", allow_create := true, quiet := false, prefer_shelf_id := "") -> Dictionary:
	var b := get_book(id)
	if b.is_empty():
		return {}
	var shelves: Array = []
	var ps := get_shelf(prefer_shelf_id)
	if not ps.is_empty():
		shelves.append(ps)
	var order: Array = []
	var pr := get_room(prefer_room_id)
	if not pr.is_empty():
		order.append(pr)
	for r in data["rooms"]:
		if r["id"] != prefer_room_id:
			order.append(r)
	for r in order:
		for s in r["shelves"]:
			if s["id"] != prefer_shelf_id:
				shelves.append(s)
	for s in shelves:
		for ri in range(s["rows"].size() - 1, -1, -1):
			if fits_in_row(id, s["id"], ri):
				_quiet_place(id, s["id"], ri, s["rows"][ri].size(), quiet)
				return {"shelf": s["id"], "row": ri, "room": get_shelf_room(s["id"])["id"]}
	if not allow_create:
		return {}
	# new shelf in a room with a free slot
	for r in order:
		var slots := free_slots(r["id"])
		if not slots.is_empty():
			var slot: Dictionary = slots[0]
			var sid := add_shelf(r["id"], slot["wall"], slot["slot"], not quiet)
			_quiet_place(id, sid, SHELF_ROWS - 1, 0, quiet)
			return {"shelf": sid, "row": SHELF_ROWS - 1, "room": r["id"], "created_shelf": true}
	# new room
	var rid := add_room("Library %d" % (data["rooms"].size() + 1), not quiet)
	var nsid := add_shelf(rid, 0, 1, not quiet)
	_quiet_place(id, nsid, SHELF_ROWS - 1, 0, quiet)
	return {"shelf": nsid, "row": SHELF_ROWS - 1, "room": rid, "created_room": true}

func _quiet_place(id: String, sid: String, row: int, index: int, quiet: bool) -> void:
	if quiet:
		detach(id)
		var s := get_shelf(sid)
		s["rows"][row].insert(clamp(index, 0, s["rows"][row].size()), id)
	else:
		place(id, sid, row, index)

## Call after a batch of quiet operations.
func notify_bulk_change() -> void:
	structure_changed.emit()
	tray_changed.emit()
	save()

## Rows are stored bottom-up (0 = lowest board) but shown to people top-down.
func row_number(row: int) -> int:
	return SHELF_ROWS - row

func location_label(loc: Dictionary, book_id := "") -> String:
	if loc.has("shelf"):
		var s := get_shelf(loc["shelf"])
		var r := get_shelf_room(loc["shelf"])
		return "%s · %s · row %d" % [r.get("name", "?"), s.get("name", "?"), row_number(int(loc.get("row", 0)))]
	if loc.has("tray"):
		return "Tray"
	if book_id != "" and str(get_book(book_id).get("status", "")) == "archived":
		return "Archive box"
	return "Nowhere"

## Books with a given status, sorted by title.
func ids_with_status(status: String) -> Array:
	var ids: Array = []
	for id in data["books"]:
		if str(data["books"][id].get("status", "")) == status:
			ids.append(id)
	ids.sort_custom(func(a, b): return str(data["books"][a].get("title", "")).naturalnocasecmp_to(str(data["books"][b].get("title", ""))) < 0)
	return ids

func reading_ids() -> Array:
	return ids_with_status("currently-reading")

func archived_ids() -> Array:
	return ids_with_status("archived")

## Archived books that still sit in a shelf or the tray (e.g. after an import) are moved into the box.
func _settle_archived() -> void:
	for id in archived_ids():
		if not find_location(id).is_empty():
			detach(id)
