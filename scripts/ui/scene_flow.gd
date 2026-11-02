extends CanvasLayer
## Moving between the title screen and the shop (autoload: SceneFlow). Owns a
## black screen above everything else that survives scene changes, and does
## the fades: New Game fades to black, shows the Fan Content disclaimer,
## loads the shop behind it and fades in on the laptop screen, whose welcome
## message starts the game (LaptopScreen);
## loading a save (Continue, Load) does the same without the intro.
## Quit to Menu fades back to the title scene, which then opens straight on
## the menu; finishing the game does too, with the credits rolling over it.
## While a fade runs, input is swallowed so nothing is clicked or pressed
## half-way through.

## Emitted by save_game(), before the save itself.
signal saving

const TITLE_SCENE := "res://scenes/title.tscn"
const SHOP_SCENE := "res://scenes/main.tscn"
const FADE_OUT := 0.4
const FADE_IN := 1.5
## Back on the menu from the shop, a quicker fade in.
const MENU_FADE_IN := 0.6
## The game's end: a slow fade out, standing in for the final animation.
const ENDING_FADE := 2.5
## How far into the fade-in the player can look and move.
const CONTROL_AT := 0.5
## The prologue: pages of text shown on the black screen before the
## disclaimer, one after another. Empty: the story now opens on the laptop
## (LaptopText), and this is only kept for a page that must come first.
const PROLOGUE: Array[String] = []
## Each intro page fades in, stays at least INTRO_MIN seconds (then any key
## or click moves on) and at most INTRO_HOLD, and fades out.
const INTRO_FADE := 0.6
const INTRO_MIN := 2.0
const INTRO_HOLD := 6.0
const INTRO_FONT_SIZE := 28
const INTRO_WIDTH := 1100
## Where builds before saves remembered that a game had been started, which
## unlocks Credits. A save now does that (the autosave written when the
## intro ends); this file is still read so playtesters who started a game
## before saves existed keep Credits. It can go before release.
const PROFILE_PATH := "user://profile.cfg"
## Frames to wait after the shop loads before fading in, so its first frame
## has drawn and the fade doesn't show a hitch.
const SETTLE_FRAMES := 2

var _black: ColorRect
var _intro: Label
var _busy := false
## The intro page on screen can be skipped by a key or click.
var _skippable := false
var _skipped := false
var _started := false
## Set on the way back from the shop, so the title opens on its menu.
var _menu_requested := false
## Set after the ending, so the title rolls the credits over its menu.
var _credits_requested := false
## Set by New Game, so the shop opens on the laptop's welcome.
var _opening_requested := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100
	_black = ColorRect.new()
	_black.color = Color.BLACK
	_black.set_anchors_preset(Control.PRESET_FULL_RECT)
	_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_black.modulate.a = 0.0
	add_child(_black)
	_intro = Label.new()
	_intro.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_intro.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_intro.grow_vertical = Control.GROW_DIRECTION_BOTH
	_intro.custom_minimum_size.x = INTRO_WIDTH
	_intro.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_intro.add_theme_font_size_override("font_size", INTRO_FONT_SIZE)
	_intro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_intro.modulate.a = 0.0
	add_child(_intro)
	load_profile(PROFILE_PATH)


func _input(event: InputEvent) -> void:
	if _busy:
		if _skippable and TitleScreen.is_start_press(event):
			_skipped = true
		get_viewport().set_input_as_handled()


## True while a fade is running.
func is_busy() -> bool:
	return _busy


## The title screen goes straight to the shop for the frame-rate benchmark,
## and in developer builds when run with `-- --skip-title`.
static func should_skip_title(args := OS.get_cmdline_user_args()) -> bool:
	return "--benchmark" in args or (OS.is_debug_build() and "--skip-title" in args)


## True once a game has been started: there's a save (of any version), or
## an older build remembered one. Credits on the main menu stays greyed out
## until then.
func has_started() -> bool:
	return _started or Saves.any_save()


## Reads whether an older build remembered a game being started, from
## `path` (tests use their own).
func load_profile(path: String) -> void:
	var file := ConfigFile.new()
	file.load(path)
	_started = file.get_value("game", "started", false)


## The intro's pages in order: the prologue, then the disclaimer.
static func intro_pages() -> Array[String]:
	var pages := PROLOGUE.duplicate()
	pages.append(Credits.DISCLAIMER)
	return pages


