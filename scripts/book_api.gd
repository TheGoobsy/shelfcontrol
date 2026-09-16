extends Node
## Book metadata search (Google Books → Open Library fallback) and cover caching (autoload "BookAPI").

signal cover_ready(book_id: String, texture: Texture2D)
signal cover_progress(done: int, total: int)

const COVER_DIR := "user://covers"
const MAX_ACTIVE := 3
const UA := "User-Agent: ShelfControl/0.1 (Godot; +https://github.com)"

var _tex_cache: Dictionary = {}    # book_id -> Texture2D
var _thumb_cache: Dictionary = {}  # url -> Texture2D
var _thumb_pending: Dictionary = {}
var _queue: Array = []
var _active := 0
var _queued_total := 0
var _queued_done := 0

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(COVER_DIR)

func is_busy() -> bool:
	return _active > 0 or not _queue.is_empty()

# ---------------------------------------------------------------- http

func _http(url: String, timeout := 20.0) -> Dictionary:
	var req := HTTPRequest.new()
	req.timeout = timeout
	req.accept_gzip = true
	add_child(req)
	var err := req.request(url, [UA])
	if err != OK:
		req.queue_free()
		return {"code": 0, "body": PackedByteArray(), "headers": PackedStringArray(), "error": err}
	var res: Array = await req.request_completed
	req.queue_free()
	return {"result": res[0], "code": res[1], "headers": res[2], "body": res[3]}

func _json(r: Dictionary) -> Variant:
	if r.get("code", 0) != 200:
		return null
	return JSON.parse_string((r["body"] as PackedByteArray).get_string_from_utf8())

# ---------------------------------------------------------------- search

func search(query: String) -> Array:
	var q := query.strip_edges()
	if q == "":
		return []
	var results := await _search_google(q)
	if results.is_empty():
		results = await _search_openlibrary(q)
	return results

func _search_google(q: String) -> Array:
	var url := "https://www.googleapis.com/books/v1/volumes?q=%s&maxResults=20&printType=books" % q.uri_encode()
	var key := str(Settings.get_value("google_api_key")).strip_edges()
	if key != "":
		url += "&key=" + key.uri_encode()
	var json = _json(await _http(url))
	if typeof(json) != TYPE_DICTIONARY or not json.has("items"):
		return []
	var out: Array = []
	for item in json["items"]:
		var info := _google_volume_to_info(item)
		if info.get("title", "") != "":
			out.append(info)
	return out

func _google_volume_to_info(item: Dictionary) -> Dictionary:
	var vi: Dictionary = item.get("volumeInfo", {})
	var info := {
		"title": str(vi.get("title", "")),
		"authors": vi.get("authors", []),
		"pages": int(vi.get("pageCount", 0)),
		"year": _year(str(vi.get("publishedDate", "")).left(4)),
		"publisher": str(vi.get("publisher", "")),
		"description": str(vi.get("description", "")),
		"genres": clean_genres(vi.get("categories", [])),
		"language": language_name(str(vi.get("language", ""))),
		"avg_rating": float(vi.get("averageRating", 0.0)),
		"ratings_count": int(vi.get("ratingsCount", 0)),
		"source": "google",
	}
	var sub := str(vi.get("subtitle", ""))
	if sub != "":
		info["title"] += ": " + sub
	for ident in vi.get("industryIdentifiers", []):
		if ident.get("type", "") == "ISBN_13":
			info["isbn13"] = str(ident.get("identifier", ""))
		elif ident.get("type", "") == "ISBN_10":
			info["isbn"] = str(ident.get("identifier", ""))
	var links: Dictionary = vi.get("imageLinks", {})
	var thumb := str(links.get("thumbnail", links.get("smallThumbnail", "")))
	if thumb != "":
		info["cover_url"] = thumb.replace("http://", "https://").replace("&edge=curl", "")
	return info

