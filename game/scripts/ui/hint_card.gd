class_name HintCard
extends Overlay
## Note-paper card under the «Мысли» button (дизайн 3.11). The game is not paused; tap outside closes.
## kinds: "thought" (text, stays until tap), "waiting" (busy + time left + cancel/OK), "ready" (Think / No need).

signal think

var kind := "thought"
var lines: Array = []


func setup(card_kind: String, line_ids: Array = []) -> HintCard:
	kind = card_kind
	lines = line_ids
	return self


func _ready() -> void:
	var bg := Control.new()
	UiKit.full_rect(bg)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	bg.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventScreenTouch and ev.pressed:
			close())
	add_child(bg)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UiKit.paper_box())
	card.anchor_left = 1.0; card.anchor_right = 1.0
	card.offset_left = -760; card.offset_right = -24; card.offset_top = 140
	add_child(card)
	var v := VBoxContainer.new()
	card.add_child(v)
	match kind:
		"thought":
			for ln in lines:
				var r := UiKit.rich(UiKit.FONT_SUB, UiKit.INK)
				r.text = "[i]%s[/i]" % UiKit.escape_bb(Game.line(ln))
				r.custom_minimum_size.x = 680
				v.add_child(r)
			if lines.is_empty():
				v.add_child(UiKit.label(Game.t("hint.nothing"), UiKit.FONT_SUB, UiKit.INK))
		"waiting":
			var r2 := UiKit.rich(UiKit.FONT_SUB, UiKit.INK)
			r2.text = "[i]%s[/i]" % Game.line("HINT-WAIT-BUSY")
			r2.custom_minimum_size.x = 680
			v.add_child(r2)
			var mins := ceili(float(Game.state.hint.get("remaining", 0.0)) / 60.0)
			var left_text := Game.t("hint.waiting_lt1") if float(Game.state.hint.get("remaining", 0.0)) < 60.0 else Game.t("hint.waiting", {"min": mins})
			v.add_child(UiKit.label(left_text, UiKit.FONT_UI, UiKit.WALNUT))
			var row := HBoxContainer.new()
			var cancel := UiKit.button(Game.t("hint.cancel"))
			cancel.pressed.connect(func() -> void:
				Hints.cancel(Game.state)
				Game.state_changed.emit()
				close())
			row.add_child(cancel)
			var ok := UiKit.button(Game.t("btn.ok"), 160, true)
			ok.pressed.connect(close)
			row.add_child(ok)
			v.add_child(row)
		"ready":
			var r3 := UiKit.rich(UiKit.FONT_SUB, UiKit.INK)
			r3.text = "[i]%s[/i]" % Game.line("HINT-READY-01")
			r3.custom_minimum_size.x = 680
			v.add_child(r3)
			var row2 := HBoxContainer.new()
			var no := UiKit.button(Game.t("hint.cancel"))
			no.pressed.connect(func() -> void:
				Hints.cancel(Game.state)
				Game.state_changed.emit()
				close())
			row2.add_child(no)
			var yes := UiKit.button(Game.t("hint.think"), 220, true)
			yes.pressed.connect(func() -> void:
				think.emit()
				close())
			row2.add_child(yes)
			v.add_child(row2)
