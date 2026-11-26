class_name StubPuzzleScreen
extends Overlay
## Placeholder for puzzles whose screens are not built yet (PIER-01, ALLEY-01, GATE-02, GATE-03).
## Shows what the puzzle is and, in the owner (debug) build, a "Solve" button so the whole slice
## flow (unlocks, goals, hints, slice end) can be checked now.

signal solved(pz: String)

var pz := ""


func setup(puzzle_id: String) -> StubPuzzleScreen:
	pz = puzzle_id
	return self


func _ready() -> void:
	Game.current_puzzle = pz
	add_child(UiKit.dim_layer(0.88))
	var box := VBoxContainer.new()
	box.anchor_left = 0.15; box.anchor_right = 0.85; box.anchor_top = 0.12; box.anchor_bottom = 0.8
	add_child(box)
	box.add_child(UiKit.label(Game.t("pz.stub.title", {"id": pz}), UiKit.FONT_UI + 8, UiKit.LAMP))
	box.add_child(UiKit.label(Game.t("pz.stub.body")))
	var node := Game.data.node(pz)
	if not Game.state.requirements_met(node):
		box.add_child(UiKit.label(Game.t("pz.stub.not_ready", {"req": JSON.stringify(node.get("requires", {}))}), UiKit.FONT_UI, UiKit.MAPLE))
	elif Game.debug_build:
		var b := UiKit.button(Game.t("debug.solve"), 420, true)
		b.pressed.connect(_solve)
		box.add_child(b)
	add_back_button()


func _exit_tree() -> void:
	if Game.current_puzzle == pz:
		Game.current_puzzle = ""


func _solve() -> void:
	Game.state.record_attempt(pz, true)
	solved.emit(pz)
	close()