func _search_openlibrary(q: String) -> Array:
	var url := "https://openlibrary.org/search.json?q=%s&limit=20&fields=title,author_name,isbn,cover_i,number_of_pages_median,first_publish_year,publisher,subject,language,ratings_average,ratings_count,first_sentence" % q.uri_encode()
	var json = _json(await _http(url))
	if typeof(json) != TYPE_DICTIONARY:
		return []
	var out: Array = []
	for doc in json.get("docs", []):
		var info := {
			"title": str(doc.get("title", "")),
			"authors": doc.get("author_name", []),
			"pages": int(doc.get("number_of_pages_median", 0)),
			"year": _year(doc.get("first_publish_year", "")),
			"genres": clean_genres(doc.get("subject", [])),
			"avg_rating": float(doc.get("ratings_average", 0.0)),
			"ratings_count": int(doc.get("ratings_count", 0)),
			"source": "openlibrary",
		}
		var langs: Array = doc.get("language", [])
		if langs.size() > 0:
			info["language"] = language_name(str(langs[0]))
		var fs = doc.get("first_sentence", [])
		if typeof(fs) == TYPE_ARRAY and fs.size() > 0:
			info["description"] = str(fs[0])
		var pubs: Array = doc.get("publisher", [])
		if pubs.size() > 0:
			info["publisher"] = str(pubs[0])
		for i in doc.get("isbn", []):
			var s := str(i)
			if s.length() == 13 and not info.has("isbn13"):
				info["isbn13"] = s
			elif s.length() == 10 and not info.has("isbn"):
				info["isbn"] = s
		if doc.has("cover_i") and int(doc["cover_i"]) > 0:
			info["cover_url"] = "https://covers.openlibrary.org/b/id/%d-L.jpg" % int(doc["cover_i"])
		if info["title"] != "":
			out.append(info)
	return out

## Re-fetches catalogue data for a book (by ISBN first, then title + author) and merges it in.
## Personal fields (rating, status, review, tags, series, date read, face-out) are never touched.
## Returns "" on success or a short reason for a toast.
func refresh_book(id: String) -> String:
	var b := Library.get_book(id)
	if b.is_empty():
		return "Book not found"
	var info: Dictionary = {}
	for key in ["isbn13", "isbn"]:
		var code := str(b.get(key, "")).strip_edges()
		if code != "":
			info = await lookup_isbn(code)
			if not info.is_empty():
				break
	if info.is_empty():
		var q := str(b.get("title", ""))
		var authors: Array = b.get("authors", [])
		if not authors.is_empty():
			q += " " + str(authors[0])
		var results := await search(q)
		if not results.is_empty():
			info = results[0]
	if info.is_empty():
		return "Nothing found online for this book"
	var fields := {}
	for key in ["title", "authors", "pages", "year", "publisher", "description", "genres", "language", "avg_rating", "ratings_count", "isbn", "isbn13", "cover_url", "source"]:
		if not info.has(key):
			continue
		var v = info[key]
		var empty: bool = (typeof(v) == TYPE_STRING and str(v).strip_edges() == "") or (typeof(v) == TYPE_ARRAY and v.is_empty()) or ((typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT) and float(v) <= 0.0)
		if empty:
			continue
		if key == "genres":
			v = Library._str_list(v, 6)
		fields[key] = v
	var old_cover := str(b.get("cover_url", ""))
	Library.update_book(id, fields)
	if str(b.get("cover_file", "")) == "" or (fields.has("cover_url") and fields["cover_url"] != old_cover):
		request_cover(id, true)
	return ""

func lookup_isbn(isbn: String) -> Dictionary:
	isbn = isbn.strip_edges()
	if isbn == "":
		return {}
	var g := await _search_google("isbn:" + isbn)
	if not g.is_empty():
		return g[0]
	var url := "https://openlibrary.org/api/books?bibkeys=ISBN:%s&format=json&jscmd=data" % isbn
	var json = _json(await _http(url))
	if typeof(json) != TYPE_DICTIONARY or json.is_empty():
		return {}
	var d: Dictionary = json.values()[0]
	var authors: Array = []
	for a in d.get("authors", []):
		authors.append(str(a.get("name", "")))
	var info := {
		"title": str(d.get("title", "")),
		"authors": authors,
		"pages": int(d.get("number_of_pages", 0)),
		"year": _year(str(d.get("publish_date", "")).right(4)),
		"source": "openlibrary",
	}
	if isbn.length() == 13:
		info["isbn13"] = isbn
	else:
		info["isbn"] = isbn
	var cover: Dictionary = d.get("cover", {})
	if cover.has("large"):
		info["cover_url"] = str(cover["large"]).replace("http://", "https://")
	var subjects: Array = []
	for sub in d.get("subjects", []):
		subjects.append(str(sub.get("name", "")))
	info["genres"] = clean_genres(subjects)
	var pubs: Array = d.get("publishers", [])
	if pubs.size() > 0:
		info["publisher"] = str(pubs[0].get("name", ""))
	return info

