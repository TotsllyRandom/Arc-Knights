extends Node

# THE ITEM DATABASE. Every item in the game is defined here, along with where it drops, how often,
# and what stats ("pips") it can have. This is the file to edit to add or change items.
#
# ---------------------------------------------------------------------------------------------
# HOW TO ADD AN ITEM: add an entry to ITEMS below. Here is every key it can have:
#
#   "name"            what the item is called
#   "slot"            where it equips: "head", "arms", "legs", "ring" or "weapon".
#                     Leave it out for items that can't be equipped (like materials).
#   "color"           the square's color until the item has art
#   "description"     shown in the tooltip
#   "drops"           WHERE it drops and HOW OFTEN: {"test_dungeon": 8, "area_b": 3}. Each name is a
#                     dungeon from DUNGEONS, and the number is the weight there. A dungeon uses ITS OWN
#                     number: in a dungeon where an item has 30 and in another where it has 50, the
#                     first dungeon uses 30. A weight of 8 drops twice as often as a 4.
#   "base_drop"       (optional) the weight used in any dungeon that isn't listed in "drops".
#                     Leave it out and the item only drops in the dungeons listed.
#   "starting_pips"   the stats that are SET on this item, the same on every copy: {"physical_resist": 3}
#   "slots_by_stars"  how many RANDOM pip slots a copy gets, by how many stars it rolled. The list is
#                     for 0, 1, 2 and 3 stars: [1, 2, 3, 4] means a 0 star copy gets 1 random pip slot,
#                     a 3 star copy gets 4. Leave this out and the item has no stars or random pips.
#   "random_pips"     (optional) which pips the random slots can roll, like ["health", "stealth"].
#                     Leave it out and any pip can roll.
#   "weapon_index"    (weapons only) which entry of Weapons.LIST it is
#   "max_stack"       (optional) how many fit in one stack. Default is 1 (doesn't stack).
#   "count_range"     (optional) [min, max] amount dropped at once, for stackable items
#
# Every time an item drops, it gets a random number of stars (0 to 3, rarer for more stars, see
# STAR_WEIGHTS). The stars decide how many random pip SLOTS it gets (slots_by_stars). Each slot
# has a rarity (common, rare or legendary, see SLOT_RARITY_WEIGHTS_BY_STARS) and picks a random pip.
# The pips themselves don't have rarities: a rarer SLOT just rolls a bigger value for its pip.
# ---------------------------------------------------------------------------------------------

const Weapons = preload("res://Scripts/weapons.gd")

# ---------------------------------------------------------------- dungeons

# Places items can drop. Each dungeon needs an entry here, and items list it in their "drops".
# (Later, the areas chosen at the Town Hall can each get an entry.)
const DUNGEONS := {
	"test_dungeon": {"name": "Test Dungeon"},
}

# ---------------------------------------------------------------- chests

# The sizes a chest can be. A chest's size comes from how many sections its room has: it gets the
# first size whose "max_sects" is big enough. "items" is how many items it holds [min, max],
# and "scale" is how big it looks.
const CHEST_SIZES := {
	"small": {"max_sects": 2, "items": [1, 2], "scale": 0.8},
	"medium": {"max_sects": 5, "items": [3, 4], "scale": 1.2},
	"large": {"max_sects": 999, "items": [5, 7], "scale": 1.8},
}

# ---------------------------------------------------------------- stars

# How likely a dropped item is to have 0, 1, 2 or 3 stars. These are weights, not percentages:
# the bigger the number, the more often it happens. Higher stars should be rarer.
const STAR_WEIGHTS := [60.0, 28.0, 10.0, 2.0]

# ---------------------------------------------------------------- pips (stats)

# Every pip: its name on screen, what's written after its number ("%" or nothing), and the range
# its value is picked from (before the slot's rarity bonus). The order here is the order they're
# listed in on screen. Add a pip here and it can roll on any item.
const PIPS := {
	"health": {"name": "Health", "suffix": "", "min": 4, "max": 10},
	"energy": {"name": "Energy", "suffix": "", "min": 4, "max": 10},
	"posture": {"name": "Posture", "suffix": "", "min": 3, "max": 8},
	"carry_load": {"name": "Carry Load", "suffix": "", "min": 2, "max": 5},
	"physical_resist": {"name": "Physical Damage Resist", "suffix": "%", "min": 2, "max": 5},
	"magic_resist": {"name": "Magic Damage Resist", "suffix": "%", "min": 2, "max": 5},
	"enemy_resist": {"name": "Enemy Damage Resist", "suffix": "%", "min": 2, "max": 5},
	"stealth": {"name": "Stealth", "suffix": "", "min": 2, "max": 5},
	"sanity": {"name": "Sanity", "suffix": "", "min": 3, "max": 8},
	"reload_speed": {"name": "Reload Speed", "suffix": "%", "min": 3, "max": 6},
	"ammo_capacity": {"name": "Ammo Capacity", "suffix": "", "min": 2, "max": 5},
	"move_speed": {"name": "Move Speed", "suffix": "%", "min": 1, "max": 3},
}