## Starts a fresh game: fade to black, play the intro, reset progress, load
## the shop, write the first autosave, fade in.
func new_game() -> void:
	if _busy:
		return
	_busy = true
	await _fade_to(1.0, FADE_OUT)
	for page in intro_pages():
		await _show_page(page)
	Progression.reset()
	Saves.begin_new_game()
	_opening_requested = true
	await _enter_shop(true, true)


## Loads a save (Continue, Load Game, or Load from the pause menu): fade to
## black, build the shop from it, fade in. Does nothing if it can't be read.
func load_game(slot: String) -> void:
	if _busy or not Saves.load_slot(slot):
		return
	_busy = true
	await _fade_to(1.0, FADE_OUT)
	await _enter_shop(false)


## Behind the black screen: loads the shop (which takes a waiting save, if
## there is one), then fades in. A new game writes its first autosave once
## the shop is built. With `opening`, the shop has opened on the laptop
## screen: the game stays stopped, with the mouse free, until it's closed.
func _enter_shop(autosave: bool, opening := false) -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(SHOP_SCENE)
	# The shop builds its store and pile in _ready, so the screen stays black
	# for that. Hold the game still until the fade-in is part way through.
	await get_tree().scene_changed
	get_tree().paused = true
	if autosave:
		Saves.save(Saves.AUTOSAVE)
	for i in SETTLE_FRAMES:
		await get_tree().process_frame
	_fade_to(0.0, FADE_IN)
	await get_tree().create_timer(FADE_IN * CONTROL_AT, true, false, true).timeout
	_busy = false
	if opening:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		return
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## Leaves the shop for the main menu: fade to black, swap scenes, fade in
## on the menu (not the title). Saving first is the pause menu's question.
func to_main_menu() -> void:
	if _busy:
		return
	_busy = true
	await _fade_to(1.0, FADE_OUT)
	_menu_requested = true
	get_tree().paused = false
	get_tree().change_scene_to_file(TITLE_SCENE)
	await get_tree().scene_changed
	_busy = false
	await _fade_to(0.0, MENU_FADE_IN)


## The game is finished: every card filed and every binder shelved. Fades
## out slowly (the final animation goes here later), then rolls the credits
## over the main menu, where they leave you.
func play_ending() -> void:
	if _busy:
		return
	_busy = true
	get_tree().paused = true
	await _fade_to(1.0, ENDING_FADE)
	_credits_requested = true
	get_tree().paused = false
	get_tree().change_scene_to_file(TITLE_SCENE)
	await get_tree().scene_changed
	_busy = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await _fade_to(0.0, MENU_FADE_IN)


## True once after play_ending(): the title rolls the credits.
func take_credits_request() -> bool:
	var requested := _credits_requested
	_credits_requested = false
	return requested


## True once after New Game: the shop opens on the laptop's welcome.
func take_opening_request() -> bool:
	var requested := _opening_requested
	_opening_requested = false
	return requested


## True once after to_main_menu(): the title skips straight to its menu.
func take_menu_request() -> bool:
	var requested := _menu_requested
	_menu_requested = false
	return requested


## Saves the game before quitting (the pause menu's Save And Quit): the
## autosave, written before this returns.
func save_game() -> void:
	saving.emit()
	Saves.save(Saves.AUTOSAVE, true)


## Fades out and closes the game.
func quit() -> void:
	if _busy:
		return
	_busy = true
	await _fade_to(1.0, FADE_OUT)
	Saves.wait_for_save()
	get_tree().quit()


## One page of the intro on the black screen: fades in, holds, fades out.
func _show_page(text: String) -> void:
	_intro.text = text
	var tween := create_tween()
	tween.tween_property(_intro, "modulate:a", 1.0, INTRO_FADE)
	await tween.finished
	_skipped = false
	var held := 0.0
	while held < INTRO_HOLD and not (_skipped and held >= INTRO_MIN):
		held += get_process_delta_time()
		_skippable = held >= INTRO_MIN
		await get_tree().process_frame
	_skippable = false
	tween = create_tween()
	tween.tween_property(_intro, "modulate:a", 0.0, INTRO_FADE)
	await tween.finished


func _fade_to(alpha: float, seconds: float) -> Signal:
	_black.mouse_filter = Control.MOUSE_FILTER_STOP if alpha > 0.0 else Control.MOUSE_FILTER_IGNORE
	var tween := create_tween()
	tween.tween_property(_black, "modulate:a", alpha, seconds)
	return tween.finished
