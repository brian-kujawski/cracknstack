class_name LightFixtures
extends RefCounted
## The library's light fittings, built from Kiln models (assets/models):
## brass pendants with green cased-glass shades over the tables, and brass
## picture lights over the framed art. Their lights stay warm white (the
## style bible keeps coloured light for the cards and the laptop).

const PENDANT := preload("res://assets/models/library_pendant/library_pendant.glb")
const PICTURE_LIGHT := preload("res://assets/models/picture_light/picture_light.glb")

## Pendant: how far above the rim the knop over the shade reaches (the rod
## starts there), and the canopy's depth below the ceiling.
const ROD_START := 0.22
const CANOPY_DEPTH := 0.04
## The shade's cased glass: deep green, glossy, lit only from the room.
const GREEN_GLASS := Color(0.07, 0.24, 0.12)
## How brightly the shade's white opal lining glows.
const LINING_GLOW := 0.7
## Picture light: the hood's centre relative to its wall plate, as built in
## picture_light.kiln.js.
const HOOD_DROP := 0.06
const HOOD_REACH := 0.2
const PICTURE_ENERGY := 0.7

static var _pendant_parts := {}
static var _picture_parts := {}


## A pendant whose shade rim is at `rim` (in the parent's space), hanging
## from a canopy on the ceiling at `ceiling`. Lights are added by the caller.
static func pendant(parent: Node3D, rim: Vector3, ceiling: float, brass: Material) -> Node3D:
	if _pendant_parts.is_empty():
		_pendant_parts = KilnModel.parts(PENDANT, ["Canopy", "Rod", "Collar", "Knop", "Shade", "Lining", "Rim"])
	var lamp := Node3D.new()
	lamp.name = "Pendant"
	lamp.position = rim
	parent.add_child(lamp)
	var glass := StandardMaterial3D.new()
	glass.albedo_color = GREEN_GLASS
	glass.roughness = 0.12
	glass.metallic_specular = 0.8
	glass.clearcoat_enabled = true
	glass.clearcoat_roughness = 0.05
	var lining := StandardMaterial3D.new()
	lining.albedo_color = Color(0.82, 0.75, 0.62)
	lining.emission_enabled = true
	lining.emission = Color("ffd199")
	lining.emission_energy_multiplier = LINING_GLOW
	var shade := KilnModel.add(lamp, _pendant_parts["Shade"], glass)
	# The bulb sits inside, so the shade's inner faces must block light too.
	shade.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED
	KilnModel.add(lamp, _pendant_parts["Lining"], lining).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for part in ["Collar", "Knop", "Rim"]:
		KilnModel.add(lamp, _pendant_parts[part], brass)
	var top := ceiling - rim.y
	KilnModel.add(lamp, _pendant_parts["Canopy"], brass, Transform3D(Basis.IDENTITY, Vector3(0, top, 0)))
	var rod := top - CANOPY_DEPTH - ROD_START
	KilnModel.add(lamp, _pendant_parts["Rod"], brass, Transform3D(Basis.from_scale(Vector3(1, rod, 1)), Vector3(0, ROD_START, 0)))
	return lamp


## A picture light on a wall, its plate at `plate` (in the parent's space),
## the wall facing `yaw` (0 faces +z), its hood `length` long, lighting the
## frame below whose centre is `frame_drop` under the plate.
static func picture_light(parent: Node3D, plate: Vector3, yaw: float, length: float, frame_drop: float, brass: Material, light_color: Color) -> Node3D:
	if _picture_parts.is_empty():
		_picture_parts = KilnModel.parts(PICTURE_LIGHT, ["Backplate", "Arm", "Hood", "CapL", "CapR"])
	var fitting := Node3D.new()
	fitting.name = "PictureLight"
	fitting.position = plate
	fitting.rotation.y = yaw
	parent.add_child(fitting)
	for part in ["Backplate", "Arm"]:
		KilnModel.add(fitting, _picture_parts[part], brass)
	# The hood is 1 m long in the model, centred: stretch it, and move its caps
	# out to the stretched ends.
	var hood_at := Vector3(0, -HOOD_DROP, HOOD_REACH)
	var stretch := Transform3D(Basis.IDENTITY, hood_at) * Transform3D(Basis.from_scale(Vector3(length, 1, 1)), Vector3.ZERO) * Transform3D(Basis.IDENTITY, -hood_at)
	KilnModel.add(fitting, _picture_parts["Hood"], brass, stretch)
	KilnModel.add(fitting, _picture_parts["CapL"], brass, Transform3D(Basis.IDENTITY, Vector3(0.5 - length / 2, 0, 0)))
	KilnModel.add(fitting, _picture_parts["CapR"], brass, Transform3D(Basis.IDENTITY, Vector3(length / 2 - 0.5, 0, 0)))
	# Inside the hood a warm strip light washes the frame below it.
	var glow := StandardMaterial3D.new()
	glow.emission_enabled = true
	glow.emission = light_color
	glow.emission_energy_multiplier = 2.0
	glow.albedo_color = light_color
	var strip := MeshInstance3D.new()
	var strip_mesh := BoxMesh.new()
	strip_mesh.size = Vector3(length - 0.02, 0.006, 0.006)
	strip.mesh = strip_mesh
	strip.material_override = glow
	strip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	strip.position = hood_at + Vector3(0, 0.012, 0)
	fitting.add_child(strip)
	var light := SpotLight3D.new()
	light.light_color = light_color
	light.light_energy = PICTURE_ENERGY
	light.spot_range = frame_drop * 2.5 + 0.5
	light.spot_angle = 50.0
	light.spot_attenuation = 0.7
	light.light_specular = 0.3
	# Aimed at the frame's lower half, so the wash spreads down its face.
	light.transform = Transform3D(Basis.looking_at(Vector3(0, -frame_drop - 0.12, 0) - hood_at, Vector3.UP), hood_at)
	fitting.add_child(light)
	return fitting
