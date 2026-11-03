class_name CardView
extends RefCounted
## Fills in a single-card material (held_card, binder_card) for a card id.
## With real data that's the card's large image in the hand, and its near
## face (NearFaces) in a binder or on a table, where it's never much bigger
## on screen and a whole table of cards would otherwise hold a large image
## each; otherwise the placeholder face drawn by the shader. Rare cards
## (RareCards) are foil: their material gets the foil version of its shader
## (see foil.gdshaderinc).

## Large faces kept in memory, most recently used last. An open binder shows
## 18 cards, so this covers a few spreads plus the hand and the stacks.
const LARGE_CACHE_SIZE := 64

## Shaders that show the near face rather than the large image.
const NEAR_SHADERS := [preload("res://shaders/binder_card.gdshader"), preload("res://shaders/binder_foil.gdshader")]

## Each plain card shader and its foil version.
const FOIL_SHADERS := {
	preload("res://shaders/held_card.gdshader"): preload("res://shaders/held_foil.gdshader"),
	preload("res://shaders/binder_card.gdshader"): preload("res://shaders/binder_foil.gdshader"),
}

static var _large_cache := {} # card id -> Texture2D
static var _large_order: Array[int] = []
static var _near_cache := {} # card id -> Texture2D
static var _near_order: Array[int] = []


static func apply(material: ShaderMaterial, id: int) -> void:
	var card := Collection.card(id)
	var rare := Collection.is_rare(id)
	_set_foil(material, rare)
	var set_data := CardDatabase.get_set(card.set_code)
	var accent := set_data.accent_color
	material.set_shader_parameter("accent", Vector3(accent.r, accent.g, accent.b))
	material.set_shader_parameter("set_number", CardDatabase.sets_in_shelf_order().find(set_data) + 1)
	material.set_shader_parameter("collector_number", card.collector_number)
	material.set_shader_parameter("rarity", card.rarity)
	material.set_shader_parameter("alpha_corners", card.has_alpha_corners())
	var face := near_face(card) if material.shader in NEAR_SHADERS else null
	if face == null:
		face = large_face(card)
	material.set_shader_parameter("has_face", face != null)
	material.set_shader_parameter("face_texture", face)
	CardDatabase.apply_back(material, card)


## Swaps the material to the foil or plain version of its shader. Swapped
## before any parameters are set, so the new shader takes them all.
static func _set_foil(material: ShaderMaterial, foil: bool) -> void:
	for plain: Shader in FOIL_SHADERS:
		if material.shader == plain and foil:
			material.shader = FOIL_SHADERS[plain]
		elif material.shader == FOIL_SHADERS[plain] and not foil:
			material.shader = plain


## The card's large image as a texture, or null if it has none.
static func large_face(card: CardData) -> Texture2D:
	if card.image_large.is_empty():
		return null
	if _large_cache.has(card.id):
		_large_order.erase(card.id)
		_large_order.append(card.id)
		return _large_cache[card.id]
	var image := FaceAtlas.load_image(card.image_large)
	if image == null:
		return null
	image.generate_mipmaps()
	var texture := ImageTexture.create_from_image(image)
	_large_cache[card.id] = texture
	_large_order.append(card.id)
	if _large_order.size() > LARGE_CACHE_SIZE:
		_large_cache.erase(_large_order.pop_front())
	return texture


## The card's near face as a texture, or null if it has none.
static func near_face(card: CardData) -> Texture2D:
	if card.image_near.is_empty():
		return null
	if _near_cache.has(card.id):
		_near_order.erase(card.id)
		_near_order.append(card.id)
		return _near_cache[card.id]
	var image := FaceAtlas.load_image(card.image_near)
	if image == null:
		return null
	var texture := ImageTexture.create_from_image(image)
	_near_cache[card.id] = texture
	_near_order.append(card.id)
	if _near_order.size() > LARGE_CACHE_SIZE:
		_near_cache.erase(_near_order.pop_front())
	return texture


## Forgets cached faces (after CardDatabase loads a different file).
static func clear_cache() -> void:
	_large_cache.clear()
	_large_order.clear()
	_near_cache.clear()
	_near_order.clear()
