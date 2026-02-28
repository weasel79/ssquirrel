extends Node
# TouchInput — virtual joystick for mobile/touch browsers.
# Uses _process + Input.is_mouse_button_pressed (compatible with Godot's
# default emulate_mouse_from_touch on iOS Safari/Chrome).
# Joystick is fixed at bottom-left of the 640×360 viewport.
# Invisible on desktop — hides when no touchscreen detected.

const STICK_RADIUS := 36.0
const DEAD_ZONE    := 10.0
const BASE_DIAM    := 76.0
const THUMB_DIAM   := 32.0

# Fixed center position in 640×360 viewport space
const JOY_CENTER := Vector2(56.0, 308.0)

var _canvas:      CanvasLayer = null
var _base_panel:  Panel       = null
var _thumb_panel: Panel       = null

var _active := false

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
	_canvas.visible = DisplayServer.is_touchscreen_available()
	add_child(_canvas)

	_base_panel  = _make_circle_panel(BASE_DIAM,  Color(1, 1, 1, 0.14), Color(1, 1, 1, 0.35), 2)
	_thumb_panel = _make_circle_panel(THUMB_DIAM, Color(1, 1, 1, 0.45), Color(0, 0, 0, 0),    0)

	_base_panel.position  = JOY_CENTER - Vector2(BASE_DIAM,  BASE_DIAM)  * 0.5
	_thumb_panel.position = JOY_CENTER - Vector2(THUMB_DIAM, THUMB_DIAM) * 0.5

	_canvas.add_child(_base_panel)
	_canvas.add_child(_thumb_panel)


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


# Safety net: if is_touchscreen_available() missed the device, show on first touch
func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and not _canvas.visible:
		_canvas.visible = true


func _process(_delta: float) -> void:
	if not _canvas.visible:
		return

	var btn_held := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	var mpos     := get_viewport().get_mouse_position()
	var vp_w     := get_viewport().get_visible_rect().size.x

	if btn_held and not _active:
		# Activate only for touches in left 55% of screen
		if mpos.x < vp_w * 0.55:
			_active = true

	if _active:
		if not btn_held:
			_active = false
			_thumb_panel.position = JOY_CENTER - Vector2(THUMB_DIAM, THUMB_DIAM) * 0.5
			_release_all()
		else:
			var offset  := mpos - JOY_CENTER
			var clamped := offset.limit_length(STICK_RADIUS)
			_thumb_panel.position = JOY_CENTER + clamped - Vector2(THUMB_DIAM, THUMB_DIAM) * 0.5
			_update_actions(offset)


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
