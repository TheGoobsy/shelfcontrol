class_name GoodreadsImport
## Parses Goodreads library-export CSV files into book info dictionaries.

static func parse_file(path: String) -> Array:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return []
	return parse_text(f.get_as_text())

static func parse_text(text: String) -> Array:
	var rows := _parse_csv(text)
	if rows.size() < 2:
		return []
	var header: Array = []
	for h in rows[0]:
		header.append(str(h).strip_edges().to_lower())
	var col := {}
	for i in header.size():
		col[header[i]] = i
	if not col.has("title"):
		return []
	var out: Array = []
	for ri in range(1, rows.size()):
		var row: Array = rows[ri]
		var title := _field(row, col, "title")
		if title == "":
			continue
		var authors: Array = []
		var a := _field(row, col, "author")
		if a != "":
			authors.append(a)
		var extra := _field(row, col, "additional authors")
		if extra != "":
			for x in extra.split(","):
				var xs := x.strip_edges()
				if xs != "":
					authors.append(xs)
		var year := _field(row, col, "original publication year")
		if year == "":
			year = _field(row, col, "year published")
		var tags: Array = []
		for t in _field(row, col, "bookshelves").split(","):
			var ts := t.strip_edges()
			if ts != "":
				tags.append(ts)
		var series := ""
		var m := _series_re().search(title)
		if m:
			title = m.get_string(1).strip_edges()
			series = m.get_string(2).strip_edges()
			if m.get_string(3) != "":
				series += " #" + m.get_string(3)
		var info := {
			"title": title,
			"series": series,
			"authors": authors,
			"avg_rating": float(_field(row, col, "average rating")),
			"status": _field(row, col, "exclusive shelf"),
			"review": _field(row, col, "my review"),
			"isbn": _clean_isbn(_field(row, col, "isbn")),
			"isbn13": _clean_isbn(_field(row, col, "isbn13")),
			"pages": int(_field(row, col, "number of pages")),
			"year": year,
			"rating": int(_field(row, col, "my rating")),
			"publisher": _field(row, col, "publisher"),
			"tags": tags,
			"exclusive_shelf": _field(row, col, "exclusive shelf"),
			"date_read": _field(row, col, "date read"),
			"source": "goodreads",
		}
		out.append(info)
	return out

static var _series_regex: RegEx

static func _series_re() -> RegEx:
	if _series_regex == null:
		_series_regex = RegEx.new()
		_series_regex.compile("^(.*?)\\s*\\(([^()#]+?)(?:,?\\s*#\\s*([\\d.]+))?\\)\\s*$")
	return _series_regex

static func _field(row: Array, col: Dictionary, key: String) -> String:
	if not col.has(key):
		return ""
	var i: int = col[key]
	if i >= row.size():
		return ""
	return str(row[i]).strip_edges()

static func _clean_isbn(s: String) -> String:
	var out := ""
	for ch in s:
		if (ch >= "0" and ch <= "9") or ch == "X" or ch == "x":
			out += ch
	return out

## Minimal RFC-4180 CSV parser (quotes, doubled quotes, embedded newlines).
static func _parse_csv(text: String) -> Array:
	var rows: Array = []
	var row: Array = []
	var field := ""
	var in_quotes := false
	var i := 0
	var n := text.length()
	while i < n:
		var c := text[i]
		if in_quotes:
			if c == "\"":
				if i + 1 < n and text[i + 1] == "\"":
					field += "\""
					i += 1
				else:
					in_quotes = false
			else:
				field += c
		else:
			if c == "\"":
				in_quotes = true
			elif c == ",":
				row.append(field)
				field = ""
			elif c == "\n" or c == "\r":
				if c == "\r" and i + 1 < n and text[i + 1] == "\n":
					i += 1
				row.append(field)
				field = ""
				if row.size() > 1 or str(row[0]) != "":
					rows.append(row)
				row = []
			else:
				field += c
		i += 1
	if field != "" or row.size() > 0:
		row.append(field)
		rows.append(row)
	return rows
