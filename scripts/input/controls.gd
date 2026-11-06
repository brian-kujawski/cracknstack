extends Node
## Every action the player can bind, its default keys and buttons, and the
## player's own rebinds (autoload: Controls). Game code names actions only
## through the constants below and asks here for how to show a binding
## ("E", "click", "scroll"), so no key is written anywhere else. Rebinds are
## kept in user://controls.cfg. The Settings page lists the bindings for
## reference only (your call: no rebinding in game), so rebind() is there for
## the future and the tests.

## Emitted after any binding changes, so hints can redraw their key names.
signal bindings_changed

const SAVE_PATH := "user://controls.cfg"

const MOVE_FORWARD := &"move_forward"
const MOVE_BACK := &"move_back"
const MOVE_LEFT := &"move_left"
const MOVE_RIGHT := &"move_right"
const CROUCH := &"crouch"
const USE_HAND := &"use_hand"
const TOSS := &"toss"
const INSPECT := &"inspect"
const FLIP_CARD := &"flip_card"
const TURN_SIDEWAYS := &"turn_sideways"
const INTERACT := &"interact"
const FLIP_NEXT := &"flip_next"
const FLIP_PREVIOUS := &"flip_previous"
const PAUSE := &"pause"
const RADIO := &"radio"
## Hold to rip open the booster pack in hand; with cards in hand, show the
## next one.
const RIP := &"rip"
## Sorceries, one key each, from 1 in the order they're learned. Each is
## added as it's built (Serra's Blessing, on 2, comes later).
const CAST_TELEPORT := &"cast_teleport"

## Every bindable action in menu order: [action, what it's called in the menu].
const ACTIONS := [
	[MOVE_FORWARD, "Walk forward"],
	[MOVE_BACK, "Walk back"],
	[MOVE_LEFT, "Step left"],
	[MOVE_RIGHT, "Step right"],
	[CROUCH, "Crouch"],
	[USE_HAND, "Pick up, put down, file, shelve"],
	[TOSS, "Toss whatever is in your hand"],
	[INSPECT, "Inspect the held card"],
	[FLIP_CARD, "Turn the inspected card over"],
	[TURN_SIDEWAYS, "Turn the inspected card sideways"],
	[INTERACT, "Open or close a binder"],
	[FLIP_NEXT, "Next page"],
	[FLIP_PREVIOUS, "Previous page"],
	[PAUSE, "Pause"],
	[RADIO, "Radio"],
	[RIP, "Rip open a pack (hold), or show the next card"],
	[CAST_TELEPORT, "Cast Teleport"],
]

## Defaults per action: keys by physical keycode (so WASD stays put on
## other keyboard layouts) and mouse buttons by index.
const DEFAULT_KEYS := {
	MOVE_FORWARD: [KEY_W, KEY_UP],
	MOVE_BACK: [KEY_S, KEY_DOWN],
	MOVE_LEFT: [KEY_A, KEY_LEFT],
	MOVE_RIGHT: [KEY_D, KEY_RIGHT],
	CROUCH: [KEY_CTRL, KEY_C],
	INSPECT: [KEY_F],
	FLIP_CARD: [KEY_R],
	TURN_SIDEWAYS: [KEY_T],
	INTERACT: [KEY_E],
	PAUSE: [KEY_ESCAPE],
	RADIO: [KEY_Q],
	RIP: [KEY_SPACE],
	CAST_TELEPORT: [KEY_1],
}
const DEFAULT_BUTTONS := {
	USE_HAND: [MOUSE_BUTTON_LEFT],
	TOSS: [MOUSE_BUTTON_RIGHT],
	FLIP_NEXT: [MOUSE_BUTTON_WHEEL_DOWN],
	FLIP_PREVIOUS: [MOUSE_BUTTON_WHEEL_UP],
}

const BUTTON_NAMES := {
	MOUSE_BUTTON_LEFT: "click",
	MOUSE_BUTTON_RIGHT: "right-click",
	MOUSE_BUTTON_MIDDLE: "middle-click",
	MOUSE_BUTTON_WHEEL_UP: "wheel up",
	MOUSE_BUTTON_WHEEL_DOWN: "wheel down",
	MOUSE_BUTTON_XBUTTON1: "mouse 4",
	MOUSE_BUTTON_XBUTTON2: "mouse 5",
}


func _ready() -> void:
	reset_all()
	load_rebinds()


## The events bound to an action, primary first.
func events(action: StringName) -> Array[InputEvent]:
	return InputMap.action_get_events(action)


