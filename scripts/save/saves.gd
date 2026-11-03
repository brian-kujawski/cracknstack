extends Node
## The game's saves (autoload: Saves): the autosave and three slots, which
## of them can be loaded, the timed autosave, and play time (plan:
## save-system-plan.md). SaveGame does the files; the shop (Main) says what
## goes in them through capture_save().
##
## The autosave is written when a New Game's intro ends, every few minutes
## of play (the Autosave every setting), when the ending starts and by Save
## And Quit. Slots are written only from the Save/Load page. A save's state
## is copied on the main thread (ShopSave.snapshot), then put in save order,
## compressed and written on a worker thread, so the game doesn't hitch;
## saving on the way out waits for it.

## A save started being written, and finished.
signal saving_started
signal saving_finished

const AUTOSAVE := "autosave"
const SLOTS := ["autosave", "slot1", "slot2", "slot3"]
const SLOT_NAMES := {"autosave": "Autosave", "slot1": "Slot 1", "slot2": "Slot 2", "slot3": "Slot 3"}
const SAVE_DIR := "user://saves"

## Where saves go; the tests point it somewhere else so they never touch yours.
var save_dir := SAVE_DIR
## The shop being played (Main registers itself), or null on the menus.
var shop: Node
## Seconds played in this game, unpaused.
var play_time := 0.0
## This game has been finished (every binder complete and shelved).
var finished := false

## A save read by load_slot(), waiting for the shop to load and take it.
var _pending := {}
var _since_autosave := 0.0
var _task := -1


func _ready() -> void:
	# Saves from the pause menu while the game is stopped still finish.
	process_mode = Node.PROCESS_MODE_ALWAYS
	var args := OS.get_cmdline_user_args()
	var at := args.find("--dump-save")
	if OS.is_debug_build() and at >= 0 and at + 1 < args.size():
		print(SaveGame.dump(args[at + 1]))
		get_tree().quit()


func _process(delta: float) -> void:
	if _task >= 0 and WorkerThreadPool.is_task_completed(_task):
		_finish_task()
	if shop == null or get_tree().paused:
		return
	play_time += delta
	_since_autosave += delta
	var every := Settings.autosave_seconds()
	if every > 0.0 and _since_autosave >= every:
		save(AUTOSAVE)


func path(slot: String) -> String:
	return save_dir.path_join(slot + SaveGame.EXTENSION)


func status(slot: String) -> SaveGame.Status:
	return SaveGame.status(path(slot))


## A slot's header and summary ({} for an empty or unreadable one).
func summary(slot: String) -> Dictionary:
	var found := SaveGame.read_summary(path(slot))
	return found if not found.is_empty() else SaveGame.read_summary(path(slot) + ".bak")


## True if there's a save of any kind, even one too old to load: a game has
## been started, which unlocks Credits.
func any_save() -> bool:
	for slot in SLOTS:
		if status(slot) != SaveGame.Status.EMPTY:
			return true
	return false


## The slot Continue loads: the newest save this build can load, or "".
func newest_loadable() -> String:
	var newest := ""
	var newest_at := -1.0
	for slot in SLOTS:
		if status(slot) == SaveGame.Status.OK:
			var at: float = summary(slot).get("saved_at", 0.0)
			if at > newest_at:
				newest = slot
				newest_at = at
	return newest


## A fresh game: nothing to load, no play time.
func begin_new_game() -> void:
	_pending = {}
	play_time = 0.0
	finished = false
	_since_autosave = 0.0


## Reads a save, ready for the shop to load (take_pending). Returns false if
## it can't be loaded.
func load_slot(slot: String) -> bool:
	var loaded := SaveGame.read(path(slot))
	if loaded.is_empty():
		return false
	_pending = loaded.shop
	play_time = loaded.summary.get("play_time", 0.0)
	finished = loaded.summary.get("finished", false)
	_since_autosave = 0.0
	return true


## The save the shop should load, once ({} for a new game).
func take_pending() -> Dictionary:
	var pending := _pending
	_pending = {}
	return pending


## Saves the shop to a slot. The state is gathered now; the file is written
## on a worker thread, or before returning with `wait` (on the way out, and
## from the Save/Load page). Returns false if there's no shop to save.
func save(slot: String, wait := false) -> bool:
	if shop == null:
		return false
	if _task >= 0:
		_finish_task()
	var taken: Dictionary = shop.snapshot_save()
	var times := {"saved_at": Time.get_unix_time_from_system(), "play_time": play_time, "finished": finished}
	_since_autosave = 0.0
	saving_started.emit()
	if wait:
		_write(path(slot), taken, times)
		saving_finished.emit()
	else:
		_task = WorkerThreadPool.add_task(_write.bind(path(slot), taken, times), false, "Saving")
	return true


## What the Load list shows of a save: when, how long played, how far
## along. `times` has saved_at, play_time and finished.
static func make_summary(state: Dictionary, times: Dictionary) -> Dictionary:
	var organized := 0
	var pockets := 0
	for entry in state.get("binders", {}).values():
		pockets += entry.pockets.size()
		organized += entry.pockets.size() - Array(entry.pockets).count(-1)
	var made := times.duplicate()
	made.merge({"organized": organized, "total": pockets, "mana": state.get("progression", {}).get("mana", 0)})
	return made


## Waits for a save still being written (the game is closing).
func wait_for_save() -> void:
	if _task >= 0:
		_finish_task()


## Puts a snapshot in save order and writes it (on a worker thread, unless
## waited for).
static func _write(to: String, taken: Dictionary, times: Dictionary) -> void:
	var state := ShopSave.finish(taken)
	var error := SaveGame.write(to, make_summary(state, times), state)
	if error != OK:
		push_error("Saves: could not write %s (%s)" % [to, error_string(error)])


func _finish_task() -> void:
	WorkerThreadPool.wait_for_task_completion(_task)
	_task = -1
	saving_finished.emit()


## "22 Oct 2026, 20:41 · 3 h 12 min · 41%", or what's wrong with the slot.
func describe(slot: String) -> String:
	match status(slot):
		SaveGame.Status.EMPTY:
			return "Empty"
		SaveGame.Status.OLD_VERSION:
			return "From an older version"
		SaveGame.Status.UNREADABLE:
			return "Can't be read"
	var found := summary(slot)
	var total: int = found.get("total", 0)
	var share := floori(100.0 * found.get("organized", 0) / total) if total > 0 else 0
	return "%s · %s · %d%%" % [date_text(found.get("saved_at", 0.0)), play_time_text(found.get("play_time", 0.0)), share]


## A save's time in local time: "22 Oct 2026, 20:41".
static func date_text(unix_time: float) -> String:
	var bias: int = Time.get_time_zone_from_system().get("bias", 0)
	var at := Time.get_datetime_dict_from_unix_time(int(unix_time) + bias * 60)
	var months := ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
	return "%d %s %d, %02d:%02d" % [at.day, months[at.month - 1], at.year, at.hour, at.minute]


## "3 h 12 min", or "12 min" under an hour.
static func play_time_text(seconds: float) -> String:
	var minutes := floori(seconds / 60.0)
	if minutes >= 60:
		return "%d h %d min" % [minutes / 60, minutes % 60]
	return "%d min" % minutes