const JUNK_SUBJECTS := ["accessible book", "protected daisy", "in library", "large type books", "overdrive", "open library staff picks", "new york times bestseller", "nyt:", "reading level", "lending library", "long now manual for civilization", "specimens", "translations into"]
const LANGUAGES := {"en": "English", "eng": "English", "de": "German", "ger": "German", "deu": "German", "fr": "French", "fre": "French", "fra": "French", "es": "Spanish", "spa": "Spanish", "it": "Italian", "ita": "Italian", "ja": "Japanese", "jpn": "Japanese", "nl": "Dutch", "dut": "Dutch", "pt": "Portuguese", "por": "Portuguese", "ru": "Russian", "rus": "Russian", "sv": "Swedish", "swe": "Swedish", "pl": "Polish", "pol": "Polish", "zh": "Chinese", "chi": "Chinese", "und": ""}

static func language_name(code: String) -> String:
	var c := code.strip_edges().to_lower()
	if c == "":
		return ""
	return LANGUAGES.get(c, code)

## Turns Google categories ("Fiction / Fantasy / Epic") and Open Library subjects into a short clean list.
static func clean_genres(raw: Array, limit := 6) -> Array:
	var out: Array = []
	for item in raw:
		for part in str(item).split("/"):
			var g := part.strip_edges()
			if g == "" or g.length() > 32:
				continue
			var low := g.to_lower()
			var junk := false
			for j in JUNK_SUBJECTS:
				if low.contains(j):
					junk = true
					break
			if junk or low.begins_with("places:") or low.begins_with("people:") or low.begins_with("times:") or low.is_valid_int():
				continue
			g = g.capitalize() if g == low else g
			if not out.has(g):
				out.append(g)
			if out.size() >= limit:
				return out
	return out

static func _year(v: Variant) -> String:
	if typeof(v) == TYPE_FLOAT or typeof(v) == TYPE_INT:
		return str(int(v)) if int(v) > 0 else ""
	var s := str(v).strip_edges()
	if s.is_valid_float() and s.contains("."):
		return str(int(float(s)))
	return s

# ---------------------------------------------------------------- covers

func get_cover_texture(book: Dictionary) -> Texture2D:
	var id := str(book.get("id", ""))
	if _tex_cache.has(id):
		return _tex_cache[id]
	var file := str(book.get("cover_file", ""))
	if file != "" and FileAccess.file_exists(file):
		var img := Image.new()
		if img.load(file) == OK:
			var tex := ImageTexture.create_from_image(img)
			_tex_cache[id] = tex
			return tex
	return null

func request_cover(book_id: String, force := false) -> void:
	var b := Library.get_book(book_id)
	if b.is_empty():
		return
	if not force and (str(b.get("cover_file", "")) != "" or b.get("cover_tried", false)):
		return
	if _queue.has(book_id):
		return
	_queue.append(book_id)
	_queued_total += 1
	_pump()

## Called once per launch: retries every book that still has no cover file.
func request_missing_covers() -> void:
	for id in Library.all_book_ids():
		var b := Library.get_book(id)
		if str(b.get("cover_file", "")) == "" or not FileAccess.file_exists(str(b.get("cover_file", ""))):
			request_cover(id, true)

func _pump() -> void:
	while _active < MAX_ACTIVE and not _queue.is_empty():
		var id: String = _queue.pop_front()
		_active += 1
		_download_cover(id)

func _cover_candidates(b: Dictionary) -> Array:
	var out: Array = []
	var url := str(b.get("cover_url", ""))
	if url != "":
		if url.contains("zoom=1"):
			out.append(url.replace("zoom=1", "zoom=2"))
		out.append(url)
	for key in ["isbn13", "isbn"]:
		var isbn := str(b.get(key, ""))
		if isbn != "":
			out.append("https://covers.openlibrary.org/b/isbn/%s-L.jpg?default=false" % isbn)
	return out

