# Shelf Control

A 3D virtual library for Android, built with Godot 4.7. Walk through styled rooms, tap a bookcase to zoom in, and drag books around to arrange them. Add books from online catalogues or import your Goodreads export.

## Features

- **3D rooms** you look around by dragging. Arrow buttons at the top and faint chevrons on the left and right screen edges switch rooms (or shelves in the close-up, going around the room); the current room's name is shown at the top.
- **Bookcases on the walls.** Tap one to zoom into a close-up. In the close-up, drag a book to reorder it or move it to another row. Pinch to zoom around your fingers, double-tap empty space to zoom into that spot (and again to zoom out), two-finger drag to pan.
- **Move between shelves** by dragging a book down into the tray, then opening another shelf and tapping a spot. Or use *Move to…* in the book detail sheet to pick any room, shelf and row.
- **Add books** via search (Google Books first, Open Library as fallback), by ISBN, or manually. Covers are downloaded and cached; the average cover colour becomes the spine colour. Results already in the library are marked.
- **Metadata** per book: title, authors, series, ISBN-10/13, year, pages, publisher, language, genres, tags, description, average rating, your rating, reading status, date read and Goodreads review. All editable in the detail sheet. *Refresh details* re-fetches the catalogue fields from the APIs (by ISBN, else title + author) without touching your own rating, status, tags or review.
- **Add books** via the accent plus icon in the side column.
- **All Books overview** (list icon, top right): filter by title, author, genre, tag or status; sort by title, author, newest or rating; tap a row for details.
- **Goodreads import** (Settings → Import from Goodreads) from the CSV export (My Books → Import and export → Export Library). Filter by exclusive shelf, skip duplicates, covers are fetched in the background. Books are auto-placed; new shelves and rooms are created when a room fills up.
- **Cover-out display**: any book can stand with its cover facing out.
- **Reading table**: a coffee table on the rug holds the books whose status is *Reading*, stacked cover-up. Each of those books keeps its shelf spot, drawn as a pale ghost so you know where it belongs. Tap the table and the camera flies in and opens the list (and flies back out when you close it); the detail sheet has *Start reading* / *Finished reading* and *Show on shelf*.
- **Archive box**: a cardboard box in the corner holds *Archived* books. Archiving takes a book off its shelf without deleting it; *Restore* puts it back on the first free spot. Tap the box and the camera flies in and opens the list.
- **Six styles**: Cozy Cabin (procedural log walls, fireplace, rug), Timber Lodge (photo textures from Poly Haven: stacked timber walls, worn pine floor, plank ceiling, dark hardwood shelves with the grain following each board), Medieval Keep (castle stone walls, slate floor, plank ceiling, and CC0 Poly Haven models: gothic chairs and coffee table, potted plants and a fern, a lantern chandelier, treasure chest, crate, kite shield and a gothic statue), Modern Loft (brick, concrete, oak), Dark Academia (green wallpaper, walnut wainscot, candlelight), Scandi Bright. Each style textures the walls, floor, ceiling and shelves, tints the UI, and places decor (plants, rug, armchair, lamps, window or a fireplace with animated flames, and a sleeping cat on the rug).
- **Doors between rooms**: rooms form a chain and each pair is joined by a door with a name plate. You leave through the east or south wall, alternating, and arrive through the opposite wall, so consecutive rooms always turn like an L, never a corridor. If a room's entry lands on the north wall, its window moves to a side wall without a door. A room has at most two doors (in and out). Tap a door to swing it open and walk into the next room, arriving with your back to it. Door spots are reserved: shelves can't be added there, and a shelf already standing on one is moved to a free spot.
- **Furniture is a room's own list.** Every piece a room holds — armchair, rug, plant, fireplace, the reading table, the archive box — is an entry in that room's `furniture` list, not something a room type decided. A new room starts with just the reading table and the archive box; the rest is placed by hand. The style still decides materials and colours. Rooms saved before this are converted once, keeping the arrangement their old room type gave them.
- **Room management** (pencil icon, top right): rename rooms and shelves, add shelves, change the library style, add or delete rooms. In a shelf view the pencil edits that shelf.
- **Sorting a shelf** (shelf menu → Sort books): reorders the whole case by title, author, genre or year and repacks the rows from the top. A book that will not fit the row it lands on starts the next one.
- **Shelf name tags** (shelf menu → Name tag): an optional plate on the front of the case carrying the shelf's name, in brass, silver, wood, paper or slate.
- **Furnishing a room** (pencil icon → *Furnish*): the floor is mapped while you arrange it — green where a piece would fit, red where something already stands — and the ring of wall spots the bookcases live on is outlined on top, red where a case, a door, the window or the fireplace has claimed one. *Plan view* looks straight down (the room is turned a quarter turn so it fills a portrait screen, with the ceiling out of the way); *Room view* maps the same floor from where you are standing.
- **Placing furniture**: the inventory at the bottom holds every piece, in seven categories — functional (the reading table and the archive box), seating, tables, lighting, plants, decor and wall pieces. Tap one and it appears in your hand: drag it across the floor, *Turn* it in eighths, and *Place* it. It reads green where it would go and red where it would not, both as the box under it and as a wash over the piece itself, so a wide piece still says what it is doing. Tap a piece already standing in the room to pick it back up, then move it, turn it or bin it. Boxes may touch and tuck by about a hand's width before the editor calls it a clash, since the box around a piece standing at an angle is larger than the piece. Wall pieces — the window, the fireplace, a hung shield — snap to the nearest free wall spot, which is the same ring the bookcases use.
- **Placing a shelf**: *Add shelf* drops a see-through bookcase onto a free wall spot and turns the room to face it. The rest of the interface steps aside so nothing navigates away mid-placement. The arrows step through every free spot in the room, *Place shelf* commits and opens the new shelf, *Cancel* backs out. Spots held by a door, the window or the fireplace are not offered, so a bookcase never costs you a piece you placed.
- **Night mode** (Settings → Scene): off, on, or automatic from 19:00 to 07:00. Starry sky and moon in the window, faint moonlight, lamps and fire carry the room.
- **Menus** are bottom sheets built from a few shared parts: titled section cards, icon tile grids for actions, chip rows for exclusive choices (room type, status, night mode, filters), and quiet text links for rare or destructive actions. Sheets size to their content and lift above the keyboard.
- **Languages**: English and German (Settings → Language: System / English / Deutsch). Strings live in `translations/ui.csv` (English text as key); Godot imports it into `.translation` files listed in `project.godot`.
- **Settings** (gear icon, top right): invert horizontal/vertical look, invert shelf panning, look sensitivity, spine text direction, optional Google Books API key, re-fetch covers, reset. Stored in `user://settings.json`.