# ---------------------------------------------------------------- pip slots

# The rarities a pip SLOT can have, and how much each multiplies the value rolled for its pip.
# (A rare slot with Health in it gives more Health than a common slot with Health in it.)
const SLOT_RARITIES := {
	"common": {"multiplier": 1.0},
	"rare": {"multiplier": 1.8},
	"legendary": {"multiplier": 3.0},
}

# How likely each random pip slot is to be common, rare or legendary, for an item with 0, 1, 2 and
# 3 stars (in that order). More stars means better odds of rare and legendary slots.
const SLOT_RARITY_WEIGHTS_BY_STARS := [
	{"common": 90.0, "rare": 10.0, "legendary": 0.0},
	{"common": 70.0, "rare": 27.0, "legendary": 3.0},
	{"common": 50.0, "rare": 40.0, "legendary": 10.0},
	{"common": 30.0, "rare": 45.0, "legendary": 25.0},
]

# ---------------------------------------------------------------- the items

const GUN_COLOR := Color(1.0, 0.6, 0.2)
const MELEE_COLOR := Color(0.7, 0.8, 0.9)

const ITEMS := {
	# ---- Weapons (no stars or pips)
	"pistol": {
		"name": "Pistol", "slot": "weapon", "weapon_index": 0, "color": GUN_COLOR,
		"drops": {"test_dungeon": 4},
	},
	"rifle": {
		"name": "Rifle", "slot": "weapon", "weapon_index": 1, "color": GUN_COLOR,
		"drops": {"test_dungeon": 3},
	},
	"burst_rifle": {
		"name": "Burst Rifle", "slot": "weapon", "weapon_index": 2, "color": GUN_COLOR,
		"drops": {"test_dungeon": 3},
	},
	"shotgun": {
		"name": "Shotgun", "slot": "weapon", "weapon_index": 3, "color": GUN_COLOR,
		"drops": {"test_dungeon": 3},
	},
	"sword": {
		"name": "Sword", "slot": "weapon", "weapon_index": 4, "color": MELEE_COLOR,
		"drops": {"test_dungeon": 4},
	},
	"spear": {
		"name": "Spear", "slot": "weapon", "weapon_index": 5, "color": MELEE_COLOR,
		"drops": {"test_dungeon": 3},
	},
	"hammer": {
		"name": "Hammer", "slot": "weapon", "weapon_index": 6, "color": MELEE_COLOR,
		"drops": {"test_dungeon": 2},
	},

	# ---- Armor and rings
	"neon_visor": {
		"name": "Neon Visor", "slot": "head", "color": Color(0.3, 0.9, 1.0),
		"description": "A placeholder helmet.",
		"drops": {"test_dungeon": 8},
		"starting_pips": {"physical_resist": 3},
		"slots_by_stars": [1, 2, 3, 4],
	},
	"chrome_gauntlets": {
		"name": "Chrome Gauntlets", "slot": "arms", "color": Color(0.75, 0.75, 0.85),
		"description": "Placeholder arm armor.",
		"drops": {"test_dungeon": 8},
		"starting_pips": {"physical_resist": 4},
		"slots_by_stars": [1, 1, 2, 3],
	},
	"mag_boots": {
		"name": "Mag Boots", "slot": "legs", "color": Color(0.6, 0.4, 0.9),
		"description": "Placeholder leg armor.",
		"drops": {"test_dungeon": 8},
		"starting_pips": {"stealth": 3},
		"slots_by_stars": [1, 2, 2, 3],
	},
	"static_ring": {
		"name": "Static Ring", "slot": "ring", "color": Color(1.0, 0.9, 0.3),
		"description": "A placeholder ring.",
		"drops": {"test_dungeon": 6},
		"starting_pips": {"magic_resist": 2},
		"slots_by_stars": [1, 1, 2, 3],
	},
	"ember_ring": {
		"name": "Ember Ring", "slot": "ring", "color": Color(1.0, 0.4, 0.3),
		"description": "A placeholder ring.",
		"drops": {"test_dungeon": 6},
		"starting_pips": {"health": 5},
		"slots_by_stars": [1, 2, 2, 3],
	},

	# ---- Materials
	"scrap": {
		"name": "Scrap", "color": Color(0.55, 0.55, 0.55),
		"description": "A placeholder material that stacks.",
		"drops": {"test_dungeon": 12},
		"max_stack": 99,
		"count_range": [1, 5],
	},
}


