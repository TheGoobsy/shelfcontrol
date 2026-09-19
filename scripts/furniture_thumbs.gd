class_name FurnitureThumbs
extends Node
## Little pictures of the catalogue pieces for the inventory, so it shows the thing rather
## than only its name.
##
## Each one is the real piece, built for the room's current style and photographed once in
## a viewport of its own: a private world, a three-quarter view from slightly above, and an
## orthographic camera framed to whatever the piece turns out to measure. That way a
## bookish fern and a gothic statue both arrive filling the same little square, and a
## Medieval Keep chair looks like a keep chair rather than a cabin one.
##
## They are made on demand, one per frame, for the category the reader has open. Rendering
## the whole catalogue up front would cost a visible stutter for pictures nobody asked for.

signal ready_for(kind: String, tex: Texture2D)

const SIZE := 200
## Three-quarter view from above: enough of the top to recognise a table, enough of the
## front to recognise a chair.
const EYE_DIR := Vector3(0.62, 0.52, 0.86)
## Slack around the piece, so nothing touches the edge of its square.
const FRAME := 1.18

var _vp: SubViewport
var _cam: Camera3D
var _stage: Node3D
var _cache: Dictionary = {}     # "style|kind" -> Texture2D
var _queue: Array = []          # kinds still to photograph
var _style: Dictionary = {}
var _style_id := ""
var _working := false

func _ready() -> void:
	if not _can_render():
		return
	_vp = SubViewport.new()
	_vp.size = Vector2i(SIZE, SIZE)
	_vp.transparent_bg = true
	_vp.own_world_3d = true
	_vp.world_3d = World3D.new()
	_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_vp.msaa_3d = Viewport.MSAA_4X
	add_child(_vp)

	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CANVAS
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(1.0, 0.96, 0.90)
	e.ambient_light_energy = 1.1
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	_vp.add_child(env)

	# a key light over the shoulder and a soft fill, so shapes read without deep shadow
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-38, 38, 0)
	key.light_energy = 1.5
	_vp.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-14, -130, 0)
	fill.light_energy = 0.55
	_vp.add_child(fill)

	_cam = Camera3D.new()
	_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	_cam.near = 0.01
	_cam.far = 40.0
	_cam.current = true
	_vp.add_child(_cam)

	_stage = Node3D.new()
	_vp.add_child(_stage)

## A headless run has nothing to render into, and the screenshot harness never opens the
## inventory, so the whole apparatus stays unbuilt there.
func _can_render() -> bool:
	return DisplayServer.get_name() != "headless"

## The style decides a piece's materials, so the pictures are taken again when it changes.
func set_style(style: Dictionary, style_id: String) -> void:
	if style_id == _style_id:
		_style = style
		return
	_style = style
	_style_id = style_id
	_cache.clear()
	_queue.clear()

func cached(kind: String) -> Texture2D:
	return _cache.get(_style_id + "|" + kind, null)

## Asks for the pictures of a set of pieces. Ones already taken come back at once through
## `ready_for`; the rest are photographed one per frame.
func request(kinds: Array) -> void:
	# before the room has a style there is nothing worth photographing: the pieces would
	# come out in their fallback colours and be thrown away a moment later
	if _vp == null or _style_id == "":
		return
	for kind in kinds:
		var k := str(kind)
		var have := cached(k)
		if have != null:
			ready_for.emit(k, have)
		elif not _queue.has(k):
			_queue.append(k)
	if not _working:
		_work()

func _work() -> void:
	_working = true
	while not _queue.is_empty():
		var kind: String = _queue.pop_front()
		if cached(kind) != null:
			continue
		var tex := await _shoot(kind)
		if tex != null:
			_cache[_style_id + "|" + kind] = tex
			ready_for.emit(kind, tex)
	_working = false

## Builds the piece, frames it and takes one exposure.
func _shoot(kind: String) -> Texture2D:
	var node := Furniture.build({"id": "thumb_" + kind, "kind": kind}, _style)
	if node == null:
		return null
	_stage.add_child(node)
	var box := Decor.model_aabb(node)
	if box.size == Vector3.ZERO:
		box = AABB(Vector3(-0.2, 0, -0.2), Vector3(0.4, 0.4, 0.4))
	var centre := box.position + box.size / 2.0
	# the diagonal, so the piece fits its square whichever way it is turned towards us
	var reach: float = maxf(box.size.length(), 0.25)
	_cam.size = reach * FRAME
	_cam.position = centre + EYE_DIR.normalized() * (reach * 2.0 + 1.0)
	_cam.look_at(centre, Vector3.UP)
	_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw
	var img := _vp.get_texture().get_image()
	_stage.remove_child(node)
	node.queue_free()
	if img == null or img.is_empty():
		return null
	return ImageTexture.create_from_image(img)
