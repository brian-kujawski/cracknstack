extends Node
## The shop's radio (autoload: Radio; plan: sound-plan.md §7.2). It plays the
## songs in assets/music/radio/ on the Music bus, in order, with a few
## seconds' quiet between them. The first FREE_SONGS are there from the
## start; the rest unlock one at a time, spread evenly as Cards Organized
## rises (the shop tells it how far along the game is with set_progress), so
## a loaded game has the songs its progress has earned and nothing extra is
## saved. Whether it's playing, its volume and repeat are the player's, kept
## in user://radio.cfg.
##
## Songs are NN_title.ogg (or .mp3, .wav): the number sets the order and the
## rest of the name is the title, "07_rainy_tuesday.ogg" -> "Rainy Tuesday".
## Until there's a song in the folder, a few placeholder tunes made in code
## stand in, so the radio and its unlocks can be tried.
##
## The radio only plays in the shop: Main starts it and stops it. Its menu is
## RadioMenu (Q); a radio in the shop to play it from comes later.

## The current song, whether it's playing, repeat or the unlocked songs
## changed.
signal changed
## A song unlocked while playing (not when a game loads).
signal song_unlocked(index: int)

const FOLDER := "res://assets/music/radio"
const EXTENSIONS := ["ogg", "mp3", "wav"]
const SAVE_PATH := "user://radio.cfg"
## Songs there from the start.
const FREE_SONGS := 3
## Seconds of quiet between songs, and before the first one in the shop.
const GAP := 3.0
## Seconds into a song after which Previous starts it again instead.
const RESTART_AFTER := 3.0
## How long the radio takes to fade out when you leave the shop.
const FADE_OUT := 0.6

## Every song in order: {"title": String, "path": String} (path "" for a
## placeholder, whose stream is made in code).
var songs: Array[Dictionary] = []
## Songs unlocked so far (always the first ones in order).
var unlocked_count := 0
## The song playing or paused, or -1 before the first.
var current := -1
## The player's choices: whether the radio's on, its volume (0..1) and
## whether a song repeats.
var playing := true
var volume := 0.8
var repeat := false

var _player: AudioStreamPlayer
var _gap_left := -1.0
var _in_shop := false
var _fade: Tween
var _path := SAVE_PATH


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_player = AudioStreamPlayer.new()
	_player.bus = Settings.MUSIC_BUS
	_player.finished.connect(_on_song_finished)
	add_child(_player)
	songs = find_songs()
	unlocked_count = mini(FREE_SONGS, songs.size())
	load_from(_path)


func _process(delta: float) -> void:
	if _gap_left < 0.0 or not _in_shop:
		return
	_gap_left -= delta
	if _gap_left <= 0.0:
		_gap_left = -1.0
		play_song(_next_index(1) if current >= 0 else 0)


## Every song in the folder, in order of their numbers, or the placeholders
## if there are none.
func find_songs(folder := FOLDER) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	var names := PackedStringArray()
	for file in DirAccess.get_files_at(folder):
		# Exported games list "song.ogg.import" or "song.ogg.remap" in place of
		# the song itself; load() still finds it by its own name.
		var name := file.trim_suffix(".import").trim_suffix(".remap")
		if name.get_extension().to_lower() in EXTENSIONS and not name in names:
			names.append(name)
	names.sort()
	for name in names:
		found.append({"title": title_from(name), "path": folder.path_join(name)})
	if found.is_empty():
		for i in PLACEHOLDERS.size():
			found.append({"title": PLACEHOLDERS[i][0], "path": ""})
	return found


## "07_rainy_tuesday.ogg" -> "Rainy Tuesday".
static func title_from(file: String) -> String:
	var name := file.get_basename()
	var cut := name.find("_")
	if cut > 0 and name.substr(0, cut).is_valid_int():
		name = name.substr(cut + 1)
	return name.replace("_", " ").strip_edges().capitalize()


## How many of `count` songs are unlocked at `share` of the game done (0..1):
## FREE_SONGS from the start, then the rest one by one at even steps, the
## last at share n / (n + 1) so it's there well before the end.
static func unlocked_at(share: float, count: int) -> int:
	var free := mini(FREE_SONGS, count)
	var rest := count - free
	return free + mini(rest, int(floor(clampf(share, 0.0, 1.0) * (rest + 1) + 0.000001)))


## The shop tells the radio how far along the game is (Cards Organized as a
## share of every card). With `announce`, each newly unlocked song is
## announced while in the shop; a loaded game's songs come in quietly.
func set_progress(share: float, announce := true) -> void:
	var count := unlocked_at(share, songs.size())
	if count == unlocked_count:
		return
	var before := unlocked_count
	unlocked_count = count
	if announce and _in_shop:
		for index in range(before, count):
			song_unlocked.emit(index)
	changed.emit()


func is_unlocked(index: int) -> bool:
	return index >= 0 and index < unlocked_count


## The shop opened: unlocks start from `share`, and if the radio's on, the
## first song starts after a moment's quiet.
func enter_shop(share: float) -> void:
	_in_shop = true
	unlocked_count = mini(FREE_SONGS, songs.size())
	set_progress(share, false)
	current = -1
	_player.stop()
	_set_player_volume()
	_gap_left = GAP if playing else -1.0
	changed.emit()


## The shop closed: the song fades out.
func leave_shop() -> void:
	_in_shop = false
	_gap_left = -1.0
	if _fade != null:
		_fade.kill()
	if _player.playing:
		_fade = create_tween()
		_fade.tween_property(_player, "volume_db", -60.0, FADE_OUT)
		_fade.tween_callback(_player.stop)


func is_in_shop() -> bool:
	return _in_shop


