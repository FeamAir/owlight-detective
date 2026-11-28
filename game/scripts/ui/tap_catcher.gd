class_name TapCatcher
extends Control
## Full-screen "tap anywhere to continue" layer (prologue frames, full-screen shows; owner 28.11).
## Any touch anywhere on it continues, except explicit buttons placed above it.
## Every input event is examined (on Android a touch arrives as an emulated mouse event first and the
## InputEventScreenTouch right after it — both in the same frame), only ScreenTouch presses count, so one tap
## continues exactly once on the phone and on the desktop (mouse → emulated touch).
## A tap during the short guard (≤ 0.3 s) is not lost: it continues right after the guard.

signal tapped

const GUARD := 0.3

var show_hint := true
var guard := GUARD
var hint: ContinueHint

var _age := 0.0
var _pending := false
var _fired := false


func _init() -> void:
	UiKit.full_rect(self)
	mouse_filter = Control.MOUSE_FILTER_STOP


func _ready() -> void:
	if show_hint:
		hint = ContinueHint.new()
		hint.anchor_left = 0.5; hint.anchor_right = 0.5; hint.anchor_top = 1.0; hint.anchor_bottom = 1.0
		hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
		hint.grow_vertical = Control.GROW_DIRECTION_BEGIN
		hint.offset_top = -24; hint.offset_bottom = -24
		add_child(hint)


static func is_tap(ev: InputEvent) -> bool:
	return ev is InputEventScreenTouch and ev.pressed


func _gui_input(ev: InputEvent) -> void:
	if not is_tap(ev):
		return
	accept_event()
	if _age < guard:
		_pending = true
	else:
		_fire()


func _process(delta: float) -> void:
	_age += delta
	if _pending and _age >= guard:
		_fire()


func _fire() -> void:
	if _fired:
		return
	_fired = true
	_pending = false
	tapped.emit()


func is_done() -> bool:
	return _fired
