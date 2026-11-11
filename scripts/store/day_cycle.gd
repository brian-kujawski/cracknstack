class_name DayCycle
extends Node
## The time of day. Daylight comes in through the curtained windows by the
## door: it tints and brightens the curtains and the strip of sky between
## them, drives a soft light from each window and sets the room's ambient
## light. At night only the store's own fixtures are lit, so the room is
## dimmer and the floor a little harder to read, but never dark.
##
## How long a full day takes is a setting (Day length, 15 minutes by
## default). Stopped holds the clock at the Stopped at hour instead.

const START_HOUR := 10.0
## Daylight around the clock: [hour, colour, strength 0..1]. Strength is how
## much daylight gets in; between keys both are blended.
const KEYS := [
	[0.0, Color(0.25, 0.3, 0.5), 0.0],
	[5.0, Color(0.25, 0.3, 0.5), 0.0],
	[6.5, Color(1.0, 0.7, 0.52), 0.4],
	[9.0, Color(1.0, 0.92, 0.82), 0.9],
	[13.0, Color(1.0, 0.98, 0.95), 1.0],
	[17.0, Color(1.0, 0.9, 0.78), 0.85],
	[19.0, Color(1.0, 0.58, 0.36), 0.45],
	[20.5, Color(0.45, 0.4, 0.6), 0.06],
	[21.5, Color(0.25, 0.3, 0.5), 0.0],
	[24.0, Color(0.25, 0.3, 0.5), 0.0],
]
const DAY_AMBIENT := Color(0.9, 0.87, 0.82)
const DAY_AMBIENT_ENERGY := 0.3
## Night stays warm (style bible §4.5: the ambient light is warm and white;
## coloured light comes only from cards and the laptop): lamplight bounce.
const NIGHT_AMBIENT := Color(0.85, 0.7, 0.55)
const NIGHT_AMBIENT_ENERGY := 0.1
## Light from each window at full daylight.
const WINDOW_ENERGY := 0.9
## How brightly the curtains and the sky behind them glow at full daylight.
const CURTAIN_GLOW := 0.45
const SKY_GLOW := 1.4
## Night through the leaded glass: dark, but light enough to show the lead.
const NIGHT_SKY := Color(0.08, 0.1, 0.17)
## The room is closed, so the environment sky is never seen directly: it is
## only what glossy surfaces (the floorboards most) reflect. main.tscn paints
## it in the room's own parchment and walnut so those reflections read as the
## room, not Godot's default blue sky. Its brightness follows the ambient.
const DAY_REFLECTION := 0.35
const NIGHT_REFLECTION := 0.08

## Hours since midnight, 0..24.
var hour := START_HOUR
var running := true

var _environment: Environment
var _window_lights: Array[Light3D] = []
var _curtain: StandardMaterial3D
var _sky: StandardMaterial3D


func setup(environment: Environment, window_lights: Array[Light3D], curtain: StandardMaterial3D, sky: StandardMaterial3D) -> void:
	_environment = environment
	_window_lights = window_lights
	_curtain = curtain
	_sky = sky
	_follow_settings()
	apply()


func _ready() -> void:
	Settings.changed.connect(func(key: String) -> void:
		if key in ["", "day_length", "stopped_at"]:
			_follow_settings())


func _process(delta: float) -> void:
	var length := Settings.day_seconds()
	if running and length > 0.0:
		hour = fmod(hour + delta * 24.0 / length, 24.0)
		apply()


## With the clock stopped, goes to the hour it's stopped at. Changing the
## length keeps the time of day; only the clock's speed changes.
func _follow_settings() -> void:
	if Settings.day_seconds() <= 0.0:
		set_hour(Settings.stopped_hour())


## Jumps to an hour and relights at once (works while paused).
func set_hour(new_hour: float) -> void:
	hour = fposmod(new_hour, 24.0)
	apply()


## Sets every light and material for the current hour.
func apply() -> void:
	var daylight := daylight_at(hour)
	var strength := daylight.a
	var colour := Color(daylight.r, daylight.g, daylight.b)
	for light in _window_lights:
		light.light_color = colour
		light.light_energy = WINDOW_ENERGY * strength
		light.visible = strength > 0.001
	if _curtain != null:
		_curtain.emission = colour * strength * CURTAIN_GLOW
	if _sky != null:
		_sky.albedo_color = NIGHT_SKY.lerp(colour * SKY_GLOW, strength)
	if _environment != null:
		_environment.ambient_light_color = NIGHT_AMBIENT.lerp(DAY_AMBIENT, strength)
		_environment.ambient_light_energy = lerpf(NIGHT_AMBIENT_ENERGY, DAY_AMBIENT_ENERGY, strength)
		if _environment.sky != null and _environment.sky.sky_material is ProceduralSkyMaterial:
			(_environment.sky.sky_material as ProceduralSkyMaterial).energy_multiplier = lerpf(NIGHT_REFLECTION, DAY_REFLECTION, strength)


## Daylight at an hour: its colour, with its strength (0..1) in alpha.
static func daylight_at(at_hour: float) -> Color:
	var h := fposmod(at_hour, 24.0)
	for i in range(1, KEYS.size()):
		var next: Array = KEYS[i]
		if h <= next[0]:
			var previous: Array = KEYS[i - 1]
			var t := inverse_lerp(previous[0], next[0], h)
			var colour: Color = (previous[1] as Color).lerp(next[1], t)
			colour.a = lerpf(previous[2], next[2], t)
			return colour
	return Color(KEYS[0][1], KEYS[0][2])
