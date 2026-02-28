extends Node
# TouchInput — virtual joystick for mobile/touch browsers.
# Injects move_left/right/up/down via Input.action_press/release.
# Joystick appears wherever the left-half of the screen is first touched.
# Invisible on desktop — no touch events = no UI shown.

const STICK_RADIUS  := 38.0   # max thumb travel from base center (viewport px)
const DEAD_ZONE     := 10.0   # minimum offset to register a direction
const BASE_DIAM     := 80.0
const THUMB_DIAM    := 34.0

var _touch_id  : int = -1
var _stick_base: Vector2

var _canvas     : CanvasLayer = null
var _base_panel : Panel       = null
var _thumb_panel: Panel       = null

var _pressed := {
	"move_left":  false,
	"move_right": false,
	"move_up":    false,
	"move_down":  false,
}


func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
	_canvas = CanvasLayer.new()
	_canvas.layer = 50
	add_child(_canvas)

	_base_panel  = _make_circle_panel(BASE_DIAM,  Color(1, 1, 1, 0.14), Color(1, 1, 1, 0.35), 2)
	_thumb_panel = _make_circle_panel(THUMB_DIAM, Color(1, 1, 1, 0.45), Color(0, 0, 0, 0),    0)
	_canvas.add_child(_base_panel)
	_canvas.add_child(_thumb_panel)
	_base_panel.visible  = false
	_thumb_panel.visible = false


func _make_circle_panel(diameter: float, bg: Color, border: Color, bw: int) -> Panel:
	var r  := int(diameter / 2)
	var st := StyleBoxFlat.new()
	st.corner_radius_top_left     = r
	st.corner_radius_top_right    = r
	st.corner_radius_bottom_left  = r
	st.corner_radius_bottom_right = r
	st.bg_color = bg
	if bw > 0:
		st.border_width_left   = bw
		st.border_width_right  = bw
		st.border_width_top    = bw
		st.border_width_bottom = bw
		st.border_color        = border
	var p := Panel.new()
	p.add_theme_stylebox_override("panel", st)
	p.size = Vector2(diameter, diameter)
	return p


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and _touch_id == -1:
			# Only activate for touches in the left 55% of the screen
			if event.position.x < get_viewport().get_visible_rect().size.x * 0.55:
				_touch_id   = event.index
				_stick_base = event.position
				_base_panel.position  = _stick_base - Vector2(BASE_DIAM,  BASE_DIAM)  * 0.5
				_thumb_panel.position = _stick_base - Vector2(THUMB_DIAM, THUMB_DIAM) * 0.5
				_base_panel.visible  = true
				_thumb_panel.visible = true
				get_viewport().set_input_as_handled()
		elif not event.pressed and event.index == _touch_id:
			_touch_id = -1
			_base_panel.visible  = false
			_thumb_panel.visible = false
			_release_all()
			get_viewport().set_input_as_handled()

	elif event is InputEventScreenDrag and event.index == _touch_id:
		var offset  := event.position - _stick_base
		var clamped := offset.limit_length(STICK_RADIUS)
		_thumb_panel.position = _stick_base + clamped - Vector2(THUMB_DIAM, THUMB_DIAM) * 0.5
		_update_actions(offset)
		get_viewport().set_input_as_handled()


func _update_actions(offset: Vector2) -> void:
	_set_action("move_left",  offset.x < -DEAD_ZONE)
	_set_action("move_right", offset.x >  DEAD_ZONE)
	_set_action("move_up",    offset.y < -DEAD_ZONE)
	_set_action("move_down",  offset.y >  DEAD_ZONE)


func _set_action(action: String, active: bool) -> void:
	if active == _pressed[action]:
		return
	_pressed[action] = active
	if active:
		Input.action_press(action)
	else:
		Input.action_release(action)


func _release_all() -> void:
	for action: String in _pressed:
		if _pressed[action]:
			Input.action_release(action)
			_pressed[action] = false