func _download_cover(id: String) -> void:
	var b := Library.get_book(id)
	var candidates := _cover_candidates(b)
	var img: Image = null
	for url in candidates:
		img = await _fetch_image(url)
		if img != null:
			break
	if img == null and not b.is_empty():
		# last resort: search by title/author to find any edition with a cover
		var q := "intitle:%s" % str(b["title"]).uri_encode()
		if b["authors"].size() > 0:
			q += "+inauthor:%s" % str(b["authors"][0]).uri_encode()
		var res := await _search_google(q)
		for r in res:
			if r.has("cover_url"):
				img = await _fetch_image(str(r["cover_url"]).replace("zoom=1", "zoom=2"))
				if img == null:
					img = await _fetch_image(str(r["cover_url"]))
				if img != null:
					if not b.has("cover_url") or b["cover_url"] == "":
						b["cover_url"] = r["cover_url"]
					break
	if img != null and Library.has_book(id):
		var path := "%s/%s.jpg" % [COVER_DIR, id]
		img.save_jpg(path, 0.88)
		var tex := ImageTexture.create_from_image(img)
		_tex_cache[id] = tex
		Library.update_book(id, {"cover_file": path, "color": spine_color_from_image(img).to_html(false), "cover_tried": true})
		cover_ready.emit(id, tex)
	elif Library.has_book(id):
		Library.update_book(id, {"cover_tried": true})
	_active -= 1
	_queued_done += 1
	cover_progress.emit(_queued_done, _queued_total)
	if _queue.is_empty() and _active == 0:
		_queued_total = 0
		_queued_done = 0
	_pump()

func _fetch_image(url: String) -> Image:
	var r := await _http(url, 25.0)
	var body: PackedByteArray = r.get("body", PackedByteArray())
	if r.get("code", 0) != 200:
		print("[BookAPI] image %s → result=%s code=%s" % [url.left(80), str(r.get("result", "?")), str(r.get("code", 0))])
		return null
	if body.size() < 1500:
		print("[BookAPI] image too small (%d bytes): %s" % [body.size(), url.left(80)])
		return null
	var img := decode_image(body)
	if img == null or img.get_width() < 24 or img.get_height() < 24:
		print("[BookAPI] image decode failed (%d bytes): %s" % [body.size(), url.left(80)])
		return null
	return img

static func decode_image(body: PackedByteArray) -> Image:
	var img := Image.new()
	var err := ERR_INVALID_DATA
	if body.size() > 12:
		if body[0] == 0x89 and body[1] == 0x50:
			err = img.load_png_from_buffer(body)
		elif body[0] == 0xFF and body[1] == 0xD8:
			err = img.load_jpg_from_buffer(body)
		elif body[0] == 0x52 and body[1] == 0x49 and body[8] == 0x57 and body[9] == 0x45:
			err = img.load_webp_from_buffer(body)
		else:
			err = img.load_jpg_from_buffer(body)
			if err != OK:
				err = img.load_png_from_buffer(body)
	if err != OK:
		return null
	if img.is_compressed():
		img.decompress()
	if img.get_format() != Image.FORMAT_RGB8 and img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)
	return img

static func spine_color_from_image(src: Image) -> Color:
	var img := src.duplicate() as Image
	img.resize(12, 18, Image.INTERPOLATE_BILINEAR)
	var r := 0.0
	var g := 0.0
	var b := 0.0
	var n := 0
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			r += c.r
			g += c.g
			b += c.b
			n += 1
	var avg := Color(r / n, g / n, b / n)
	var h := avg.h
	var s := avg.s
	var v := avg.v
	return Color.from_hsv(h, clamp(s * 1.25, 0.12, 0.9), clamp(v, 0.16, 0.78))

func get_thumbnail(url: String) -> Texture2D:
	if url == "":
		return null
	if _thumb_cache.has(url):
		return _thumb_cache[url]
	var img := await _fetch_image(url)
	if img == null:
		return null
	var tex := ImageTexture.create_from_image(img)
	_thumb_cache[url] = tex
	return tex
