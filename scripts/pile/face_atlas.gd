class_name FaceAtlas
extends RefCounted
## Small card faces for the floor (plan §4.4): every card's face shrunk to
## one slot of an atlas page, the pages stacked in one Texture2DArray. Card
## i sits in page i / slots_per_page, slot i % slots_per_page, slots running
## left to right, top to bottom.
##
## Khans of Tarkir fits in two pages, so every page stays loaded. Streaming
## pages in and out comes with the full ~30,000-card collection (M8).

var texture: Texture2DArray
var columns := 0
var rows := 0
## One slot's size as a fraction of a page.
var slot_uv := Vector2.ZERO


## Loads the atlas a card data file describes (CardFileLoader's "faces"), or
## returns null if any page is missing or unreadable.
static func load_pages(faces: Dictionary) -> FaceAtlas:
	var images: Array[Image] = []
	for path in faces["pages"]:
		var image := load_image(path)
		if image == null:
			push_warning("FaceAtlas: missing atlas page %s; drawing placeholder faces" % path)
			return null
		image.convert(Image.FORMAT_RGBA8)
		image.generate_mipmaps()
		images.append(image)
	var atlas := FaceAtlas.new()
	atlas.texture = Texture2DArray.new()
	if atlas.texture.create_from_images(images) != OK:
		push_warning("FaceAtlas: atlas pages differ in size; drawing placeholder faces")
		return null
	atlas.columns = int(faces["columns"])
	atlas.rows = int(faces["rows"])
	var page_size := float(faces["page_size"])
	atlas.slot_uv = Vector2(faces["slot_size"][0], faces["slot_size"][1]) / page_size
	return atlas


## Reads an image whether or not the editor has imported it. The file on
## disk wins when it's there, because the importer rewrites atlas pages in
## place and the editor's imported copy (.godot/imported) stays stale until
## the editor rescans: a game run from the command line would otherwise show
## the old pages' faces. In an exported game only the imported texture exists.
static func load_image(path: String) -> Image:
	if FileAccess.file_exists(path):
		var image := Image.new()
		var bytes := FileAccess.get_file_as_bytes(path)
		var error := ERR_FILE_UNRECOGNIZED
		match path.get_extension().to_lower():
			"png":
				error = image.load_png_from_buffer(bytes)
			"jpg", "jpeg":
				error = image.load_jpg_from_buffer(bytes)
			"webp":
				error = image.load_webp_from_buffer(bytes)
		if error == OK:
			return image
	if ResourceLoader.exists(path):
		var texture := load(path) as Texture2D
		if texture != null:
			var image := texture.get_image()
			if image.is_compressed():
				image.decompress()
			return image
	return null


func slots_per_page() -> int:
	return columns * rows


## Hands the atlas to a shader that declares the faces uniforms (floor_card).
func apply(material: ShaderMaterial) -> void:
	material.set_shader_parameter("faces", texture)
	material.set_shader_parameter("face_grid", Vector2i(columns, rows))
	material.set_shader_parameter("face_slot_uv", slot_uv)