## Plays an unlocked song from the start.
func play_song(index: int) -> void:
	if not is_unlocked(index):
		return
	current = index
	_gap_left = -1.0
	_player.stream = stream(index)
	_set_player_volume()
	_player.stream_paused = false
	_player.play()
	_set_playing(true)


## Play / Pause: pauses the song, or carries on with it (or starts the next
## one if none is going).
func toggle_playing() -> void:
	if playing:
		_player.stream_paused = true
		_gap_left = -1.0
		_set_playing(false)
	elif current >= 0 and _player.stream != null and _player.stream_paused:
		_player.stream_paused = false
		_set_playing(true)
	else:
		play_song(_next_index(1) if current >= 0 else 0)


func next() -> void:
	play_song(_next_index(1) if current >= 0 else 0)


## Previous: back to the start of this song if it's a few seconds in,
## otherwise the song before.
func previous() -> void:
	if current >= 0 and position() > RESTART_AFTER:
		play_song(current)
	else:
		play_song(_next_index(-1) if current >= 0 else 0)


func set_repeat(on: bool) -> void:
	repeat = on
	save()
	changed.emit()


## The radio's own volume, 0..1, on top of the Music slider.
func set_volume(value: float) -> void:
	volume = clampf(value, 0.0, 1.0)
	_set_player_volume()
	save()


## Seconds into the current song, and its length (0 for none).
func position() -> float:
	return _player.get_playback_position() if current >= 0 and (_player.playing or _player.stream_paused) else 0.0


func length() -> float:
	return _player.stream.get_length() if current >= 0 and _player.stream != null else 0.0


## The next unlocked song `step` (1 or -1) along from the current one,
## round the list.
func _next_index(step: int) -> int:
	if unlocked_count == 0:
		return -1
	return posmod(current + step, unlocked_count)


func _on_song_finished() -> void:
	if not _in_shop or not playing:
		return
	if repeat:
		play_song(current)
	else:
		_gap_left = GAP


func _set_playing(on: bool) -> void:
	if playing != on:
		playing = on
		save()
	changed.emit()


func _set_player_volume() -> void:
	if _fade != null:
		_fade.kill()
		_fade = null
	_player.volume_db = linear_to_db(volume * volume) if volume > 0.0 else -80.0


## A song's stream: loaded from its file, or a placeholder made in code.
func stream(index: int) -> AudioStream:
	var song := songs[index]
	if not song.path.is_empty():
		return load(song.path)
	if not song.has("stream"):
		song.stream = _placeholder(index)
	return song.stream


func save(path := _path) -> void:
	var file := ConfigFile.new()
	file.set_value("radio", "playing", playing)
	file.set_value("radio", "volume", volume)
	file.set_value("radio", "repeat", repeat)
	file.save(path)


## Reads the player's radio choices from `path`, which later saves go to.
func load_from(path: String) -> void:
	_path = path
	var file := ConfigFile.new()
	if file.load(path) != OK:
		return
	playing = file.get_value("radio", "playing", playing)
	volume = clampf(file.get_value("radio", "volume", volume), 0.0, 1.0)
	repeat = file.get_value("radio", "repeat", repeat)


## Placeholder tunes until real songs arrive: [title, beats per minute,
## root note (Hz), chord roots in semitones from it, one per bar].
const PLACEHOLDERS := [
	["Placeholder Tune One", 84, 220.0, [0, 5, 7, 5]],
	["Placeholder Tune Two", 96, 196.0, [0, -3, 5, 7]],
	["Placeholder Tune Three", 72, 246.9, [0, 3, 8, 7]],
	["Placeholder Tune Four", 108, 261.6, [0, 7, 9, 5]],
	["Placeholder Tune Five", 66, 174.6, [0, 4, 5, 0]],
]
const PLACEHOLDER_RATE := 22050
## Bars per placeholder tune (each plays its chord roots round and round).
const PLACEHOLDER_BARS := 8


## A gentle arpeggio, a note per beat with a soft bass note per bar: just
## enough to hear the radio working.
static func _placeholder(index: int) -> AudioStreamWAV:
	var tune: Array = PLACEHOLDERS[index % PLACEHOLDERS.size()]
	var beat := 60.0 / float(tune[1])
	var root: float = tune[2]
	var chords: Array = tune[3]
	var frames := int(PLACEHOLDER_BARS * 4 * beat * PLACEHOLDER_RATE)
	var samples := PackedFloat32Array()
	samples.resize(frames)
	var arpeggio := [0, 4, 7, 12]
	for bar in PLACEHOLDER_BARS:
		var chord: int = chords[bar % chords.size()]
		_add_note(samples, (bar * 4) * beat, root * pow(2.0, (chord - 12) / 12.0), 0.3, 4 * beat, 0.8)
		for step in 4:
			var note: int = chord + arpeggio[step]
			_add_note(samples, (bar * 4 + step) * beat, root * pow(2.0, note / 12.0), 0.18, beat * 1.5, 0.35)
	var data := PackedByteArray()
	data.resize(frames * 2)
	for i in frames:
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = PLACEHOLDER_RATE
	wav.data = data
	return wav


static func _add_note(samples: PackedFloat32Array, start: float, frequency: float, amplitude: float, length: float, decay: float) -> void:
	var first := int(start * PLACEHOLDER_RATE)
	var last := mini(samples.size(), first + int(length * PLACEHOLDER_RATE))
	for i in range(first, last):
		var t := float(i - first) / PLACEHOLDER_RATE
		var envelope := minf(1.0, t / 0.01) * exp(-t / decay) * minf(1.0, (last - i) / 400.0)
		samples[i] += amplitude * envelope * (sin(TAU * frequency * t) + 0.3 * sin(TAU * 2.0 * frequency * t))
