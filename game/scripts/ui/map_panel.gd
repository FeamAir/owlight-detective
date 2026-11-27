class_name MapPanel
extends Overlay
## «Карта» button on the game screen: the zone map full screen with a short legend.

signal travel(vp_id: String)

var view: MapView


func _ready() -> void:
	add_child(UiKit.dim_layer(0.6))
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UiKit.paper_box())
	card.anchor_left = 0.03; card.anchor_right = 0.97; card.anchor_top = 0.04; card.anchor_bottom = 0.96
	add_child(card)
	var h := HBoxContainer.new()
	card.add_child(h)
	view = MapView.new()
	view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	view.size_flags_stretch_ratio = 2.0
	view.travel.connect(func(vp_id: String) -> void: travel.emit(vp_id))
	h.add_child(view)
	var side := VBoxContainer.new()
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side.custom_minimum_size = Vector2(420, 0)
	h.add_child(side)
	side.add_child(UiKit.label(Game.t("map.title"), UiKit.FONT_SUB + 4, UiKit.WALNUT))
	side.add_child(UiKit.label("● " + Game.t("vp." + Game.state.vp) + " — " + Game.t("map.you_are_here"), UiKit.FONT_UI, UiKit.INK))
	side.add_child(UiKit.label(Game.t("map.hint"), UiKit.FONT_UI - 2, UiKit.INK.lightened(0.15)))
	side.add_child(UiKit.label("?  " + Game.t("map.not_visited"), UiKit.FONT_UI - 2, UiKit.INK.lightened(0.25)))
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side.add_child(spacer)
	var back := UiKit.button(Game.t("btn.back"), 260)
	back.custom_minimum_size.y = UiKit.BIG_TAP
	back.pressed.connect(close)
	side.add_child(back)