## How to show an action's primary binding in a hint: "E", "click", ...
func label(action: StringName) -> String:
	var bound := events(action)
	return event_label(bound[0]) if not bound.is_empty() else "unbound"


## Two actions shown as one, as for turning pages: "scroll" when they're
## the two wheel directions, otherwise both names.
func pair_label(first: StringName, second: StringName) -> String:
	var a := events(first)
	var b := events(second)
	if not a.is_empty() and not b.is_empty() and a[0] is InputEventMouseButton and b[0] is InputEventMouseButton:
		var buttons := [a[0].button_index, b[0].button_index]
		if MOUSE_BUTTON_WHEEL_UP in buttons and MOUSE_BUTTON_WHEEL_DOWN in buttons:
			return "scroll"
	return "%s/%s" % [label(first), label(second)]


static func event_label(event: InputEvent) -> String:
	if event is InputEventMouseButton:
		return BUTTON_NAMES.get(event.button_index, "mouse %d" % event.button_index)
	if event is InputEventKey:
		var keycode: int = DisplayServer.keyboard_get_keycode_from_physical(event.physical_keycode) \
			if DisplayServer.get_name() != "headless" else event.physical_keycode
		return OS.get_keycode_string(keycode)
	return event.as_text()


## Makes `event` the action's primary binding (or its `slot`th), replacing
## what was there. Other actions keep their bindings; the menu decides what
## to do about clashes (see actions_using()).
func rebind(action: StringName, event: InputEvent, slot := 0) -> void:
	var bound := events(action)
	if slot < bound.size():
		bound[slot] = event
	else:
		bound.append(event)
	_set_events(action, bound)
	bindings_changed.emit()


## Every action an event already triggers.
func actions_using(event: InputEvent) -> Array[StringName]:
	var found: Array[StringName] = []
	for entry in ACTIONS:
		for bound in events(entry[0]):
			if _same(bound, event):
				found.append(entry[0])
	return found


## Puts one action back to its defaults.
func reset(action: StringName) -> void:
	_set_events(action, default_events(action))
	bindings_changed.emit()


func reset_all() -> void:
	for entry in ACTIONS:
		_set_events(entry[0], default_events(entry[0]))
	bindings_changed.emit()


static func default_events(action: StringName) -> Array[InputEvent]:
	var made: Array[InputEvent] = []
	for keycode in DEFAULT_KEYS.get(action, []):
		made.append(_key(keycode))
	for button in DEFAULT_BUTTONS.get(action, []):
		made.append(_button(button))
	return made


## Writes every action that differs from its defaults.
func save(path := SAVE_PATH) -> void:
	var file := ConfigFile.new()
	for entry in ACTIONS:
		var action: StringName = entry[0]
		var bound := events(action)
		if not _same_list(bound, default_events(action)):
			file.set_value("bindings", action, bound.map(_describe))
	file.save(path)


func load_rebinds(path := SAVE_PATH) -> void:
	var file := ConfigFile.new()
	if file.load(path) != OK or not file.has_section("bindings"):
		return
	for entry in ACTIONS:
		var action: StringName = entry[0]
		if not file.has_section_key("bindings", action):
			continue
		var bound: Array[InputEvent] = []
		for described in file.get_value("bindings", action):
			var event := _parse(described)
			if event != null:
				bound.append(event)
		_set_events(action, bound)
	bindings_changed.emit()


func _set_events(action: StringName, bound: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	InputMap.action_erase_events(action)
	for event in bound:
		InputMap.action_add_event(action, event)


## Saved as plain text ("key:87", "mouse:1"), never as objects.
static func _describe(event: InputEvent) -> String:
	if event is InputEventKey:
		return "key:%d" % event.physical_keycode
	if event is InputEventMouseButton:
		return "mouse:%d" % event.button_index
	return ""


static func _parse(described) -> InputEvent:
	var parts := str(described).split(":")
	if parts.size() != 2 or not parts[1].is_valid_int():
		return null
	match parts[0]:
		"key":
			return _key(int(parts[1]))
		"mouse":
			return _button(int(parts[1]))
	return null


static func _key(keycode: int) -> InputEventKey:
	var key := InputEventKey.new()
	key.physical_keycode = keycode
	return key


static func _button(index: int) -> InputEventMouseButton:
	var button := InputEventMouseButton.new()
	button.button_index = index
	return button


static func _same(a: InputEvent, b: InputEvent) -> bool:
	return _describe(a) != "" and _describe(a) == _describe(b)


static func _same_list(a: Array, b: Array) -> bool:
	return a.map(_describe) == b.map(_describe)
