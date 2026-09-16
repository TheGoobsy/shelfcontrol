class_name CardRow
extends PanelContainer
## A tappable card that sizes itself to its content. (A plain Button ignores its children's size,
## which left rows clipped and without bottom padding.) The content sits inside the Card margins;
## a transparent Button on top provides the press feedback and the `pressed` signal.

signal pressed

var button: Button

func _init(content: Control, min_h := 0.0) -> void:
	theme_type_variation = "Card"
	custom_minimum_size = Vector2(0, min_h)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ignore_mouse(content)
	add_child(content)
	button = Button.new()
	button.theme_type_variation = "CardButton"
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(func(): pressed.emit())
	add_child(button)

static func _ignore_mouse(c: Node) -> void:
	for ch in c.get_children():
		if ch is Control:
			ch.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_ignore_mouse(ch)
