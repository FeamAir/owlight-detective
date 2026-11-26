class_name DocumentView
extends Overlay
## Document reading mode (дизайн 3.10): paper in the centre, ≥18 sp, scroll. Text is set by the engine
## (handwriting fonts later: Tarn — Caveat, Clara — her own hand), so RU/EN are identical in layout.

var doc_id := ""
var extra_text := ""


func setup(id: String, extra: String = "") -> DocumentView:
	doc_id = id
	extra_text = extra
	return self


static func doc_text(id: String) -> String:
	var d := Game.data.document(id)
	if d.has("line"):
		return Game.line(d["line"])
	if d.has("text_by_level"):
		return Game.t("%s.%s" % [d["text_by_level"], Game.state.difficulty])
	return ""


func _ready() -> void:
	add_child(UiKit.dim_layer(0.75))
	var paper := PanelContainer.new()
	paper.add_theme_stylebox_override("panel", UiKit.paper_box())
	paper.anchor_left = 0.15; paper.anchor_right = 0.85; paper.anchor_top = 0.05; paper.anchor_bottom = 0.95
	add_child(paper)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	paper.add_child(scroll)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(v)
	var title := ""
	if doc_id != "":
		title = Game.t(Game.data.document(doc_id).get("title", doc_id))
	v.add_child(UiKit.label(title, UiKit.FONT_SUB + 4, UiKit.WALNUT))
	var body := UiKit.label(doc_text(doc_id) if doc_id != "" else extra_text, UiKit.FONT_SUB + 2, UiKit.INK)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(body)
	add_back_button()
