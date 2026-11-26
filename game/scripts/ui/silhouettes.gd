class_name Silhouettes
extends RefCounted
## Silhouettes of the PIER-01 list (test-set PIER-01, «Список-силуэты»): white outline, filled with ink
## when found. Translation class A — no words. Placeholders for the artist's final icons.


static func draw(ci: CanvasItem, target: String, r: Rect2, col: Color, filled: bool) -> void:
	var c := r.get_center()
	var s := minf(r.size.x, r.size.y)
	var w := 4.0
	match target:
		"coat":
			# long thing folded in two, two sleeves and a belt
			var body := Rect2(c - Vector2(s * 0.42, s * 0.3), Vector2(s * 0.84, s * 0.6))
			if filled:
				ci.draw_rect(body, col)
			ci.draw_rect(body, col, false, w)
			for sx in [-1.0, 1.0]:
				var sl := Rect2(Vector2(c.x + sx * s * 0.42 - (s * 0.16 if sx < 0 else 0.0), c.y - s * 0.3), Vector2(s * 0.16, s * 0.48))
				if filled:
					ci.draw_rect(sl, col)
				ci.draw_rect(sl, col, false, w)
			ci.draw_line(Vector2(body.position.x, c.y + s * 0.02), Vector2(body.end.x, c.y + s * 0.02), col if not filled else UiKit.IVORY, w)
		"hat":
			# circle with a bump in the middle and a band round the bump
			if filled:
				ci.draw_circle(c, s * 0.42, col)
			ci.draw_arc(c, s * 0.42, 0, TAU, 32, col, w)
			ci.draw_arc(c, s * 0.2, 0, TAU, 24, col if not filled else UiKit.IVORY, w)
			ci.draw_arc(c, s * 0.26, 0, TAU, 24, col if not filled else UiKit.IVORY, w * 0.7)
		"coat_damp_hem":
			# edge of folded cloth: nap on top, hatched dark strip with an uneven border below
			var top := c.y - s * 0.25
			var mid := c.y + s * 0.08
			var left := c.x - s * 0.45
			var right := c.x + s * 0.45
			for k in 9:
				var x := left + (right - left) * k / 8.0
				ci.draw_line(Vector2(x, top), Vector2(x + 4, top - 10), col, 3.0)
			ci.draw_line(Vector2(left, top), Vector2(right, top), col, w)
			var edge := PackedVector2Array()
			for k in 11:
				edge.append(Vector2(left + (right - left) * k / 10.0, mid + [0, 6, -4, 8, 0, -6, 5, -2, 7, -3, 0][k]))
			ci.draw_polyline(edge, col, w)
			var bottom := c.y + s * 0.3
			ci.draw_line(Vector2(left, bottom), Vector2(right, bottom), col, w)
			for k in 10:
				var x2 := left + (right - left) * k / 9.0
				ci.draw_line(Vector2(x2, mid + 8), Vector2(x2 + 14, bottom - 2), col, 2.0 if not filled else 5.0)
		"puddle":
			# flat blot with a glint
			var pts := PackedVector2Array()
			for i in 24:
				var a := TAU * i / 24.0
				pts.append(c + Vector2(cos(a) * s * (0.42 + 0.06 * sin(a * 3.0)), sin(a) * s * 0.2))
			if filled:
				ci.draw_colored_polygon(pts, col)
			var ol := pts.duplicate()
			ol.append(pts[0])
			ci.draw_polyline(ol, col, w)
			ci.draw_line(c + Vector2(-s * 0.15, -s * 0.04), c + Vector2(s * 0.08, -s * 0.07), UiKit.IVORY if filled else col, 3.0)
		"wet_leaves":
			leaf(ci, c, s * 0.42, col, filled)
		"full_bucket":
			# bucket, a wavy line right at the rim
			var top2 := c.y - s * 0.3
			var poly := PackedVector2Array([Vector2(c.x - s * 0.32, top2), Vector2(c.x + s * 0.32, top2), Vector2(c.x + s * 0.24, c.y + s * 0.34), Vector2(c.x - s * 0.24, c.y + s * 0.34)])
			if filled:
				ci.draw_colored_polygon(poly, col)
			var ol2 := poly.duplicate()
			ol2.append(poly[0])
			ci.draw_polyline(ol2, col, w)
			var wave := PackedVector2Array()
			for k in 13:
				wave.append(Vector2(c.x - s * 0.3 + s * 0.6 * k / 12.0, top2 + 6 + sin(k * 1.5) * 4.0))
			ci.draw_polyline(wave, UiKit.IVORY if filled else col, 3.0)
			ci.draw_arc(Vector2(c.x, top2), s * 0.32, PI, TAU, 16, col, 3.0)


## Maple leaf: five sharp lobes and a stalk.
static func leaf(ci: CanvasItem, c: Vector2, r: float, col: Color, filled: bool) -> void:
	var pts := PackedVector2Array()
	var lobes := 5
	for i in lobes * 2 + 1:
		var a := -PI / 2 + PI * 0.9 * (float(i) / (lobes * 2) * 2.0 - 1.0)
		var rad := r if i % 2 == 0 else r * 0.45
		pts.append(c + Vector2(cos(a), sin(a)) * rad)
	pts.append(c + Vector2(0, r * 0.15))
	if filled:
		ci.draw_colored_polygon(pts, col)
	var outline := pts.duplicate()
	outline.append(pts[0])
	ci.draw_polyline(outline, col, 3.0)
	ci.draw_line(c, c + Vector2(0, r * 0.8), col, 3.0)
