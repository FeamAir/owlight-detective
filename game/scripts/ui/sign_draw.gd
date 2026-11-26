class_name SignDraw
extends RefCounted
## «Знаки мастерской» drawn by the engine (detail layer over the background art, brief №18):
## exact and identical on RU/EN. Shapes are placeholders for the artist's final vector icons.


static func draw(ci: CanvasItem, sign_id: String, c: Vector2, r: float, ink: Color, bg: Color = Color(0, 0, 0, 0)) -> void:
	if bg.a > 0.0:
		ci.draw_circle(c, r, bg)
	var w := maxf(2.0, r * 0.12)
	match sign_id:
		"moon":
			ci.draw_circle(c, r * 0.62, ink)
			ci.draw_circle(c + Vector2(r * 0.3, -r * 0.12), r * 0.52, bg if bg.a > 0.0 else Color(0.2, 0.2, 0.2))
		"owl":
			ci.draw_circle(c + Vector2(0, r * 0.1), r * 0.62, ink)
			for s in [-1.0, 1.0]:
				ci.draw_circle(c + Vector2(s * r * 0.25, -r * 0.05), r * 0.2, bg if bg.a > 0.0 else Color.WHITE)
				ci.draw_circle(c + Vector2(s * r * 0.25, -r * 0.05), r * 0.08, ink)
				ci.draw_colored_polygon(PackedVector2Array([c + Vector2(s * r * 0.15, -r * 0.4), c + Vector2(s * r * 0.5, -r * 0.75), c + Vector2(s * r * 0.5, -r * 0.3)]), ink)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.08, r * 0.1), c + Vector2(r * 0.08, r * 0.1), c + Vector2(0, r * 0.3)]), bg if bg.a > 0.0 else Color.WHITE)
		"gear":
			var teeth := 8
			var pts := PackedVector2Array()
			for i in teeth * 2:
				var a := TAU * i / (teeth * 2)
				var rr := r * (0.68 if i % 2 == 0 else 0.5)
				pts.append(c + Vector2(cos(a - 0.15), sin(a - 0.15)) * rr)
				pts.append(c + Vector2(cos(a + 0.15), sin(a + 0.15)) * rr)
			ci.draw_colored_polygon(pts, ink)
			ci.draw_circle(c, r * 0.2, bg if bg.a > 0.0 else Color(0.2, 0.2, 0.2))
		"key":
			ci.draw_arc(c + Vector2(-r * 0.35, 0), r * 0.25, 0, TAU, 24, ink, w * 1.4)
			ci.draw_line(c + Vector2(-r * 0.1, 0), c + Vector2(r * 0.65, 0), ink, w * 1.4)
			ci.draw_line(c + Vector2(r * 0.45, 0), c + Vector2(r * 0.45, r * 0.3), ink, w * 1.4)
			ci.draw_line(c + Vector2(r * 0.62, 0), c + Vector2(r * 0.62, r * 0.25), ink, w * 1.4)
		"wave":
			for k in 2:
				var pts := PackedVector2Array()
				for i in 17:
					var x := -0.65 + 1.3 * i / 16.0
					pts.append(c + Vector2(x * r, (sin(x * 9.0) * 0.14 + (k * 0.35 - 0.17)) * r))
				ci.draw_polyline(pts, ink, w * 1.3)
		"feather":
			ci.draw_line(c + Vector2(-r * 0.5, r * 0.5), c + Vector2(r * 0.5, -r * 0.5), ink, w)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(r * 0.5, -r * 0.5), c + Vector2(-r * 0.05, -r * 0.25), c + Vector2(-r * 0.3, r * 0.3), c + Vector2(r * 0.25, r * 0.05)]), ink)
		"pendulum":
			ci.draw_line(c + Vector2(0, -r * 0.6), c + Vector2(0, r * 0.25), ink, w)
			ci.draw_circle(c + Vector2(0, r * 0.4), r * 0.2, ink)
		"star":
			var pts := PackedVector2Array()
			for i in 10:
				var a := -PI / 2 + TAU * i / 10
				pts.append(c + Vector2(cos(a), sin(a)) * (r * (0.65 if i % 2 == 0 else 0.28)))
			ci.draw_colored_polygon(pts, ink)
		"lantern":
			ci.draw_rect(Rect2(c + Vector2(-r * 0.3, -r * 0.4), Vector2(r * 0.6, r * 0.8)), ink, false, w)
			ci.draw_rect(Rect2(c + Vector2(-r * 0.18, -r * 0.25), Vector2(r * 0.36, r * 0.5)), Color("#F2C98A"))
			ci.draw_line(c + Vector2(0, -r * 0.4), c + Vector2(0, -r * 0.62), ink, w)
		_:
			ci.draw_arc(c, r * 0.5, 0, TAU, 24, ink, w)
