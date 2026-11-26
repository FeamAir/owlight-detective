class_name ItemInspect
extends Overlay
## Examining an item (дизайн 3.7): picture, name, description. The owl's base shows its 4 signs as an
## engine layer from values (IT-OWL.owl_base_signs — LL-1 source); the ticket shows its level text.

var item_id := ""
var _base := false
var _layer: Control


func setup(id: String) -> ItemInspect:
	item_id = id
	return self


func _ready() -> void:
	add_child(UiKit.dim_layer(0.85))
	var it := Game.data.item(item_id)
	var pic := TextureRect.new()
	pic.texture = Game.data.texture("items", it.get("inspect", {}).get("asset", ""))
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.anchor_left = 0.08; pic.anchor_right = 0.42; pic.anchor_top = 0.12; pic.anchor_bottom = 0.8
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(pic)
	_layer = Control.new()
	_layer.anchor_left = 0.08; _layer.anchor_right = 0.42; _layer.anchor_top = 0.12; _layer.anchor_bottom = 0.8
	_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.draw.connect(_draw_base)
	add_child(_layer)
	var v := VBoxContainer.new()
	v.anchor_left = 0.46; v.anchor_right = 0.94; v.anchor_top = 0.12; v.anchor_bottom = 0.85
	add_child(v)
	v.add_child(UiKit.label(Game.t(it.get("name_key", item_id)), UiKit.FONT_UI + 8, UiKit.LAMP))
	v.add_child(UiKit.label(Game.t(it.get("desc_key", ""))))
	if item_id == "IT-TICKET":
		v.add_child(UiKit.label(Game.t("doc.ticket." + Game.state.difficulty)))
		var eff: Dictionary = it.get("on_inspect", {})
		var res := {"lines": [], "given": [], "tutorial": ""}
		Interactions.apply_effects(Game.state, eff, res)
		Game.state_changed.emit()
	if not it.get("details", []).is_empty():
		var b := UiKit.button(Game.t("bag.owl_base"), 360)
		b.pressed.connect(_show_base)
		v.add_child(b)
	add_back_button()


func _show_base() -> void:
	_base = true
	for d in Game.data.item(item_id).get("details", []):
		if d.get("autosnap") != null:
			Game.state.give(d["autosnap"])
		if d.get("question") != null:
			Game.state.give_question(d["question"])
	Game.state_changed.emit()
	_layer.queue_redraw()


func _draw_base() -> void:
	if not _base:
		return
	var signs: Array = Game.data.values(item_id, Game.state.difficulty).get("owl_base_signs", [])
	var c := _layer.size * 0.5
	_layer.draw_circle(c, 230, Color(0.45, 0.33, 0.2))
	_layer.draw_arc(c, 230, 0, TAU, 64, UiKit.INK, 5.0)
	for i in signs.size():
		var a := -PI / 2 + TAU * i / signs.size()
		SignDraw.draw(_layer, signs[i], c + Vector2(cos(a), sin(a)) * 140, 58, UiKit.IVORY, Color(0.25, 0.18, 0.12))
