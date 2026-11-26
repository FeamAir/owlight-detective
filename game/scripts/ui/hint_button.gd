class_name HintButton
extends Control
## «Мысли» button (дизайн 3.11): top right, 56 dp. Normal level: dotted track, ink ring closing clockwise
## while the thought matures (no numbers on screen), ink drop when ready. Easy: just the button. Hard: hidden.

signal pressed

var _flash := 0.0


func _ready() -> void:
	custom_minimum_size = Vector2(UiKit.BIG_TAP, UiKit.BIG_TAP)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_STOP


func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventScreenTouch and ev.pressed:
		accept_event()
		pressed.emit()


func _process(delta: float) -> void:
	_flash = maxf(0.0, _flash - delta)
	queue_redraw()


func pulse() -> void:
	_flash = 0.4


func _draw() -> void:
	var c := size * 0.5
	var r := size.x * 0.36
	draw_circle(c, r, Color(UiKit.LAKE_DUSK, 0.85))
	draw_arc(c, r, 0, TAU, 40, UiKit.BRASS, 3.0)
	# profile in a beret drawn with one pen line (placeholder glyph)
	var ink := UiKit.IVORY
	draw_arc(c + Vector2(2, 4), r * 0.42, PI * 0.6, PI * 2.2, 16, ink, 3.0)
	draw_line(c + Vector2(-r * 0.45, -r * 0.2), c + Vector2(r * 0.4, -r * 0.42), ink, 4.0)
	for i in 3:
		draw_circle(c + Vector2(-r * 0.25 + i * r * 0.25, -r * 0.7), 3.0, ink)
	if Game.state == null:
		return
	var h: Dictionary = Game.state.hint
	if Hints.mode(Game.state) == "wait":
		var rr := r + 9.0
		for i in 24:                                  # dotted track
			var a := TAU * i / 24.0
			draw_circle(c + Vector2(cos(a), sin(a)) * rr, 1.6, Color(UiKit.IVORY, 0.5))
		if h.get("pending", false):
			var total := Hints.wait_seconds(Game.state, false)
			var done := clampf(1.0 - float(h["remaining"]) / maxf(total, 1.0), 0.0, 1.0)
			draw_arc(c, rr, -PI / 2, -PI / 2 + TAU * done, 48, UiKit.INK.lightened(0.5), 6.0)
			var tip := -PI / 2 + TAU * done
			draw_circle(c + Vector2(cos(tip), sin(tip)) * rr, 5.0, UiKit.LAMP)
		elif h.get("ready", false):
			draw_arc(c, rr, 0, TAU, 48, UiKit.LAMP, 6.0)
			draw_circle(c + Vector2(r * 0.35, -r * 0.05), 7.0 + _flash * 6.0, UiKit.LAMP)   # ink drop at the temple
