extends Control
## Screen router: main menu → difficulty → prologue → game → slice end (дизайн 3.1).
## Android "Back" always goes one level up (дизайн 2.4); in the panorama it opens the pause menu.

var _screen: Control


func _ready() -> void:
	UiKit.full_rect(self)
	theme = UiKit.make_theme()
	if Game.data.raw.is_empty():
		var l := UiKit.label("Content missing: " + Game.data.load_error, UiKit.FONT_UI, UiKit.MAPLE)
		UiKit.full_rect(l)
		add_child(l)
		return
	show_main_menu()


func _set_screen(c: Control) -> void:
	if _screen:
		_screen.queue_free()
	_screen = c
	add_child(c)


func show_main_menu() -> void:
	Game.current_puzzle = ""
	var m := MainMenu.new()
	m.continue_game.connect(_continue)
	m.new_game.connect(_choose_difficulty)
	m.debug_start.connect(func(lvl: String, sp: Dictionary) -> void:
		Game.new_game_at(lvl, sp)
		Game.autosave()
		_explore(true))
	_set_screen(m)


func _choose_difficulty() -> void:
	var d := DifficultyScreen.new()
	d.back.connect(show_main_menu)
	d.start.connect(_start_new)
	_set_screen(d)


func _start_new(level: String) -> void:
	Game.new_game(level)
	var intro := IntroPlayer.new()
	intro.finished.connect(func() -> void:
		Game.finish_intro()
		_explore(true))
	_set_screen(intro)


func _continue() -> void:
	if not Game.load_game():
		show_main_menu()
		return
	if Game.state.slice_ended:
		_show_end()
	else:
		_explore(false)


func _explore(fresh: bool) -> void:
	var e := ExploreScreen.new()
	e.request_main_menu.connect(show_main_menu)
	e.slice_finished.connect(_show_end)
	_set_screen(e)
	e.start(fresh)


func _show_end() -> void:
	var s := EndScreen.new()
	s.back_to_slice.connect(func() -> void:
		Game.state.slice_ended = false
		Game.state.flags.erase("ev.EV-SLICE-END")
		Game.autosave()
		_explore(false))
	s.new_game.connect(_choose_difficulty)
	s.main_menu.connect(show_main_menu)
	_set_screen(s)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and _screen and _screen.has_method("on_back"):
		_screen.on_back()


func _unhandled_input(ev: InputEvent) -> void:
	# Desktop testing: Esc = Android Back
	if ev is InputEventKey and ev.pressed and ev.keycode == KEY_ESCAPE and _screen and _screen.has_method("on_back"):
		_screen.on_back()