# ---------------------------------------------------------------- making and dropping items

# Builds a new copy of an item, ready to put in the inventory. Armor and rings roll their stars and
# random pips here, so no two copies are the same. Pass forced_stars (0 to 3) to skip the star roll.
#     Inventory.add_item(Items.create_item("neon_visor"))
func create_item(item_id: String, forced_stars: int = -1) -> Dictionary:
	if not ITEMS.has(item_id):
		push_error("Items.create_item: there is no item called '%s'" % item_id)
		return {}
	var definition: Dictionary = ITEMS[item_id]

	var extra := {}
	if definition.has("weapon_index"):
		extra["weapon_index"] = definition["weapon_index"]
	if definition.has("max_stack"):
		extra["max_stack"] = definition["max_stack"]
	if definition.has("count_range"):
		var amounts: Array = definition["count_range"]
		extra["count"] = randi_range(amounts[0], amounts[1])

	var item := Inventory.make_item(
		item_id,
		definition["name"],
		definition.get("slot", ""),
		definition.get("color", Color.GRAY),
		_description_for(definition),
		extra
	)

	# Stars and pips, for items that have "slots_by_stars"
	if definition.has("slots_by_stars"):
		var stars: int = forced_stars if forced_stars >= 0 else roll_stars()
		stars = clampi(stars, 0, 3)

		var pips := []
		var used := {}
		# The pips that are SET on this item
		var starting: Dictionary = definition.get("starting_pips", {})
		for pip_id in starting:
			pips.append(_make_pip(pip_id, int(starting[pip_id]), "set", true))
			used[pip_id] = true
		# The random pip slots
		var allowed: Array = definition.get("random_pips", PIPS.keys())
		var slot_counts: Array = definition["slots_by_stars"]
		var slots: int = int(slot_counts[mini(stars, slot_counts.size() - 1)])
		for i in range(slots):
			var rolled := _roll_pip(stars, used, allowed)
			if rolled.is_empty():
				break
			pips.append(rolled)
			used[rolled["id"]] = true

		item["has_stars"] = true
		item["stars"] = stars
		item["pips"] = pips
		item["stats"] = _total_of(pips)
	return item


# Picks a random item that can drop in a dungeon (using each item's drop weights for THAT dungeon,
# or its base_drop if it doesn't list the dungeon) and builds it.
# Returns an empty Dictionary if nothing can drop there.
func roll_drop(dungeon_id: String) -> Dictionary:
	var weights := {}
	for item_id in ITEMS:
		var definition: Dictionary = ITEMS[item_id]
		var drops: Dictionary = definition.get("drops", {})
		var weight := float(drops.get(dungeon_id, definition.get("base_drop", 0.0)))
		if weight > 0.0:
			weights[item_id] = weight
	var chosen := _pick_weighted(weights)
	if chosen == "":
		return {}
	return create_item(chosen)


# Fills a chest: rolls as many drops as that chest size holds. Returns an Array of items.
func roll_chest_items(dungeon_id: String, size_name: String) -> Array:
	var info: Dictionary = CHEST_SIZES.get(size_name, CHEST_SIZES["small"])
	var counts: Array = info["items"]
	var found := []
	for i in range(randi_range(counts[0], counts[1])):
		var item := roll_drop(dungeon_id)
		if not item.is_empty():
			found.append(item)
	return found


# Which chest size a room gets, from how many sections it has
func chest_size_for(sect_count: int) -> String:
	for size_name in CHEST_SIZES:
		if sect_count <= int(CHEST_SIZES[size_name]["max_sects"]):
			return size_name
	return "large"


# Rolls how many stars (0 to 3) a new item gets, using STAR_WEIGHTS
func roll_stars() -> int:
	var total := 0.0
	for weight in STAR_WEIGHTS:
		total += weight
	var roll := randf() * total
	for i in range(STAR_WEIGHTS.size()):
		roll -= STAR_WEIGHTS[i]
		if roll <= 0.0:
			return i
	return STAR_WEIGHTS.size() - 1


# The name shown for a dungeon
func dungeon_name(dungeon_id: String) -> String:
	return DUNGEONS.get(dungeon_id, {}).get("name", dungeon_id)


# ---------------------------------------------------------------- text for the screen

