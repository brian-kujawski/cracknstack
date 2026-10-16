extends SceneTree
## Generates the placeholder card data: ~150 fake sets, ~30,000 cards, one
## base version of each, numbered 1..N with no gaps (plan §4.3).
##
## Run from the project root:
##   godot --headless --script res://tools/gen_placeholder_sets.gd
##
## Output is deterministic for a given SEED, so re-running only changes the
## file when this script changes.

const OUTPUT_PATH := "res://data/placeholder/cards.json"
const SEED := 20261016
const SET_COUNT := 150
const MIN_SET_SIZE := 60
const MAX_SET_SIZE := 350
## 1993-08-05, the month Magic first came out.
const FIRST_RELEASE_UNIX := 744508800

const SET_ADJECTIVES := [
	"Shattered", "Gilded", "Drowned", "Ashen", "Verdant", "Hollow", "Radiant", "Feral",
	"Sunken", "Burning", "Silent", "Eternal", "Frozen", "Crimson", "Twilight", "Iron",
	"Wandering", "Fallen", "Hidden", "Storm-Torn",
]
const SET_NOUNS := [
	"Tides", "Thrones", "Spires", "Wilds", "Covenant", "Reaches", "Dominion", "Archive",
	"Bloodlines", "Expanse", "Ruins", "Frontier", "Pact", "Horizons", "Depths", "Crown",
	"Forge", "Requiem", "Labyrinth", "Harvest",
]
const NAME_FIRST := [
	"Grim", "Bright", "Thorn", "Ember", "Frost", "Shadow", "Iron", "Moss", "Storm", "Gloom",
	"Sun", "Bone", "Silver", "Ash", "Tide", "Wild", "Dread", "Star", "Rune", "Hollow",
]
const NAME_SECOND := [
	"caller", "walker", "binder", "shaper", "seeker", "weaver", "warden", "drinker", "breaker",
	"speaker", "hound", "drake", "golem", "sprite", "knight", "witch", "colossus", "serpent",
]
const SPELL_NAMES := [
	"Bolt", "Ritual", "Rebuke", "Growth", "Counterspell", "Edict", "Blessing", "Insight",
	"Upheaval", "Wrath", "Surge", "Bargain", "Harvest", "Gambit", "Reckoning",
]
const CREATURE_TYPES := [
	"Human Soldier", "Elf Druid", "Goblin Warrior", "Zombie", "Merfolk Wizard", "Dragon",
	"Angel", "Vampire Rogue", "Beast", "Spirit", "Golem", "Elemental", "Faerie", "Giant",
]
const COLORS := ["W", "U", "B", "R", "G"]


func _init() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED

	var sets := []
	var cards := []
	var used_set_names := {}
	for s in SET_COUNT:
		var code := "PH%03d" % (s + 1)
		var set_name := _unique_set_name(rng, used_set_names)
		# Spread release dates evenly over ~33 years (roughly 4–5 sets a year),
		# so set codes and release order agree.
		var days := s * (33 * 365) / SET_COUNT + rng.randi_range(0, 20)
		var date := Time.get_date_dict_from_unix_time(FIRST_RELEASE_UNIX + days * 86400)
		var color := Color.from_hsv(rng.randf(), rng.randf_range(0.45, 0.8), rng.randf_range(0.6, 0.9))
		sets.append({
			"code": code,
			"name": set_name,
			"release_date": "%04d-%02d-%02d" % [date.year, date.month, date.day],
			"accent_color": "#" + color.to_html(false),
		})
		var size := rng.randi_range(MIN_SET_SIZE, MAX_SET_SIZE)
		for n in range(1, size + 1):
			cards.append(_make_card(rng, code, n, size))

	var file := FileAccess.open(OUTPUT_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Could not write %s: %s" % [OUTPUT_PATH, error_string(FileAccess.get_open_error())])
		quit(1)
		return
	# One card per line keeps diffs readable without bloating the file.
	file.store_string('{"format": 1,\n"sets": %s,\n"cards": [\n' % JSON.stringify(sets, "\t"))
	for i in cards.size():
		file.store_string(JSON.stringify(cards[i]) + ("," if i < cards.size() - 1 else "") + "\n")
	file.store_string("]}\n")
	file.close()
	print("Wrote %d sets, %d cards to %s" % [sets.size(), cards.size(), OUTPUT_PATH])
	quit(0)


func _unique_set_name(rng: RandomNumberGenerator, used: Dictionary) -> String:
	while true:
		var candidate: String = "%s %s" % [_pick(rng, SET_ADJECTIVES), _pick(rng, SET_NOUNS)]
		if not used.has(candidate):
			used[candidate] = true
			return candidate
	return ""


func _make_card(rng: RandomNumberGenerator, set_code: String, number: int, set_size: int) -> Array:
	var roll := rng.randf()
	var rarity := "common"
	if roll > 0.97:
		rarity = "mythic"
	elif roll > 0.85:
		rarity = "rare"
	elif roll > 0.55:
		rarity = "uncommon"

	# Like real sets: colours in blocks, then multicolour, then colourless/lands.
	var colors := []
	var block := float(number) / set_size
	if block < 0.8:
		colors.append(COLORS[int(block / 0.16)])
	elif block < 0.92:
		var first := rng.randi_range(0, 4)
		colors.append(COLORS[first])
		colors.append(COLORS[(first + rng.randi_range(1, 4)) % 5])

	var name: String
	var type_line: String
	if block >= 0.92:
		name = "%s %s" % [_pick(rng, NAME_FIRST), _pick(rng, ["Idol", "Gate", "Relic", "Vault", "Grove", "Tower"])]
		type_line = "Artifact" if rng.randf() < 0.5 else "Land"
	elif rng.randf() < 0.6:
		name = "%s%s" % [_pick(rng, NAME_FIRST), _pick(rng, NAME_SECOND)]
		type_line = "Creature — %s" % _pick(rng, CREATURE_TYPES)
	else:
		name = "%s %s" % [_pick(rng, NAME_FIRST), _pick(rng, SPELL_NAMES)]
		type_line = "Instant" if rng.randf() < 0.5 else "Sorcery"
	return [set_code, number, name, rarity, colors, type_line]


func _pick(rng: RandomNumberGenerator, options: Array) -> String:
	return options[rng.randi_range(0, options.size() - 1)]
