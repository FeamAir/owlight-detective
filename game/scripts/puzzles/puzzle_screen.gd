class_name PuzzleScreen
extends Overlay
## Base for puzzle screens: values of the level, "Back", a message card for tutorial prompts, reactions
## and the "solved" logic line, the action button (bottom right) and "Next ›" after solving.
## The card is fitted to its text (font shrinks, card grows up) so the whole logic line is readable
## at 1600×720 and on other aspect ratios; it re-fits when the window size changes.

signal solved(pz: String)

const CARD_LEFT := 0.165
const CARD_RIGHT := 0.765         # action buttons (≤ 320 wide) start at 1600 − 344 = 0.785
const CARD_PAD := Vector2(26, 14)

var pz := ""
var _v: Dictionary = {}
var _done := false
var _card: PanelContainer
var _card_title: Label
var _card_body: Label
var _card_bottom := -24.0          # offset of the card's bottom edge from the screen bottom
var _card_max_frac := 0.46         # max card height as a share of the screen height
var _card_at_top := false          # true: the card hangs from the top edge (search scene: keep the floor visible)
var _action: Button
var _back: Button


func setup(puzzle_id: String) -> PuzzleScreen:
	pz = puzzle_id
	return self


func _ready() -> void:
	Game.current_puzzle = pz
	_v = Game.data.values(pz, Game.state.difficulty)
	_build()
	_back = add_back_button()
	_build_card()
	get_viewport().size_changed.connect(_fit_card)


## Subclasses build their puzzle here.
func _build() -> void:
	pass


func _exit_tree() -> void:
	if Game.current_puzzle == pz:
		Game.current_puzzle = ""
	if Game.state and not _done:
		_save_progress()


## Subclasses store unfinished progress in Game.state.puzzle_progress[pz].
func _save_progress() -> void:
	pass


func level() -> String:
	return Game.state.difficulty


func node() -> Dictionary:
	return Game.data.node(pz)


# ------------------------------------------------------------ action button

func add_action_button(text: String, w: float = 320.0) -> Button:
	var b := UiKit.button(text, w, true)
	b.anchor_left = 1.0; b.anchor_right = 1.0; b.anchor_top = 1.0; b.anchor_bottom = 1.0
	b.offset_left = -24 - w; b.offset_right = -24; b.offset_top = -24 - UiKit.BIG_TAP; b.offset_bottom = -24
	b.custom_minimum_size.y = UiKit.BIG_TAP
	add_child(b)
	_action = b
	return b


# ------------------------------------------------------------ message card

func _build_card() -> void:
	_card = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(UiKit.LAKE_DUSK, 0.94)
	sb.border_color = UiKit.BRASS
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(14)
	sb.content_margin_left = CARD_PAD.x; sb.content_margin_right = CARD_PAD.x
	sb.content_margin_top = CARD_PAD.y; sb.content_margin_bottom = CARD_PAD.y
	_card.add_theme_stylebox_override("panel", sb)
	_card.anchor_left = CARD_LEFT; _card.anchor_right = CARD_RIGHT
	if _card_at_top:
		_card.anchor_top = 0.0; _card.anchor_bottom = 0.0
		_card.offset_top = 16; _card.offset_bottom = 16
		_card.grow_vertical = Control.GROW_DIRECTION_END
	else:
		_card.anchor_top = 1.0; _card.anchor_bottom = 1.0
		_card.offset_top = _card_bottom; _card.offset_bottom = _card_bottom
		_card.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.visible = false
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(v)
	_card_title = UiKit.label("", UiKit.FONT_UI + 4, UiKit.LAMP)
	_card_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_card_title)
	_card_body = UiKit.label("", UiKit.FONT_SUB, UiKit.IVORY)
	_card_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_card_body)
	add_child(_card)


## Shows a card: title (may be "") and body text. Empty both → hides the card.
func show_card(title: String, body: String, body_color: Color = UiKit.IVORY) -> void:
	_card_title.text = title
	_card_title.visible = title != ""
	_card_body.text = body
	_card_body.visible = body != ""
	_card_body.add_theme_color_override("font_color", body_color)
	_card.visible = title != "" or body != ""
	_fit_card()


func hide_card() -> void:
	_card.visible = false


func card_visible() -> bool:
	return _card != null and _card.visible


## Fits the body font so the card stays within _card_max_frac of the screen height.
func _fit_card() -> void:
	if _card == null or not _card.visible:
		return
	var vs := get_viewport_rect().size
	var width := vs.x * (CARD_RIGHT - CARD_LEFT) - CARD_PAD.x * 2.0 - 6.0
	var max_h := vs.y * _card_max_frac - CARD_PAD.y * 2.0 - 6.0
	if _card_title.visible:
		max_h -= UiKit.text_height(_card_title.text, width, UiKit.FONT_UI + 4) + 6.0
	var sz := UiKit.fit_font_size(_card_body.text, width, max_h, UiKit.FONT_SUB, 22)
	_card_body.add_theme_font_size_override("font_size", sz)



## Card geometry for checks (tests, screenshots): {rect, fits}.
func card_layout() -> Dictionary:
	var r := _card.get_global_rect()
	var vs := get_viewport_rect().size
	var width := vs.x * (CARD_RIGHT - CARD_LEFT) - CARD_PAD.x * 2.0 - 6.0
	var need := UiKit.text_height(_card_body.text, width, _card_body.get_theme_font_size("font_size"))
	return {"rect": r, "fits": r.position.y >= 0.0 and r.end.y <= vs.y + 0.5 and _card_body.size.y + 1.0 >= need * 0.9}


## Tutorial prompt once per game (UI-TUT-…).
func tutorial_once(key: String) -> void:
	if not Game.state.has("tut." + key):
		Game.state.set_flag("tut." + key)
		show_card("", Game.t(key), UiKit.LAMP)


## Reaction to a wrong answer ({ui, ui_params, line} from PuzzleRules.feedback).
func show_feedback(fb: Dictionary) -> void:
	var title := ""
	if str(fb.get("ui", "")) != "":
		title = Game.t(fb["ui"], fb.get("ui_params", {}))
	var body := ""
	if str(fb.get("line", "")) != "":
		Game.state.note_line(fb["line"])
		body = Game.line(fb["line"])
	if title == "" and body == "":
		return
	show_card(title, body, UiKit.LAMP)


## Wrong answer: stats + reaction.
func wrong(rule: String, n: int = 0, m: int = 0) -> void:
	Game.state.record_attempt(pz, false)
	show_feedback(PuzzleRules.feedback(rule, level(), node(), n, m))


## Solved: stats, logic line in a card, then "Next ›" emits solved.
func finish(title_key: String = "pz.solved_generic") -> void:
	if _done:
		return
	_done = true
	Game.state.record_attempt(pz, true)
	Game.state.puzzle_progress.erase(pz)
	var ln: String = str(node().get("logic_line", ""))
	if ln != "":
		Game.state.note_line(ln)
	show_card(Game.t(title_key), PuzzleRules.logic_text(pz, level(), Game.lang(), Game.data), UiKit.IVORY)
	if _action:
		_action.visible = false
	var cont := add_action_button(Game.t("btn.next"), 280)
	cont.pressed.connect(func() -> void:
		solved.emit(pz)
		close())
