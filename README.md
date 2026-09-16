# Shelf Control

A 3D virtual library for Android, built with Godot 4.7. Walk through styled rooms, tap a bookcase to zoom in, and drag books around to arrange them. Add books from online catalogues or import your Goodreads export.

## Features

- **3D rooms** you look around by dragging. Arrow buttons at the top switch rooms; the current room's name is shown in the middle.
- **Bookcases on the walls.** Tap one to zoom into a close-up. In the close-up, drag a book to reorder it or move it to another row. Pinch to zoom around your fingers, double-tap empty space to zoom into that spot (and again to zoom out), two-finger drag to pan.
- **Move between shelves** by dragging a book down into the tray, then opening another shelf and tapping a spot. Or use *Move to…* in the book detail sheet to pick any room, shelf and row.
- **Add books** via search (Google Books first, Open Library as fallback), by ISBN, or manually. Covers are downloaded and cached; the average cover colour becomes the spine colour. Results already in the library are marked.
- **Metadata** per book: title, authors, series, ISBN-10/13, year, pages, publisher, language, genres, tags, description, average rating, your rating, reading status, date read and Goodreads review. All editable in the detail sheet. *Refresh details* re-fetches the catalogue fields from the APIs (by ISBN, else title + author) without touching your own rating, status, tags or review.
- **Add books** via the accent plus icon in the side column.
- **All Books overview** (list icon, top right): filter by title, author, genre, tag or status; sort by title, author, newest or rating; tap a row for details.
- **Goodreads import** (Settings → Import from Goodreads) from the CSV export (My Books → Import and export → Export Library). Filter by exclusive shelf, skip duplicates, covers are fetched in the background. Books are auto-placed; new shelves and rooms are created when a room fills up.
- **Cover-out display**: any book can stand with its cover facing out.
- **Reading table**: a coffee table on the rug holds the books whose status is *Reading*, stacked cover-up. Each of those books keeps its shelf spot, drawn as a pale ghost so you know where it belongs. Tap the stack for the list; the detail sheet has *Start reading* / *Finished reading* and *Show on shelf*.
- **Archive box**: a cardboard box in the corner holds *Archived* books. Archiving takes a book off its shelf without deleting it; *Restore* puts it back on the first free spot. Tap the box for the list.
- **Five styles**: Cozy Cabin (procedural log walls, fireplace, rug), Timber Lodge (photo textures from Poly Haven: stacked timber walls, worn pine floor, plank ceiling, dark hardwood shelves with the grain following each board), Modern Loft (brick, concrete, oak), Dark Academia (green wallpaper, walnut wainscot, candlelight), Scandi Bright. Each style textures the walls, floor, ceiling and shelves, tints the UI, and places decor (plants, rug, armchair, lamps, window or a fireplace with animated flames, and a sleeping cat on the rug).
- **Room types** (per room, pencil icon → Room type): Living room (the style's own furniture), Office (writing desk with banker's lamp, swivel chair, globe), Bedroom (bed, nightstand lamp, rug) and Fantasy library (candelabras, lectern with an open tome, glowing crystal ball, candle chandelier). The style still decides materials and colours.
- **Room management** (pencil icon, top right): rename rooms and shelves, add shelves to free wall spots, change the room type or the library style, add or delete rooms. In a shelf view the pencil edits that shelf.
- **Night mode** (Settings → Scene): off, on, or automatic from 19:00 to 07:00. Starry sky and moon in the window, faint moonlight, lamps and fire carry the room.
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
  room3d.gd              Builds the room shell, lights, decor and shelves
  shelf3d.gd             Bookcase geometry, book layout, hit-testing
  book3d.gd / book_mesh.gd  A single book: two-surface mesh, spine label, cover quad
  decor.gd               Procedural props (plants, rug, fireplace, cat, window, lamps, armchair, reading table, archive box…)
  breather.gd / flicker.gd  Tiny animation helpers (cat breathing, fire flicker)
  materials.gd           Cached material factory
  camera_rig.gd          Tweened camera moves
  demo_data.gd           Sample library for --demo runs
  ui/hud.gd              Theme, top/bottom bars, tray, toasts, bottom sheets
  ui/dialogs.gd          Add / import / style / room / shelf / detail / move / settings dialogs
icons/                   SVG icons for the side buttons
shaders/                 Procedural surfaces: planks, logs, wood, brick, plaster, wallpaper, rug, fire, sky glass
textures/lodge/          Poly Haven texture sets (diffuse / normal / roughness) for the Timber Lodge style
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
# modes: look, look2, study, shelf, shelf2, closeup, fire, cat, table, chair, window, box, ghost, office, office2, bedroom, fantasy, fantasy2, drag, dragtray, zoomtap, detail, add, import, style, room, move, settings, books, reading, archive
# add --style=timber_lodge (or any style id) to render a different style
# add --night to render with night mode on
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

## Notes

- Google Books' anonymous quota is shared per network and is frequently exhausted (HTTP 429). The app transparently falls back to Open Library for search, ISBN lookup and covers.
- Rows are stored bottom-up internally but numbered top-down in the UI.
- Shelf capacity is real: a row only accepts a book if its thickness (or cover width, when face-out) fits.
