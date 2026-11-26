class_name UiKit
extends RefCounted
## Palette, sizes and small widget factories (docs/design/visual-and-ux.md 1.2, 3.0).
## Base viewport 1600×720 ≈ 800×360 dp → 1 dp = 2 units.

const DP := 2.0
const LAKE_DUSK := Color("#1E2A33")
const WALNUT := Color("#3A2A20")
const BRASS := Color("#C08F45")
const LAMP := Color("#F2C98A")
const IVORY := Color("#EEE4CF")
const INK := Color("#24313F")
const MAPLE := Color("#A4472F")
const FOG := Color("#93A6AB")

const FONT_UI := 32          # 16 sp
const FONT_SUB := 36         # 18 sp subtitles / dialogue
const FONT_TITLE := 56
const TAP := 96.0            # 48 dp minimum touch target
const BIG_TAP := 112.0       # 56 dp


static func make_theme() -> Theme:
	var th := Theme.new()
	th.default_font_size = FONT_UI
	var btn := _box(LAKE_DUSK.lerp(INK, 0.3), BRASS, 3, 14)
	var btn_h := _box(LAKE_DUSK.lerp(BRASS, 0.25), LAMP, 3, 14)
	var btn_p := _box(BRASS.darkened(0.3), LAMP, 4, 14)
	var btn_d := _box(LAKE_DUSK, FOG.darkened(0.3), 2, 14)
	for t in ["Button"]:
		th.set_stylebox("normal", t, btn)
		th.set_stylebox("hover", t, btn_h)
		th.set_stylebox("pressed", t, btn_p)
		th.set_stylebox("focus", t, StyleBoxEmpty.new())
		th.set_stylebox("disabled", t, btn_d)
		th.set_color("font_color", t, IVORY)
		th.set_color("font_hover_color", t, LAMP)
		th.set_color("font_pressed_color", t, IVORY)
		th.set_color("font_disabled_color", t, FOG.darkened(0.2))
	th.set_color("font_color", "Label", IVORY)
	th.set_color("default_color", "RichTextLabel", IVORY)
	th.set_stylebox("panel", "PanelContainer", _box(Color(LAKE_DUSK, 0.92), BRASS, 2, 18))
	th.set_stylebox("panel", "Panel", _box(Color(LAKE_DUSK, 0.92), BRASS, 2, 18))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(BRASS, 0.6)
	sb.set_corner_radius_all(6)
	th.set_stylebox("grabber_area", "VScrollBar", sb)
	th.set_constant("separation", "VBoxContainer", 12)
	th.set_constant("separation", "HBoxContainer", 12)
	return th


static func _box(bg: Color, border: Color, bw: int, pad: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(14)
	s.content_margin_left = pad + 6
	s.content_margin_right = pad + 6
	s.content_margin_top = pad
	s.content_margin_bottom = pad
	return s


static func paper_box() -> StyleBoxFlat:
	var s := _box(IVORY, BRASS.darkened(0.2), 3, 24)
	return s


static func button(text: String, min_w: float = 0.0, primary: bool = false) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(min_w, TAP)
	b.focus_mode = Control.FOCUS_NONE
	if primary:
		b.add_theme_stylebox_override("normal", _box(BRASS.darkened(0.15), LAMP, 4, 14))
		b.add_theme_color_override("font_color", INK)
	return b


static func label(text: String, size: int = FONT_UI, color: Color = IVORY) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


static func rich(size: int = FONT_UI, color: Color = IVORY) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.add_theme_font_size_override("normal_font_size", size)
	r.add_theme_font_size_override("italics_font_size", size)
	r.add_theme_font_size_override("bold_font_size", size)
	r.add_theme_color_override("default_color", color)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


static func full_rect(c: Control) -> Control:
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.offset_left = 0
	c.offset_top = 0
	c.offset_right = 0
	c.offset_bottom = 0
	return c


static func dim_layer(alpha: float = 0.6) -> ColorRect:
	var r := ColorRect.new()
	r.color = Color(0, 0, 0, alpha)
	full_rect(r)
	return r


static func escape_bb(text: String) -> String:
	return text.replace("[", "[lb]")
