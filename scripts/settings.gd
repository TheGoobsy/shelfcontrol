extends Node
## User preferences (autoload "Settings"), stored separately from the library.

signal changed(key: String)

const PATH := "user://settings.json"
const DEFAULTS := {
	"invert_look_x": false,     # room view: drag right looks left
	"invert_look_y": false,     # room view: drag down looks up
	"invert_pan": false,        # shelf view: drag moves the camera instead of the shelf
	"look_sensitivity": 1.0,    # 0.5 .. 2.0
	"spine_top_down": true,     # spine titles read top→bottom (false = bottom→top)
	"google_api_key": "",
	"night_mode": "off",        # off | on | auto (19:00–07:00)
	"language": "system",       # system | en | de
}

var data: Dictionary = {}

func _ready() -> void:
	data = DEFAULTS.duplicate()
	if FileAccess.file_exists(PATH):
		var f := FileAccess.open(PATH, FileAccess.READ)
		if f:
			var parsed = JSON.parse_string(f.get_as_text())
			if typeof(parsed) == TYPE_DICTIONARY:
				for k in parsed.keys():
					if DEFAULTS.has(k):
						data[k] = parsed[k]
	apply_language()

func get_value(key: String) -> Variant:
	return data.get(key, DEFAULTS.get(key))

func set_value(key: String, value: Variant) -> void:
	if data.get(key) == value:
		return
	data[key] = value
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data, "\t"))
	changed.emit(key)

func reset() -> void:
	for k in DEFAULTS.keys():
		set_value(k, DEFAULTS[k])

func is_night() -> bool:
	var mode := str(get_value("night_mode"))
	if mode == "on":
		return true
	if mode == "auto":
		var h: int = Time.get_time_dict_from_system()["hour"]
		return h >= 19 or h < 7
	return false

## Applies the language setting to the TranslationServer. Call after loading and on change.
func apply_language() -> void:
	var lang := str(get_value("language"))
	if lang == "system":
		lang = OS.get_locale_language()
	TranslationServer.set_locale("de" if lang.begins_with("de") else "en")
