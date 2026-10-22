extends Node
## Every player setting, its default and its saved value (autoload:
## Settings). The Settings page (SettingsScreen) shows them and calls
## change(); the game reads them with value() and redraws on `changed`.
## Settings that belong to the engine as a whole (window, frame rate, render
## scale, shadows, anti-aliasing, volumes, interface size) are applied here;
## the rest (look, crouch, field of view, brightness, day length, autosave)
## are read by the player, the main scene, DayCycle and Saves. Kept in user://settings.cfg,
## which New Game and saves never touch.

## Emitted after a setting changes, with its key.
signal changed(key: String)

const SAVE_PATH := "user://settings.cfg"

## Audio buses, children of Master (default_bus_layout.tres).
const EFFECTS_BUS := &"Effects"
const AMBIENCE_BUS := &"Ambience"
const MUSIC_BUS := &"Music"
const VOLUMES := {
	"master_volume": &"Master",
	"effects_volume": EFFECTS_BUS,
	"ambience_volume": AMBIENCE_BUS,
	"music_volume": MUSIC_BUS,
}

## Dropdown choices, by index: what each one means.
const DAY_LENGTHS := [600.0, 900.0, 1800.0, 3600.0, 0.0] # seconds; 0 = stopped
const STOPPED_HOURS := [9.0, 12.0, 18.0, 0.0] # morning, noon, evening, night
const AUTOSAVE_MINUTES := [0, 2, 5, 10] # 0 = off
const FRAME_LIMITS := [0, 30, 60, 120, 144] # 0 = unlimited
const RENDER_SCALES := [1.0, 0.85, 0.75, 0.5]
## Per shadow level: positional shadow atlas size and soft shadow quality.
## High is the engine's default, which the game used before Settings.
const SHADOW_LEVELS := [
	[1024, RenderingServer.SHADOW_QUALITY_HARD],
	[2048, RenderingServer.SHADOW_QUALITY_SOFT_VERY_LOW],
	[4096, RenderingServer.SHADOW_QUALITY_SOFT_LOW],
]
## Per anti-aliasing choice: [MSAA, screen-space AA].
const ANTI_ALIASING := [
	[Viewport.MSAA_DISABLED, Viewport.SCREEN_SPACE_AA_DISABLED],
	[Viewport.MSAA_DISABLED, Viewport.SCREEN_SPACE_AA_FXAA],
	[Viewport.MSAA_2X, Viewport.SCREEN_SPACE_AA_DISABLED],
	[Viewport.MSAA_4X, Viewport.SCREEN_SPACE_AA_DISABLED],
]
## Quality presets (Low, Medium, High): render scale, shadows and
## anti-aliasing, as indexes into the lists above. A fourth choice, Custom,
## is whatever doesn't match one of these.
const QUALITY_KEYS := ["render_scale", "shadows", "anti_aliasing"]
const QUALITY_PRESETS := [
	{"render_scale": 2, "shadows": 0, "anti_aliasing": 0},
	{"render_scale": 0, "shadows": 1, "anti_aliasing": 1},
	{"render_scale": 0, "shadows": 2, "anti_aliasing": 2},
]
const CUSTOM_QUALITY := 3

## Mouse look at 1.00× sensitivity, in radians per pixel.
const BASE_LOOK_SENSITIVITY := 0.0025

## Every setting and its default. Volumes, sensitivity, brightness and
## interface size are fractions (0.8 = 80%); dropdowns are indexes.
const DEFAULTS := {
	"master_volume": 1.0,
	"effects_volume": 1.0,
	"ambience_volume": 0.6,
	"music_volume": 0.7,
	"mute_in_background": true,
	"mouse_sensitivity": 1.0,
	"invert_y": false,
	"crouch_toggle": false,
	"day_length": 1,
	"stopped_at": 1,
	"autosave_every": 2,
	"interface_size": 1.0,
	"fullscreen": false,
	"vsync": true,
	"frame_limit": 0,
	"field_of_view": 75.0,
	"brightness": 1.0,
	"quality": 2,
	"render_scale": 0,
	"shadows": 2,
	"anti_aliasing": 2,
}

## Which settings each Reset button puts back.
const TABS := {
	"Audio": ["master_volume", "effects_volume", "ambience_volume", "music_volume", "mute_in_background"],
	"Controls": ["mouse_sensitivity", "invert_y", "crouch_toggle"],
	"Gameplay": ["day_length", "stopped_at", "autosave_every", "interface_size"],
	"Graphics": ["fullscreen", "vsync", "frame_limit", "field_of_view", "brightness", "quality", "render_scale", "shadows", "anti_aliasing"],
}

## Where save() and load_settings() go by default; the tests point it
## somewhere else so they never touch your settings.
var save_path := SAVE_PATH

var _values := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_values = DEFAULTS.duplicate()
	load_settings()


