class_name FaceAtlas
extends RefCounted
## Far faces for the floor (card-face-lod-plan.md): every card's face shrunk
## to one slot of an atlas page, the pages stacked in one Texture2DArray and
## always loaded. Card i sits in page i / slots_per_page, slot i %
## slots_per_page, slots running left to right, top to bottom.
##
## The importer writes the pages BC1-compressed with their mipmaps, so they
## go to the GPU as they are. At Low card detail the top mipmap is left out:
## a quarter of the memory, faces half as sharp. Cards close to the player
## get sharper near faces on top of these (NearFaces).

var texture: Texture2DArray
var columns := 0
var rows := 0
## One slot's size as a fraction of a page.
var slot_uv := Vector2.ZERO


## Loads the atlas a card data file describes (CardFileLoader's "faces"), or
## returns null if any page is missing or unreadable. `low_detail` leaves
## out each page's top mipmap.
static func load_pages(faces: Dictionary, low_detail := false) -> FaceAtlas:
	var images: Array[Image] = []
	for path in faces["pages"]:
		var image := load_image(path)
		if image == null:
			push_warning("FaceAtlas: missing atlas page %s; drawing placeholder faces" % path)
			return null
		if not image.is_compressed():
			image.convert(Image.FORMAT_RGBA8)
		if not image.has_mipmaps():
			image.generate_mipmaps()
		images.append(without_top_mipmap(image) if low_detail else image)
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
## Card faces (.dds.gz, see tools/bc1.py) are gzipped DDS files, which the
## editor never imports. Safe on worker threads (NearFaces).
static func load_image(path: String) -> Image:
	if FileAccess.file_exists(path):
		var image := Image.new()
		var bytes := FileAccess.get_file_as_bytes(path)
		var extension := path.get_extension().to_lower()
		if extension == "gz":
			bytes = bytes.decompress_dynamic(-1, FileAccess.COMPRESSION_GZIP)
			extension = path.get_basename().get_extension().to_lower()
		var error := ERR_FILE_UNRECOGNIZED
		if not bytes.is_empty():
			match extension:
				"png":
					error = image.load_png_from_buffer(bytes)
				"jpg", "jpeg":
					error = image.load_jpg_from_buffer(bytes)
				"webp":
					error = image.load_webp_from_buffer(bytes)
				"dds":
					error = image.load_dds_from_buffer(bytes)
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


## The image from its second mipmap down: half the size, a quarter of the
## memory. An image with no smaller mipmap comes back as it is.
static func without_top_mipmap(image: Image) -> Image:
	if image.get_mipmap_count() == 0:
		return image
	var data := image.get_data().slice(image.get_mipmap_offset(1))
	return Image.create_from_data(maxi(1, image.get_width() / 2), maxi(1, image.get_height() / 2),
			image.get_mipmap_count() > 1, image.get_format(), data)


func slots_per_page() -> int:
	return columns * rows


## How many pixels tall one card's face is, as loaded.
func slot_height() -> int:
	return roundi(slot_uv.y * texture.get_height())


## Hands the atlas to a shader that declares the faces uniforms (floor_card).
func apply(material: ShaderMaterial) -> void:
	material.set_shader_parameter("faces", texture)
	material.set_shader_parameter("face_grid", Vector2i(columns, rows))
	material.set_shader_parameter("face_slot_uv", slot_uv)
