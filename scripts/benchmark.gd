extends Node
## Frame-rate benchmark for the pile (M2's 60 fps target). Run with:
##   godot --path . -- --benchmark
## The camera walks a fixed loop through the store for DURATION seconds, then
## prints average fps, 1% low and draw calls, and quits.

const WARMUP := 2.0
const DURATION := 20.0
## Eye-height waypoints (x, z): a lap of the room past all three shelves,
## then through the middle between the tables.
const PATH := [
	Vector2(6, 7.3), Vector2(1.4, 6.6), Vector2(1.4, 1.2), Vector2(6, 1.2), Vector2(10.6, 1.2),
	Vector2(10.6, 6.6), Vector2(6, 6.6), Vector2(6, 1.6), Vector2(6, 7.3),
]

var _camera: Camera3D
var _elapsed := 0.0
var _frame_times := PackedFloat32Array()
var _max_draw_calls := 0


func _ready() -> void:
	if not "--benchmark" in OS.get_cmdline_user_args():
		queue_free()
		return
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var player: Node3D = get_node("../Player")
	player.process_mode = Node.PROCESS_MODE_DISABLED
	_camera = Camera3D.new()
	_camera.fov = 75
	get_parent().add_child.call_deferred(_camera)
	_camera.ready.connect(_camera.make_current)


func _process(delta: float) -> void:
	if _camera == null or not _camera.is_inside_tree():
		return
	_elapsed += delta
	var t := clampf((_elapsed) / (WARMUP + DURATION), 0.0, 1.0) * (PATH.size() - 1)
	var i := mini(int(t), PATH.size() - 2)
	var a: Vector2 = PATH[i]
	var b: Vector2 = PATH[i + 1]
	var p := a.lerp(b, t - i)
	_camera.global_position = Vector3(p.x, 1.65, p.y)
	var ahead := a.lerp(b, minf(1.0, t - i + 0.2))
	if ahead.distance_to(p) > 0.01:
		_camera.look_at(Vector3(ahead.x, 0.6, ahead.y))
	if _elapsed > WARMUP:
		_frame_times.append(delta)
		_max_draw_calls = maxi(_max_draw_calls, RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
	if _elapsed >= WARMUP + DURATION:
		_report()
		get_tree().quit()


func _report() -> void:
	var sorted := _frame_times.duplicate()
	sorted.sort()
	var total := 0.0
	for ft in sorted:
		total += ft
	var average_fps := sorted.size() / total
	var slowest := sorted.slice(int(sorted.size() * 0.99))
	var slow_total := 0.0
	for ft in slowest:
		slow_total += ft
	var low_fps := slowest.size() / slow_total
	var line := "BENCHMARK cards=%d frames=%d avg_fps=%.1f one_percent_low_fps=%.1f max_draw_calls=%d gpu=%s" % [
		CardDatabase.card_count(), sorted.size(), average_fps, low_fps, _max_draw_calls,
		RenderingServer.get_video_adapter_name()]
	print(line)