func value(key: String) -> Variant:
	return _values[key]


## Sets one setting and applies it at once. Choosing a quality preset sets
## the three quality rows; changing one of those by hand makes it Custom.
func change(key: String, new_value: Variant) -> void:
	assert(DEFAULTS.has(key), "no setting called %s" % key)
	if _values[key] == new_value:
		return
	_values[key] = new_value
	if key == "quality" and new_value < QUALITY_PRESETS.size():
		for quality_key in QUALITY_KEYS:
			_values[quality_key] = QUALITY_PRESETS[new_value][quality_key]
	elif key in QUALITY_KEYS:
		_values["quality"] = matching_quality()
	_apply()
	changed.emit(key)


## The preset the three quality rows match, or CUSTOM_QUALITY.
func matching_quality() -> int:
	for preset in QUALITY_PRESETS.size():
		var matches := true
		for quality_key in QUALITY_KEYS:
			matches = matches and _values[quality_key] == QUALITY_PRESETS[preset][quality_key]
		if matches:
			return preset
	return CUSTOM_QUALITY


## Puts one tab's settings back to their defaults.
func reset_tab(tab: String) -> void:
	for key in TABS[tab]:
		_values[key] = DEFAULTS[key]
	_apply()
	changed.emit("")


func reset_all() -> void:
	_values = DEFAULTS.duplicate()
	_apply()
	changed.emit("")


## Mouse look, in radians per pixel moved.
func look_sensitivity() -> float:
	return BASE_LOOK_SENSITIVITY * value("mouse_sensitivity")


## Seconds in one day and night, or 0 when the clock is stopped.
func day_seconds() -> float:
	return DAY_LENGTHS[value("day_length")]


## The hour the clock stands at when it's stopped.
func stopped_hour() -> float:
	return STOPPED_HOURS[value("stopped_at")]


## Seconds of play between autosaves, or 0 when autosave is off.
func autosave_seconds() -> float:
	return AUTOSAVE_MINUTES[value("autosave_every")] * 60.0


## Writes every setting that differs from its default.
func save(path := "") -> void:
	path = path if path != "" else save_path
	var file := ConfigFile.new()
	for key in DEFAULTS:
		if _values[key] != DEFAULTS[key]:
			file.set_value("settings", key, _values[key])
	file.save(path)


## Reads the saved settings over the defaults; anything missing, or of the
## wrong kind, keeps its default.
func load_settings(path := "") -> void:
	path = path if path != "" else save_path
	_values = DEFAULTS.duplicate()
	var file := ConfigFile.new()
	if file.load(path) == OK:
		for key in DEFAULTS:
			var saved: Variant = file.get_value("settings", key, DEFAULTS[key])
			if typeof(saved) == typeof(DEFAULTS[key]) or (DEFAULTS[key] is float and saved is int):
				_values[key] = type_convert(saved, typeof(DEFAULTS[key]))
	_values["quality"] = matching_quality()
	_apply()
	changed.emit("")


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_FOCUS_OUT:
			if value("mute_in_background"):
				AudioServer.set_bus_mute(0, true)
		NOTIFICATION_APPLICATION_FOCUS_IN:
			AudioServer.set_bus_mute(0, false)
		NOTIFICATION_WM_CLOSE_REQUEST:
			save()


## Applies the engine-wide settings.
func _apply() -> void:
	for key in VOLUMES:
		var bus := AudioServer.get_bus_index(VOLUMES[key])
		if bus >= 0:
			var volume: float = value(key)
			# Squared, so the slider's middle sounds like half as loud.
			AudioServer.set_bus_volume_db(bus, linear_to_db(volume * volume) if volume > 0.0 else -80.0)
			AudioServer.set_bus_mute(bus, volume <= 0.0 and bus != 0)
	var root := get_tree().root
	root.content_scale_factor = value("interface_size")
	root.scaling_3d_scale = RENDER_SCALES[value("render_scale")]
	root.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR if root.scaling_3d_scale < 1.0 else Viewport.SCALING_3D_MODE_BILINEAR
	var shadows: Array = SHADOW_LEVELS[value("shadows")]
	root.positional_shadow_atlas_size = shadows[0]
	RenderingServer.positional_soft_shadow_filter_set_quality(shadows[1])
	var anti_aliasing: Array = ANTI_ALIASING[value("anti_aliasing")]
	root.msaa_3d = anti_aliasing[0]
	root.screen_space_aa = anti_aliasing[1]
	Engine.max_fps = 0 if value("vsync") else FRAME_LIMITS[value("frame_limit")]
	if DisplayServer.get_name() == "headless":
		return
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if value("vsync") else DisplayServer.VSYNC_DISABLED)
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if value("fullscreen") else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != mode and not (mode == DisplayServer.WINDOW_MODE_WINDOWED and DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_MAXIMIZED):
		DisplayServer.window_set_mode(mode)
