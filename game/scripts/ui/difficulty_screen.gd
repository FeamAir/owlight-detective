class_name DifficultyScreen
extends Control
## New game: difficulty (дизайн 3.3; brief №4 — fixed for the whole game).

signal start(level: String)
signal back

var _level := ""
var _cards: Dictionary = {}
var _start_btn: Button


func _ready() -> void:
	UiKit.full_rect(self)
	var bg := ColorRect.new()
	bg.color = UiKit.LAKE_DUSK
	UiKit.full_rect(bg)
	add_child(bg)
	var t := UiKit.label(Game.t("diff.title"), UiKit.FONT_TITLE, UiKit.LAMP)
	t.position = Vector2(60, 20)
	t.size = Vector2(1000, 80)
	add_child(t)
	var row := HBoxContainer.new()
	row.position = Vector2(60, 110)
	row.size = Vector2(1480, 400)
	row.add_theme_constant_override("separation", 30)
	add_child(row)
	for lvl in GameData.LEVELS:
		var card := Button.new()
		card.focus_mode = Control.FOCUS_NONE
		card.custom_minimum_size = Vector2(470, 400)
		card.toggle_mode = true
		card.pressed.connect(_pick.bind(lvl))
		var v := VBoxContainer.new()
		UiKit.full_rect(v)
		v.offset_left = 24; v.offset_right = -24; v.offset_top = 20; v.offset_bottom = -20
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var icon: String = {"easy": "☼", "normal": "♨", "hard": "☾"}[lvl]   # lamp / candle / moon — shape, not colour
		var name_l := UiKit.label("%s  %s" % [icon, Game.t("diff." + lvl)], UiKit.FONT_SUB + 8, UiKit.LAMP)
		name_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(name_l)
		var s := UiKit.label(Game.t("diff.%s.sub" % lvl), UiKit.FONT_UI, UiKit.IVORY)
		s.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(s)
		var d := UiKit.label(Game.t("diff.%s.desc" % lvl), UiKit.FONT_UI - 4, UiKit.FOG)
		d.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(d)
		card.add_child(v)
		row.add_child(card)
		_cards[lvl] = card
	var common := UiKit.label(Game.t("diff.common"), UiKit.FONT_UI - 4, UiKit.IVORY)
	common.position = Vector2(60, 525)
	common.size = Vector2(1480, 40)
	add_child(common)
	var note := UiKit.label(Game.t("diff.locked_note"), UiKit.FONT_UI - 4, UiKit.LAMP)
	note.position = Vector2(60, 565)
	note.size = Vector2(1000, 80)
	add_child(note)
	var b := UiKit.button(Game.t("btn.back"), 220)
	b.position = Vector2(60, 720 - 24 - UiKit.BIG_TAP)
	b.size = Vector2(220, UiKit.BIG_TAP)
	b.pressed.connect(func() -> void: back.emit())
	add_child(b)
	_start_btn = UiKit.button(Game.t("diff.start"), 380, true)
	_start_btn.anchor_left = 1.0; _start_btn.anchor_right = 1.0; _start_btn.anchor_top = 1.0; _start_btn.anchor_bottom = 1.0
	_start_btn.offset_left = -440; _start_btn.offset_right = -60; _start_btn.offset_top = -24 - UiKit.BIG_TAP; _start_btn.offset_bottom = -24
	_start_btn.disabled = true
	_start_btn.pressed.connect(_on_start)
	add_child(_start_btn)


func _pick(lvl: String) -> void:
	_level = lvl
	for k in _cards:
		(_cards[k] as Button).button_pressed = k == lvl
		(_cards[k] as Button).modulate = Color(1, 1, 1) if k == lvl else Color(0.7, 0.7, 0.7)
	_start_btn.disabled = false


func _on_start() -> void:
	if not Game.has_save():
		start.emit(_level)
		return
	var ov := Overlay.new()
	ov.add_child(UiKit.dim_layer(0.7))
	var card := PanelContainer.new()
	card.anchor_left = 0.25; card.anchor_right = 0.75; card.anchor_top = 0.3
	ov.add_child(card)
	var v := VBoxContainer.new()
	card.add_child(v)
	v.add_child(UiKit.label(Game.t("diff.overwrite"), UiKit.FONT_SUB))
	var row := HBoxContainer.new()
	var c := UiKit.button(Game.t("btn.cancel"), 260)
	c.pressed.connect(ov.close)
	row.add_child(c)
	var ok := UiKit.button("⚠ " + Game.t("btn.restart"), 340, true)
	ok.pressed.connect(func() -> void:
		Game.delete_save()
		start.emit(_level))
	row.add_child(ok)
	v.add_child(row)
	add_child(ov)


func on_back() -> void:
	for c in get_children():
		if c is Overlay:
			c.on_back()
			return
	back.emit()
