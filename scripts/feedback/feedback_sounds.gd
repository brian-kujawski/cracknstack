class_name FeedbackSounds
extends RefCounted
## Placeholder sounds, synthesised in code so there are no audio assets yet
## (real sounds are M4). Each is a short bell-like chime: sine partials with
## a fast attack and an exponential decay.

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

static var _streams := {}


## Plays a sound at a point in the world from a throwaway player node.
static func play(parent: Node, at: Vector3, kind: Kind) -> void:
	var player := AudioStreamPlayer3D.new()
	player.stream = stream(kind)
	player.unit_size = 4.0
	player.bus = Settings.EFFECTS_BUS
	parent.add_child(player)
	player.global_position = at
	player.finished.connect(player.queue_free)
	player.play()


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