Everything is stored locally in `user://library.json` with covers in `user://covers/`.

## Project layout

```
project.godot            Godot project (mobile renderer, portrait, 1080x2160 canvas)
scenes/main.tscn         Root scene (everything else is built in code)
scripts/
  main.gd                Modes, camera, touch input, drag & drop, room switching
  library.gd             Data model + JSON persistence (autoload "Library")
  styles.gd              Style catalogue + room geometry constants (autoload "Styles")
  settings.gd            User preferences (autoload "Settings")
  book_api.gd            Google Books / Open Library search, cover download & cache (autoload "BookAPI")
  goodreads_import.gd    CSV parser for Goodreads exports
  room3d.gd              Builds the room shell, lights, furniture and shelves
  furniture.gd           Catalogue of placeable pieces: what exists, how to build one, how much floor it takes
  edit_overlay.gd        The green/red floor map shown while a room is being furnished
  shelf3d.gd             Bookcase geometry, book layout, hit-testing
  book3d.gd / book_mesh.gd  A single book: two-surface mesh, spine label, cover quad
  decor.gd               Procedural props (plants, rug, fireplace, cat, window, lamps, armchair, reading table, archive box…)
  breather.gd / flicker.gd  Tiny animation helpers (cat breathing, fire flicker)
  materials.gd           Cached material factory
  camera_rig.gd          Tweened camera moves
  demo_data.gd           Sample library for --demo runs
  ui/hud.gd              Theme, top/bottom bars, tray, toasts, bottom sheets
  ui/dialogs.gd          Add / import / style / room / shelf / detail / move / settings dialogs
  ui/card_row.gd         Tappable card row that sizes to its content
translations/ui.csv      English + German UI strings (keys = English)
icons/                   SVG icons for the side buttons
shaders/                 Procedural surfaces: planks, logs, wood, brick, plaster, wallpaper, rug, fire, sky glass
textures/lodge/, textures/keep/   Poly Haven texture sets (diffuse / normal / roughness)
models/keep/             Poly Haven glTF models (1k) placed by the Medieval Keep style
tools/make_icons.gd      Renders launcher icons from icon.svg
export_presets.cfg       Android preset (arm64, internet permission, immersive)
```

