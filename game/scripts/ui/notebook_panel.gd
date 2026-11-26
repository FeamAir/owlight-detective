class_name NotebookPanel
extends Overlay
## Clara's notebook (дизайн 3.8, spec 7.2): tabs on the left, content on the right.
## Not in slice build yet: map page, "my notes", highlighting into Codes on normal/hard, compare mode.

var _tab := "case"
var _content: VBoxContainer
var _tabs: VBoxContainer


func _tab_list() -> Array:
	var t: Array = ["case", "clues", "docs", "snaps", "codes", "questions"]
	if Game.state.difficulty == "easy":
		t.append("signs")
	if Game.state.difficulty != "hard":
		t.append("thoughts")
	t.append_array(["solved", "log"])
	return t


func _ready() -> void:
	add_child(UiKit.dim_layer(0.55))
	var book := PanelContainer.new()
	book.add_theme_stylebox_override("panel", UiKit.paper_box())
	book.anchor_left = 0.03; book.anchor_right = 0.97; book.anchor_top = 0.04; book.anchor_bottom = 0.96
	add_child(book)
	var h := HBoxContainer.new()
	book.add_child(h)
	var tab_scroll := ScrollContainer.new()
	tab_scroll.custom_minimum_size = Vector2(330, 0)
	tab_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	h.add_child(tab_scroll)
	_tabs = VBoxContainer.new()
	_tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab_scroll.add_child(_tabs)
	var close_b := UiKit.button(Game.t("btn.back"))
	close_b.pressed.connect(close)
	_tabs.add_child(close_b)
	for t in _tab_list():
		var b := UiKit.button(Game.t("nb.tab." + t))
		b.pressed.connect(_select.bind(t))
		_tabs.add_child(b)
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	h.add_child(scroll)
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_content)
	Game.state.news["notebook"] = 0
	Game.state.set_flag("seen.notebook")
	_select("case")


func _select(t: String) -> void:
	_tab = t
	for c in _content.get_children():
		c.queue_free()
	_content.add_child(UiKit.label(Game.t("nb.tab." + t), UiKit.FONT_SUB + 6, UiKit.WALNUT))
	match t:
		"case": _case()
		"clues": _list(Game.state.clues.map(func(id: String) -> String: return _clue_text(id)))
		"docs": _docs()
		"snaps": _list(Game.state.snapshots.map(func(id: String) -> String: return Game.t(Game.data.snapshot(id).get("title", id))))
		"codes": _codes()
		"questions": _questions()
		"signs": _signs()
		"thoughts": _list(Game.state.thoughts_log.map(func(e: Dictionary) -> String:
			return "%s — %s" % [Game.line(e["line"]), Game.t("vp." + str(e.get("vp", "")))]))
		"solved": _solved()
		"log": _list(Game.state.line_log.map(func(id: String) -> String: return "%s: %s" % [Game.speaker_name(id), Game.line(id)]))


func _text(s: String, color: Color = UiKit.INK, size: int = UiKit.FONT_UI) -> void:
	var l := UiKit.label(s, size, color)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_child(l)


func _list(rows: Array) -> void:
	if rows.is_empty():
		_text(Game.t("nb.empty"), UiKit.FOG.darkened(0.3))
	for r in rows:
		_text("• " + str(r))


func _clue_text(id: String) -> String:
	var c := Game.data.clue(id)
	var params: Dictionary = c.get("params", {})
	return Game.t(c.get("text", id), params)


func _case() -> void:
	for k in ["UI-CASE-01", "UI-CASE-02", "UI-CASE-03"]:
		_text(Game.t(k), UiKit.WALNUT)
	var goals := Game.state.active_goals()
	if not goals.is_empty():
		_text(Game.t("nb.goal") + ": " + Game.t(Game.data.goal(goals[0])["text"]), UiKit.INK, UiKit.FONT_SUB)
		for g in goals.slice(1):
			_text("   " + Game.t("nb.side_goals") + ": " + Game.t(Game.data.goal(g)["text"]), UiKit.INK.lightened(0.2), UiKit.FONT_UI - 4)
	_text(Game.t("nb.people"), UiKit.WALNUT, UiKit.FONT_SUB)
	for pid in Game.data.ids("people"):
		var p := Game.data.people_entry(pid)
		var facts: Array = []
		for ln in p.get("facts", []):
			if Game.state.has("line." + ln):
				if Game.data.line(ln).get("style") == "letter":
					facts.append(Game.t("doc.letter.title"))
				else:
					facts.append(Game.line(ln))
		if facts.is_empty():
			continue
		_text("%s:" % Game.t(p["name_key"]), UiKit.INK, UiKit.FONT_UI)
		for f in facts:
			_text("   — " + f.get_slice("\n", 0), UiKit.INK.lightened(0.15), UiKit.FONT_UI - 4)


func _docs() -> void:
	if Game.state.documents.is_empty():
		_text(Game.t("nb.empty"), UiKit.FOG.darkened(0.3))
	for id in Game.state.documents:
		var b := UiKit.button(Game.t(Game.data.document(id).get("title", id)))
		b.pressed.connect(func() -> void: add_child(DocumentView.new().setup(id)))
		_content.add_child(b)


func _codes() -> void:
	var rows: Array = []
	for id in Game.state.codes:
		var c := Game.data.code(id)
		var src: Variant = Game.data.value_path(str(c.get("from", "")).trim_prefix("values."), Game.state.difficulty)
		var txt := ""
		match c.get("kind", ""):
			"signs":
				txt = ", ".join(Array(src).map(func(s: String) -> String: return Game.t("sign." + s)))
			"sign_levels":
				var parts: Array = []
				for s in Dictionary(src):
					parts.append("%s %d" % [Game.t("sign." + s), int(src[s])])
				txt = ", ".join(parts)
			"ticket":
				var v := Game.data.values("PZ-GATE-03", Game.state.difficulty)
				var dur := "%d:%02d" % [int(v.get("duration_min", 0)) / 60, int(v.get("duration_min", 0)) % 60]
				txt = Game.t("code.ticket.fmt", {"departure": v.get("departure", ""), "duration": dur})
		rows.append("%s: %s" % [Game.t(c.get("title", id)), txt])
	_list(rows)


func _questions() -> void:
	var rows: Array = []
	for q in Game.state.open_questions():
		var qd := Game.data.question(q)
		var mark := ""
		if Game.state.difficulty == "easy" and qd.get("easy_mark") == "may_be_useful":
			mark = " " + Game.t("nb.may_be_useful")
		rows.append(Game.t(qd["text"]) + mark)
	_list(rows)


func _signs() -> void:
	for s in Game.data.ids("signs"):
		var d := Game.data.sign_def(s)
		_text("%s — %d" % [Game.t("sign." + s), int(d["number"])])


func _solved() -> void:
	var rows: Array = []
	for pz in Game.state.solved_order:
		var ln: String = Game.data.node(pz).get("logic_line", "")
		var params := {}
		if pz == "PZ-GATE-01":
			params = CodeLockLogic.logic_params(Game.data.values(pz, Game.state.difficulty), Game.lang(), Game.data)
		elif pz == "PZ-GATE-02":
			var words: Dictionary = Game.data.values(pz, Game.state.difficulty).get("rain_end_words", {})
			params = {"rain_end_words": words.get(Game.lang(), "")}
		rows.append("%s: %s" % [pz, Game.line(ln, params)])
	_list(rows)
