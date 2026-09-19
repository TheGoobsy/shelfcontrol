class_name DemoData
## Offline sample library used by --demo (screenshots, dev runs).

const BOOKS := [
	["The Name of the Wind", "Patrick Rothfuss", 662, 2007],
	["Dune", "Frank Herbert", 412, 1965],
	["The Left Hand of Darkness", "Ursula K. Le Guin", 304, 1969],
	["Piranesi", "Susanna Clarke", 245, 2020],
	["The Hobbit", "J.R.R. Tolkien", 310, 1937],
	["Circe", "Madeline Miller", 393, 2018],
	["Project Hail Mary", "Andy Weir", 476, 2021],
	["The Shadow of the Wind", "Carlos Ruiz Zafón", 487, 2001],
	["Norwegian Wood", "Haruki Murakami", 296, 1987],
	["A Gentleman in Moscow", "Amor Towles", 462, 2016],
	["The Secret History", "Donna Tartt", 559, 1992],
	["Kafka on the Shore", "Haruki Murakami", 505, 2002],
	["Sapiens", "Yuval Noah Harari", 443, 2011],
	["Thinking, Fast and Slow", "Daniel Kahneman", 499, 2011],
	["The Night Circus", "Erin Morgenstern", 387, 2011],
	["Cloud Atlas", "David Mitchell", 509, 2004],
	["The Remains of the Day", "Kazuo Ishiguro", 258, 1989],
	["Stoner", "John Williams", 288, 1965],
	["Gödel, Escher, Bach", "Douglas Hofstadter", 777, 1979],
	["The Wind-Up Bird Chronicle", "Haruki Murakami", 607, 1994],
	["Hyperion", "Dan Simmons", 482, 1989],
	["Neuromancer", "William Gibson", 271, 1984],
	["The Master and Margarita", "Mikhail Bulgakov", 384, 1967],
	["East of Eden", "John Steinbeck", 601, 1952],
	["Educated", "Tara Westover", 334, 2018],
	["The Overstory", "Richard Powers", 502, 2018],
	["Pachinko", "Min Jin Lee", 490, 2017],
	["The Goldfinch", "Donna Tartt", 771, 2013],
	["Braiding Sweetgrass", "Robin Wall Kimmerer", 390, 2013],
	["Klara and the Sun", "Kazuo Ishiguro", 303, 2021],
	["The Fifth Season", "N.K. Jemisin", 468, 2015],
	["Children of Time", "Adrian Tchaikovsky", 600, 2015],
	["The Silmarillion", "J.R.R. Tolkien", 365, 1977],
	["Meditations", "Marcus Aurelius", 254, 180],
	["Ficciones", "Jorge Luis Borges", 174, 1944],
	["The Little Prince", "Antoine de Saint-Exupéry", 96, 1943],
	["Anathem", "Neal Stephenson", 937, 2008],
	["Red Rising", "Pierce Brown", 382, 2014],
	["Station Eleven", "Emily St. John Mandel", 333, 2014],
	["The Sparrow", "Mary Doria Russell", 408, 1996],
	["Invisible Cities", "Italo Calvino", 165, 1972],
	["Mistborn", "Brandon Sanderson", 541, 2006],
	["The Bell Jar", "Sylvia Plath", 244, 1963],
	["Wolf Hall", "Hilary Mantel", 604, 2009],
	["The Sandman Vol. 1", "Neil Gaiman", 240, 1989],
	["Blindness", "José Saramago", 326, 1995],
	["The Three-Body Problem", "Liu Cixin", 400, 2008],
	["Beloved", "Toni Morrison", 324, 1987],
	["Gilead", "Marilynne Robinson", 247, 2004],
	["Middlemarch", "George Eliot", 880, 1871],
	["The Dispossessed", "Ursula K. Le Guin", 341, 1974],
	["A Short History of Nearly Everything", "Bill Bryson", 544, 2003],
	["The Song of Achilles", "Madeline Miller", 378, 2011],
	["Snow Crash", "Neal Stephenson", 470, 1992],
	["Never Let Me Go", "Kazuo Ishiguro", 288, 2005],
	["Lonesome Dove", "Larry McMurtry", 858, 1985],
	["The Pillars of the Earth", "Ken Follett", 973, 1989],
	["Watership Down", "Richard Adams", 478, 1972],
	["The Brothers Karamazov", "Fyodor Dostoevsky", 796, 1880],
	["Jonathan Strange & Mr Norrell", "Susanna Clarke", 782, 2004],
]

