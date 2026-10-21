extends CanvasLayer
## Moving between the title screen and the shop (autoload: SceneFlow). Owns a
## black screen above everything else that survives scene changes, and does
## the fades: New Game fades to black, loads the shop behind it and fades in.
## While a fade runs, input is swallowed so nothing is clicked or pressed
## half-way through.

const TITLE_SCENE := "res://scenes/title.tscn"
const SHOP_SCENE := "res://scenes/main.tscn"
const FADE_OUT := 0.4
const FADE_IN := 1.5
## How far into the fade-in the player can look and move.
const CONTROL_AT := 0.5
## Frames to wait after the shop loads before fading in, so its first frame
## has drawn and the fade doesn't show a hitch.
const SETTLE_FRAMES := 2

var _black: ColorRect
var _busy := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100
	_black = ColorRect.new()
	_black.color = Color.BLACK
	_black.set_anchors_preset(Control.PRESET_FULL_RECT)
	_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_black.modulate.a = 0.0
	add_child(_black)


func _input(_event: InputEvent) -> void:
	if _busy:
		get_viewport().set_input_as_handled()


## True while a fade is running.
func is_busy() -> bool:
	return _busy


## The title screen goes straight to the shop for the frame-rate benchmark,
## and in developer builds when run with `-- --skip-title`.
static func should_skip_title(args := OS.get_cmdline_user_args()) -> bool:
	return "--benchmark" in args or (OS.is_debug_build() and "--skip-title" in args)


## Starts a fresh game: fade to black, reset progress, load the shop, fade in.
func new_game() -> void:
	if _busy:
		return
	_busy = true
	await _fade_to(1.0, FADE_OUT)
	Progression.reset()
	get_tree().paused = false
	get_tree().change_scene_to_file(SHOP_SCENE)
	# The shop builds its store and pile in _ready, so the screen stays black
	# for that. Hold the game still until the fade-in is part way through.
	await get_tree().scene_changed
	get_tree().paused = true
	for i in SETTLE_FRAMES:
		await get_tree().process_frame
	_fade_to(0.0, FADE_IN)
	await get_tree().create_timer(FADE_IN * CONTROL_AT, true, false, true).timeout
	get_tree().paused = false
	_busy = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## Fades out and closes the game.
func quit() -> void:
	if _busy:
		return
	_busy = true
	await _fade_to(1.0, FADE_OUT)
	get_tree().quit()


func _fade_to(alpha: float, seconds: float) -> Signal:
	_black.mouse_filter = Control.MOUSE_FILTER_STOP if alpha > 0.0 else Control.MOUSE_FILTER_IGNORE
	var tween := create_tween()
	tween.tween_property(_black, "modulate:a", alpha, seconds)
	return tween.finished
