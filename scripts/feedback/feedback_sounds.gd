class_name FeedbackSounds
extends RefCounted
## Placeholder sounds, synthesised in code so there are no audio assets yet
## (real sounds are M4). Each is a short bell-like chime: sine partials with
## a fast attack and an exponential decay.
##
## Chimes never stack up on one another. Each waits until at least SPACING
## after the one before it, so a burst of lock-ins (quick filing by hand,
## Teleport sending a whole hand, Brainstorm pulling in nine cards) plays as
## a quick run of notes rather than one loud wall of sound, and only
## MAX_VOICES ring at once. Card chimes in a run climb a scale, a step each,
## and a pause of RUN_RESET starts the next run from the bottom again.

enum Kind {
	CARD_LOCKED, ## A card locks into its pocket.
	PAGE_COMPLETE, ## The last pocket on a page locks in.
	BINDER_COMPLETE, ## The last pocket in the binder locks in.
	BINDER_SHELVED, ## A binder stands in its own shelf space.
	SECTION_COMPLETE, ## A whole shelf is in order and complete.
}

const MIX_RATE := 22050

## Per kind: [[frequency (Hz), start (s), amplitude], ...], decay (s).
const NOTES := {
	Kind.CARD_LOCKED: [[[1318.5, 0.0, 0.5], [1975.5, 0.0, 0.25]], 0.25],
	Kind.PAGE_COMPLETE: [[[1046.5, 0.0, 0.4], [1318.5, 0.08, 0.4], [1568.0, 0.16, 0.45]], 0.45],
	Kind.BINDER_COMPLETE: [[[523.3, 0.0, 0.35], [659.3, 0.1, 0.35], [784.0, 0.2, 0.35], [1046.5, 0.3, 0.45]], 0.9],
	Kind.BINDER_SHELVED: [[[392.0, 0.0, 0.5], [587.3, 0.0, 0.3]], 0.35],
	Kind.SECTION_COMPLETE: [[[392.0, 0.0, 0.3], [493.9, 0.12, 0.3], [587.3, 0.24, 0.3], [784.0, 0.36, 0.4]], 1.0],
}

## The shortest gap between two chimes starting, in seconds.
const SPACING := 0.07
## Card chimes in a run climb this scale, in semitones from the chime's own
## pitch (a pentatonic, so any two in a row sound right), and stay on its
## top step once they get there.
const RUN_SCALE := [-5, -3, 0, 2, 4, 7, 9, 12]
## Seconds without a chime that end a run.
const RUN_RESET := 2.0
## Chimes ringing at once; a new one fades out the oldest.
const MAX_VOICES := 4
## How quickly a chime cut short fades out.
const CUT_FADE := 0.05

static var _streams := {}
## When the latest chime starts (Time ticks, seconds), and how far up the
## scale the run has climbed.
static var _last_start := -INF
static var _run_step := 0
## Chimes playing or waiting to, oldest first.
static var _voices: Array = []


## Plays a sound at a point in the world from a throwaway player node.
## It starts in its turn (see SPACING) and, for a card chime, a step up the
## run's scale.
static func play(parent: Node, at: Vector3, kind: Kind) -> void:
	var slot := schedule(Time.get_ticks_msec() / 1000.0, kind)
	var player := AudioStreamPlayer3D.new()
	player.stream = stream(kind)
	player.unit_size = 4.0
	player.bus = Settings.EFFECTS_BUS
	player.pitch_scale = slot[1]
	parent.add_child(player)
	player.global_position = at
	player.finished.connect(player.queue_free)
	var alive := []
	for voice in _voices:
		if is_instance_valid(voice):
			alive.append(voice)
	_voices = alive
	_voices.append(player)
	if slot[0] <= 0.0:
		_start(player)
	else:
		parent.get_tree().create_timer(slot[0], false).timeout.connect(func() -> void:
			if is_instance_valid(player):
				_start(player))


## Starts a chime, fading out the oldest one still ringing if there are
## already MAX_VOICES.
static func _start(player: AudioStreamPlayer3D) -> void:
	var ringing := []
	for voice in _voices:
		if is_instance_valid(voice) and voice.playing and voice.volume_db > -60.0:
			ringing.append(voice)
	if ringing.size() >= MAX_VOICES:
		var oldest: AudioStreamPlayer3D = ringing[0]
		oldest.create_tween().tween_property(oldest, "volume_db", -80.0, CUT_FADE)
		_voices.erase(oldest)
	player.play()


## When a chime asked for at `now` (seconds) starts, and its pitch: returns
## [seconds to wait, pitch scale]. Card chimes climb the run's scale; the
## bigger chimes keep their own pitch and don't move the run along.
static func schedule(now: float, kind: Kind) -> Array:
	var start := maxf(now, _last_start + SPACING)
	if start - _last_start > RUN_RESET:
		_run_step = 0
	_last_start = start
	var pitch := 1.0
	if kind == Kind.CARD_LOCKED:
		pitch = pow(2.0, RUN_SCALE[mini(_run_step, RUN_SCALE.size() - 1)] / 12.0)
		_run_step += 1
	return [start - now, pitch]


## Forgets the run and the queue (tests, and a fresh scene).
static func reset() -> void:
	_last_start = -INF
	_run_step = 0
	_voices.clear()


static func stream(kind: Kind) -> AudioStreamWAV:
	if not _streams.has(kind):
		_streams[kind] = _synthesise(NOTES[kind][0], NOTES[kind][1])
	return _streams[kind]


static func _synthesise(notes: Array, decay: float) -> AudioStreamWAV:
	var length := 0.0
	for note in notes:
		length = maxf(length, note[1] + decay * 5.0)
	var frames := int(length * MIX_RATE)
	var samples := PackedFloat32Array()
	samples.resize(frames)
	for note in notes:
		var start := int(note[1] * MIX_RATE)
		for i in range(start, frames):
			var t := float(i - start) / MIX_RATE
			var envelope := minf(1.0, t / 0.004) * exp(-t / decay)
			samples[i] += note[2] * envelope * sin(TAU * note[0] * t)
	var data := PackedByteArray()
	data.resize(frames * 2)
	for i in frames:
		data.encode_s16(i * 2, int(clampf(samples[i] * 0.6, -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = false
	wav.data = data
	return wav