## `style_id` has to be known up front: a room's furniture is seeded from the style's own
## arrangement, so setting the style afterwards would leave the cabin's armchair standing
## in a castle.
static func populate(style_id := "cozy_cabin") -> void:
	Library.no_save = true
	# a fixed prefix makes the furniture ids repeat, and with them every piece's look
	Furniture.id_prefix = "demo"
	Furniture._serial = 0
	Library.data = Library._default_data()
	Library.data["style"] = style_id
	var living := Library.add_room("Living Room", false)
	_furnish(living, "living")
	Library.add_shelf(living, 0, 1, false, "Fiction A")
	Library.add_shelf(living, 0, 3, false, "Fiction B")
	Library.add_shelf(living, 3, 1, false, "Non-fiction")
	Library.add_shelf(living, 3, 2, false, "Favourites")
	Library.add_shelf(living, 1, 0, false, "To read")
	var study := Library.add_room("Study", false)
	_furnish(study, "office")
	Library.add_shelf(study, 0, 2, false, "Reference")
	Library.add_shelf(study, 2, 0, false, "Classics")
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var i := 0
	for b in BOOKS:
		var genre_pool := ["Fantasy", "Science Fiction", "Literary Fiction", "History", "Philosophy", "Classics", "Memoir", "Mystery"]
		var pub_pool := ["Vintage", "Penguin", "Faber", "Picador", "Gollancz", "Tor", "Hogarth", "Bloomsbury"]
		var info := {"title": b[0], "authors": [b[1]], "pages": b[2], "year": str(b[3]), "rating": (i % 5) + 1, "face_out": i % 9 == 4, "source": "demo",
			"publisher": pub_pool[(i * 5 + 2) % pub_pool.size()],
			"genres": [genre_pool[i % genre_pool.size()], genre_pool[(i * 3 + 1) % genre_pool.size()]], "language": "English",
			"avg_rating": 3.6 + (i % 14) * 0.1, "ratings_count": 1200 + i * 731, "status": ["read", "to-read", "read", "read", "currently-reading", "read", "to-read"][i % 7]}
		if i % 11 == 7:
			info["status"] = "archived"
		if i == 0:
			info["series"] = "The Kingkiller Chronicle #1"
			info["isbn13"] = "9780756404741"
			info["isbn"] = "0756404746"
			info["tags"] = ["found family", "slow burn", "magic school"]
			info["description"] = "Told in Kvothe's own voice, this is the tale of the magically gifted young man who grows to be the most notorious wizard his world has ever seen. The intimate narrative of his childhood in a troupe of traveling players, his years spent as a near-feral orphan in a crime-ridden city, his daringly brazen yet successful bid to enter a legendary school of magic, and his life as a fugitive after the murder of a king form a gripping coming-of-age story."
		var id := Library.add_book(info)
		i += 1
		if info["status"] == "archived":
			continue
		var room := Library.get_room(living if i <= 46 else study)
		var placed := false
		for attempt in 12:
			var s: Dictionary = room["shelves"][rng.randi() % mini(room["shelves"].size(), 3)]
			var r := 1 + rng.randi() % 3
			if Library.fits_in_row(id, s["id"], r) and Library.row_free_width(s["id"], r) > 0.35:
				Library._quiet_place(id, s["id"], r, s["rows"][r].size(), true)
				placed = true
				break
		if not placed:
			Library.auto_place(id, room["id"], true, true)
	# a third room to show a chain turn: entered from the north, so its window moves to the west wall
	var attic := Library.add_room("Attic", false)
	_furnish(attic, "bedroom")
	Library.add_shelf(attic, 1, 0, false, "Keepsakes")
	# a couple of books in the tray
	var t1 := Library.add_book({"title": "Exhalation", "authors": ["Ted Chiang"], "pages": 350, "year": "2019", "source": "demo"})
	var t2 := Library.add_book({"title": "The Buried Giant", "authors": ["Kazuo Ishiguro"], "pages": 317, "year": "2015", "source": "demo"})
	Library.to_tray(t1)
	Library.to_tray(t2)
	Library.structure_changed.emit()

## The demo library wants rooms that already look lived in, so two of them are furnished
## from the sets rooms used to be typed with, on top of the starter table and box.
static func _furnish(rid: String, legacy_type: String) -> void:
	var room := Library.get_room(rid)
	Library.set_furniture(rid, Furniture.legacy_arrangement(legacy_type, room, Styles.get_style(Library.get_style_id())), false)
