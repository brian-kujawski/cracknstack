class_name Glide
extends RefCounted
## Short, simple moves of things between the hand and the world: a card
## coming up off the floor, going into a pocket, a binder being set down.
## Nothing fancy, just an eased slide (and turn) from one pose to another,
## with an optional little lift in the middle so put-downs arc rather than
## slide along the surface.


## Moves `node` from the global pose `from` to the pose `to` returns. `to` is
## asked again every frame, so the target can move (the hand moves with the
## camera). Returns the tween, so callers can chain what happens on arrival.
static func start(node: Node3D, from: Transform3D, to: Callable, seconds: float, lift := 0.0) -> Tween:
	var tween := node.create_tween()
	tween.tween_method(func(t: float) -> void:
		node.global_transform = pose(from, to.call(), t, lift), 0.0, 1.0, seconds) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	return tween


## Adds a second leg to a glide: after what `tween` already does, `node`
## slides from `from` to `to`, easing to a stop.
static func then(tween: Tween, node: Node3D, from: Transform3D, to: Transform3D, seconds: float) -> Tween:
	tween.tween_method(func(t: float) -> void:
		node.global_transform = from.interpolate_with(to, t), 0.0, 1.0, seconds) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	return tween


## The pose a fraction `t` of the way from `from` to `to`, raised by up to
## `lift` metres at the midpoint.
static func pose(from: Transform3D, to: Transform3D, t: float, lift := 0.0) -> Transform3D:
	var p := from.interpolate_with(to, t)
	p.origin.y += lift * sin(PI * t)
	return p


## A card lying flat with its face up (or down), turned to `yaw`, as a quad
## (whose face is its local +Z and top edge its local +Y). The top edge points
## along the turned -Z, as on the floor and in binder pockets.
static func flat_card(origin: Vector3, basis_y: Basis, face_up := true) -> Transform3D:
	var lie := Basis(Vector3.RIGHT, -PI / 2)
	if not face_up:
		lie = Basis(Vector3.BACK, PI) * lie
	return Transform3D(basis_y * lie, origin)
