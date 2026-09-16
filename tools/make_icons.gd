extends SceneTree
## Renders launcher icons from icon.svg. Run: godot --headless --path . --script tools/make_icons.gd

func _init() -> void:
	var svg := FileAccess.get_file_as_string("res://icon.svg")
	var out := "res://build_assets"
	DirAccess.make_dir_recursive_absolute(out)
	var main := Image.new()
	main.load_svg_from_string(svg, 192.0 / 128.0)
	main.save_png(out + "/icon_192.png")
	# adaptive foreground: icon centred in a 432 canvas (safe zone is the inner 66%)
	var fg := Image.create(432, 432, false, Image.FORMAT_RGBA8)
	fg.fill(Color(0, 0, 0, 0))
	var inner := Image.new()
	inner.load_svg_from_string(svg, 260.0 / 128.0)
	fg.blit_rect(inner, Rect2i(0, 0, inner.get_width(), inner.get_height()), Vector2i((432 - inner.get_width()) / 2, (432 - inner.get_height()) / 2))
	fg.save_png(out + "/icon_fg_432.png")
	var bg := Image.create(432, 432, false, Image.FORMAT_RGBA8)
	bg.fill(Color(0.23, 0.14, 0.08))
	bg.save_png(out + "/icon_bg_432.png")
	print("icons written")
	quit()