# The text of an item's tooltip: its name, stars, description and pips
func tooltip(item: Dictionary) -> String:
	var text: String = item.get("name", "")
	if item.get("has_stars", false):
		text += "   %d / 3 stars" % int(item.get("stars", 0))
	if item.get("description", "") != "":
		text += "\n" + item["description"]
	var pips: Array = item.get("pips", [])
	if not pips.is_empty():
		text += "\n"
		for pip in pips:
			text += "\n" + pip_text(pip)
	return text


# One pip as text, like "+6% Physical Damage Resist". Pips from rare and legendary slots are marked.
func pip_text(pip: Dictionary) -> String:
	var info: Dictionary = PIPS.get(pip["id"], {})
	var value: int = int(pip["value"])
	var plus := "+" if value >= 0 else ""
	var text := "%s%d%s %s" % [plus, value, info.get("suffix", ""), info.get("name", pip["id"])]
	var rarity: String = pip.get("rarity", "common")
	if rarity == "rare" or rarity == "legendary":
		text += "  [%s slot]" % rarity
	return text


# A list of pip totals (like the sum of everything you have equipped), one per line
func totals_text(totals: Dictionary) -> String:
	var lines := []
	for pip_id in PIPS:
		var value: int = int(totals.get(pip_id, 0))
		if value != 0:
			var info: Dictionary = PIPS[pip_id]
			lines.append("%s%d%s %s" % ["+" if value > 0 else "", value, info["suffix"], info["name"]])
	return "\n".join(lines)


# What a line about an item says when it's listed (in a chest or a pickup popup)
func pickup_text(item: Dictionary) -> String:
	var text: String = item.get("name", "")
	if int(item.get("count", 1)) > 1:
		text += " x%d" % int(item["count"])
	if item.get("has_stars", false):
		text += "  (%d stars)" % int(item.get("stars", 0))
	return text


# ---------------------------------------------------------------- internals

func _description_for(definition: Dictionary) -> String:
	if definition.has("description"):
		return definition["description"]
	if definition.has("weapon_index"):
		return _weapon_description(int(definition["weapon_index"]))
	return ""


func _weapon_description(weapon_index: int) -> String:
	var stats: Dictionary = Weapons.LIST[weapon_index]
	if stats.get("type", Weapons.Type.GUN) == Weapons.Type.GUN:
		return "Gun. Damage %d, holds %d bullets." % [stats.get("damage", 0), stats.get("max_ammo", 0)]
	return "Melee. Damage %d, range %.1f." % [stats.get("damage", 0), stats.get("melee_range", 0.0)]


# "rarity" is the rarity of the SLOT the pip rolled in ("set" for pips that are always on the item)
func _make_pip(pip_id: String, value: int, rarity: String, fixed: bool) -> Dictionary:
	return {"id": pip_id, "value": value, "rarity": rarity, "fixed": fixed}


# Rolls one random pip slot: first the slot's rarity (more stars means better odds), then which
# pip goes in it, then the pip's value, which the slot's rarity multiplies. Pips already on the
# item (in "used") aren't picked again.
func _roll_pip(stars: int, used: Dictionary, allowed: Array) -> Dictionary:
	var weights: Dictionary = SLOT_RARITY_WEIGHTS_BY_STARS[clampi(stars, 0, SLOT_RARITY_WEIGHTS_BY_STARS.size() - 1)]
	var rarity := _pick_weighted(weights)

	var options := []
	for pip_id in allowed:
		if PIPS.has(pip_id) and not used.has(pip_id):
			options.append(pip_id)
	if options.is_empty():
		return {}

	var chosen: String = options.pick_random()
	var info: Dictionary = PIPS[chosen]
	var base_value := randi_range(int(info["min"]), int(info["max"]))
	var multiplier: float = SLOT_RARITIES.get(rarity, {}).get("multiplier", 1.0)
	return _make_pip(chosen, maxi(1, roundi(base_value * multiplier)), rarity, false)


# Adds up the values of a list of pips, giving {"pip id": total}
func _total_of(pips: Array) -> Dictionary:
	var totals := {}
	for pip in pips:
		totals[pip["id"]] = int(totals.get(pip["id"], 0)) + int(pip["value"])
	return totals


# Picks one key from a Dictionary of {key: weight}, so keys with bigger weights get picked more often
func _pick_weighted(weights: Dictionary) -> String:
	var total := 0.0
	for key in weights:
		total += float(weights[key])
	if total <= 0.0:
		return ""
	var roll := randf() * total
	for key in weights:
		roll -= float(weights[key])
		if roll <= 0.0:
			return str(key)
	return str(weights.keys().back())
