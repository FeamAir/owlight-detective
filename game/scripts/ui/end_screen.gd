class_name EndScreen
extends Control
## Slice end (spec 2.5): «Продолжение следует», stats, back to the slice / new game / main menu;
## owner build — export of the play protocol.

signal back_to_slice
signal new_game
signal main_menu


func _ready() -> void:
	UiKit.full_rect(self)
	var bg := ColorRect.new()
	bg.color = UiKit.LAKE_DUSK
	UiKit.full_rect(bg)
	add_child(bg)
	var v := VBoxContainer.new()
	v.anchor_left = 0.1; v.anchor_right = 0.9; v.anchor_top = 0.05; v.anchor_bottom = 0.95
	add_child(v)
	v.add_child(UiKit.label(Game.t("UI-END-01"), 72, UiKit.LAMP))
	v.add_child(UiKit.label(Game.t("UI-END-02"), UiKit.FONT_SUB))
	var st := Game.state
	var counted: Array = Game.data.slice().get("end", {}).get("clues_counted", [])
	v.add_child(UiKit.label(Game.t("UI-END-03", {
		"time": Game.format_time(st.play_time), "puzzles": st.solved_count(), "clues": st.clues_found(counted),
		"errors": st.errors, "hints": st.hints_used, "difficulty": Game.t("diff." + st.difficulty)}), UiKit.FONT_UI, UiKit.IVORY))
	var row := HBoxContainer.new()
	var b1 := UiKit.button(Game.t("UI-END-04"), 0, true)
	b1.pressed.connect(func() -> void: back_to_slice.emit())
	row.add_child(b1)
	var b2 := UiKit.button(Game.t("UI-END-05"))
	b2.pressed.connect(func() -> void: new_game.emit())
	row.add_child(b2)
	var b3 := UiKit.button(Game.t("UI-END-06"))
	b3.pressed.connect(func() -> void: main_menu.emit())
	row.add_child(b3)
	if Game.debug_build:
		var b4 := UiKit.button(Game.t("debug.protocol"))
		var out := UiKit.label("", UiKit.FONT_UI - 8, UiKit.FOG)
		b4.pressed.connect(func() -> void: out.text = Game.protocol_text() + "\n→ " + Game.export_protocol())
		row.add_child(b4)
		v.add_child(row)
		v.add_child(out)
	else:
		v.add_child(row)


func on_back() -> void:
	main_menu.emit()