## Running on desktop

```bash
godot --path . -- --demo            # sample library, nothing is saved
godot --path .                      # your real library (user:// data dir)
```

Mouse drag looks around, click a shelf to zoom, drag books, scroll wheel zooms in the shelf view.

Screenshot harness (used during development):

```bash
godot --path . --resolution 540x1080 -- --demo --mode=shelf --shot=/tmp/shelf.png
# modes: look, look2, study, edit, edit_room, furnish_ok, furnish_bad, furnish_wall, furnish_lift, shelf, shelf2, closeup, fire, cat, table, chair, window, door, door_go, attic, attic_n, keep_fire, keep_corner, box, focus_table, focus_box, ghost, office, office2, bedroom, fantasy, fantasy2, drag, dragtray, zoomtap, detail, place, place_win, place_fire, place_go, place_cancel, trayfly, trayfly_out, tag, tag2, sorted, add, import, style, room, move, settings, books, reading, archive
# add --style=timber_lodge (or any style id) to render a different style
# add --night to render with night mode on, --lang=de for German
godot --headless --path . -- --demo --apitest
godot --headless --path . -- --demo --csvtest=/path/to/goodreads_library_export.csv
```

## Building the APK

Requirements: Godot 4.7.2, matching Android export templates, Android SDK (build-tools + platforms), JDK 17, a debug keystore. The editor settings must point at the SDK, the JDK and the keystore (`export/android/*` in `~/.config/godot/editor_settings-4.7.tres`).

```bash
godot --headless --path . --import
godot --headless --path . --script tools/make_icons.gd
JAVA_HOME=/usr/lib/jvm/java-17-openjdk godot --headless --path . --export-debug Android build/shelfcontrol.apk
adb install -r build/shelfcontrol.apk
```

For a release build, add a release keystore to the preset and use `--export-release`.

## Credits

Timber Lodge uses CC0 textures from [Poly Haven](https://polyhaven.com): *Wood Trunk Wall* (Amal Kumar), *Wood Floor Worn* (Dimitrios Savva), *Brown Planks 09* (Rob Tuytel), *Dark Wood* (Dario Barresi, Dimitrios Savva, Rico Cilliers) and *Brown Leather* (Rob Tuytel) for the armchair. The reading table is built from the style's shelf wood in every style. The trunk wall maps are rotated 90° so the timbers lie horizontally.

Medieval Keep uses CC0 textures *Castle Wall Slates* (Rob Tuytel), *Slate Floor 02* (Dimitrios Savva), *Medieval Wood* (Rob Tuytel), *Dark Wooden Planks* (Amal Kumar) and CC0 models *Green Chair 01* and *Lantern Chandelier 01* (Kirill Sannikov), *Gothic Coffee Table* and *Kite Shield* (Ulan Cabanilla), *Potted Plant 01* and *Treasure Chest* (Rico Cilliers), *Fern 02* (Rob Tuytel, Rico Cilliers), *Wooden Crate 01* (James Ray Cock) and *Gothic Statue* (Benny Weimer), all from [Poly Haven](https://polyhaven.com). Models are the 1k glTF exports under `models/keep/`; a style's decor list can place any of them with `{"model": …, "pos": …}` entries.

## Notes

- Google Books' anonymous quota is shared per network and is frequently exhausted (HTTP 429). The app transparently falls back to Open Library for search, ISBN lookup and covers.
- Rows are stored bottom-up internally but numbered top-down in the UI.
- Shelf capacity is real: a row only accepts a book if its thickness (or cover width, when face-out) fits.
