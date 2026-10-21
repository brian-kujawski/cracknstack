class_name HoveringCard
extends LooseCard
## A card a pile flip tossed up while its binder was open, held in the air a
## few inches above the pile (or the table it lay on) by Demonic
## Consultation, face up and ready to grab like a card on a table. When its
## time runs out, or its binder is closed, it falls back down.

## How high above the pile it hovers, and how far it bobs.
const HEIGHT := 0.12
const BOB := 0.01
const RISE_SECONDS := 0.3

var binder: Binder
var seconds_left := 0.0
var pile: PileWorld

var _base_y := 0.0
var _age := 0.0


## Lifts card `id` from where it lay (`from`, a global point on the pile) to
## hover above it for `seconds`, until `for_binder` closes.
func hover(id: int, world: PileWorld, from: Vector3, yaw: float, for_binder: Binder, seconds: float) -> void:
	pile = world
	binder = for_binder
	seconds_left = seconds
	setup(id, from + Vector3.UP * HEIGHT, yaw)
	_base_y = position.y
	position.y = from.y
	create_tween().tween_property(self, "position:y", _base_y, RISE_SECONDS) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	_age += delta
	seconds_left -= delta
	if seconds_left <= 0.0 or not binder.is_open():
		fall()
		return
	if _age > RISE_SECONDS:
		position.y = _base_y + BOB * sin((_age - RISE_SECONDS) * 3.0)


## Drops back down where it hovers: onto the pile, or the table it rose from.
func fall() -> void:
	if is_queued_for_deletion():
		return
	pile.land(card_id, global_position, rotation.y, true, [get_rid()])
	queue_free()
