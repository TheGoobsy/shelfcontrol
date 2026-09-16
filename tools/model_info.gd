extends SceneTree
## Prints the floor-aligned bounding box of every imported model in models/keep.
func _init() -> void:
	var dir := DirAccess.open("res://models/keep")
	for name in dir.get_directories():
		var n := Decor.model("keep", name)
		if n == null:
			print(name, " FAILED")
			continue
		var box: AABB = n.get_meta("aabb")
		print("%-24s size=(%.2f %.2f %.2f) min=(%.2f %.2f %.2f)" % [name, box.size.x, box.size.y, box.size.z, box.position.x, box.position.y, box.position.z])
		n.free()
	quit()
