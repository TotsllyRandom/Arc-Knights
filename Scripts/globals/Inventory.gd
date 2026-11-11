extends Node

# The player's inventory. It's an autoload, so it carries over from one dungeon to the next.
# The inventory screen (inventory_screen.gd) shows and edits this, and the player reads its
# two weapon slots to decide which weapons they're carrying.
#
# THE BAG has no limit and only holds items (there are no empty spaces). The number of items you
# can carry comfortably is your CARRY LOAD: BASE_CARRY_LOAD plus the Carry Load pips on what you
# have equipped. Every item or stack past that still fits, but slows the player down.
#
# WHERE ITEMS ARE DEFINED: items live in the item database, Items.gd. To give the player an item:
#     Inventory.add_item(Items.create_item("neon_visor"))
#
# An item is a Dictionary with these keys (Items.create_item fills them in):
#   id           - the item's id in Items.gd (identical stackable items share it)
#   name         - shown on the item and in its tooltip
#   slot         - which equipment slot it fits: "head", "arms", "legs", "ring" or "weapon".
#                  "" means it can't be equipped (materials, potions...)
#   color        - the square's color. A stand-in until items have icon art.
#   icon         - an optional Texture2D (not drawn yet; this is where item art will go)
#   description  - shown in the tooltip
#   count        - how many are in this stack
#   max_stack    - how many fit in one stack (1 = doesn't stack)
#   stats        - the item's pip totals, {"physical_resist": 7, ...}
# Armor and rings that roll stars also have:
#   has_stars    - true
#   stars        - 0 to 3
#   pips         - the list of pips on it: {"id", "value", "rarity", "fixed"}
# Weapon items also have "weapon_index", which is that weapon's position in Weapons.LIST.

# Sent whenever anything in the inventory changes, so the screen can redraw
signal changed
# Sent when one of the two weapon slots changes, so the player can switch to the new weapon
signal weapons_changed
# Sent when the player drops an item. The player spawns it on the ground.
signal item_dropped(item)

# The bag is shown 10 items across. The screen shows this many rows and scrolls for more.
const BAG_COLUMNS := 10
const BAG_VISIBLE_ROWS := 5

# How many items fit before you're slowed down, before adding the Carry Load pips
const BASE_CARRY_LOAD := 20
# Each item over the limit slows the player by this much (0.04 = 4% of their speed)...
const OVERLOAD_SLOWDOWN_PER_ITEM := 0.04
# ...but never below this fraction of their normal speed
const MIN_SPEED_MULTIPLIER := 0.35

# Every equipment slot, and the kind of item (an item's "slot") that it accepts
const EQUIPMENT_SLOTS := {
	"head": "head",
	"arms": "arms",
	"legs": "legs",
	"ring1": "ring",
	"ring2": "ring",
	"ring3": "ring",
	"ring4": "ring",
	"weapon1": "weapon",
	"weapon2": "weapon",
}

# What an empty equipment slot says on the inventory screen
const SLOT_LABELS := {
	"head": "Head",
	"arms": "Arms",
	"legs": "Legs",
	"ring1": "Ring",
	"ring2": "Ring",
	"ring3": "Ring",
	"ring4": "Ring",
	"weapon1": "Weapon",
	"weapon2": "Weapon",
}

# Starts the inventory with some items so there's something to try out.
# Set this to false once the player should start with nothing.
const ADD_DEMO_ITEMS := true

# Every item in the bag, in order. There are never any empty spaces in this list.
var bag: Array = []
# Equipment slot id -> item Dictionary (or null if empty)
var equipment: Dictionary = {}

# How many menus that need the mouse are open (the inventory, a chest). While any are open, the
# camera lock lets go of the mouse so it can click things.
var open_menus := 0


func _ready() -> void:
	clear()
	if ADD_DEMO_ITEMS:
		_add_demo_items()


# Empties everything. Call this when a new character starts.
func clear() -> void:
	bag.clear()
	equipment.clear()
	for slot_id in EQUIPMENT_SLOTS:
		equipment[slot_id] = null
	changed.emit()
	weapons_changed.emit()


# Menus call these when they open and close, so the player knows to free the mouse
func menu_opened() -> void:
	open_menus += 1


func menu_closed() -> void:
	open_menus = maxi(open_menus - 1, 0)


# ---------------------------------------------------------------- carry load

# How many items the player can carry before being slowed
func get_carry_capacity() -> int:
	return BASE_CARRY_LOAD + int(get_total_pips().get("carry_load", 0))


# How many bag spaces are used (every item or stack takes one)
func get_carry_used() -> int:
	return bag.size()


# How many items are over the limit (0 if none)
func get_overload() -> int:
	return maxi(get_carry_used() - get_carry_capacity(), 0)


# What the player's speed is multiplied by: 1.0 normally, less when carrying too much
func get_speed_multiplier() -> float:
	return clampf(1.0 - get_overload() * OVERLOAD_SLOWDOWN_PER_ITEM, MIN_SPEED_MULTIPLIER, 1.0)


# ---------------------------------------------------------------- slots

# Slot ids are "bag0", "bag1"... for the bag (by position), and the names in EQUIPMENT_SLOTS for equipment
func bag_slot_id(index: int) -> String:
	return "bag%d" % index


func is_bag_slot(slot_id: String) -> bool:
	return slot_id.begins_with("bag")


func bag_index(slot_id: String) -> int:
	return int(slot_id.substr(3))


# The item in a slot, or null if it's empty
func get_item(slot_id: String) -> Variant:
	if is_bag_slot(slot_id):
		var index := bag_index(slot_id)
		if index < 0 or index >= bag.size():
			return null
		return bag[index]
	return equipment.get(slot_id)


# Puts an item in a slot (null empties it). Emptied bag spaces are cleaned up afterwards by _compact_bag.
func _set_item(slot_id: String, item: Variant) -> void:
	if is_bag_slot(slot_id):
		var index := bag_index(slot_id)
		if index >= bag.size():
			if item != null:
				bag.append(item)
		else:
			bag[index] = item
	else:
		equipment[slot_id] = item


# Removes empty spaces from the bag, so it never has gaps
func _compact_bag() -> void:
	bag = bag.filter(func(entry): return entry != null)


# Can this item sit in this slot? Any item can go in the bag; equipment slots only take their own kind.
func accepts(slot_id: String, item: Dictionary) -> bool:
	if is_bag_slot(slot_id):
		return true
	var kind: String = EQUIPMENT_SLOTS.get(slot_id, "#")
	return kind == item.get("slot", "")


# ---------------------------------------------------------------- moving items

func _can_stack(moving: Dictionary, target: Dictionary) -> bool:
	return moving.get("id", "") == target.get("id", "") \
		and int(target.get("max_stack", 1)) > 1 \
		and int(target.get("count", 1)) < int(target.get("max_stack", 1))


# Would moving the item in one slot onto another slot work?
func can_move(from_id: String, to_id: String) -> bool:
	if from_id == to_id:
		return false
	var moving = get_item(from_id)
	if moving == null or not accepts(to_id, moving):
		return false
	var target = get_item(to_id)
	if target == null or _can_stack(moving, target):
		return true
	# Swapping: the other item has to be able to go back where this one came from
	return accepts(from_id, target)


# Moves the item in one slot onto another slot. If the other slot has an item, they swap
# (or merge, if they're the same kind of stackable item). Returns true if anything moved.
func move_item(from_id: String, to_id: String) -> bool:
	if not can_move(from_id, to_id):
		return false
	var moving: Dictionary = get_item(from_id)
	var target = get_item(to_id)

	if target != null and _can_stack(moving, target):
		var room: int = int(target.get("max_stack", 1)) - int(target.get("count", 1))
		var moved: int = mini(room, int(moving.get("count", 1)))
		target["count"] = int(target.get("count", 1)) + moved
		moving["count"] = int(moving.get("count", 1)) - moved
		if moving["count"] <= 0:
			_set_item(from_id, null)
	else:
		_set_item(to_id, moving)
		_set_item(from_id, target)

	_compact_bag()
	_announce_change(from_id, to_id)
	return true


# Takes an equipped item off and puts it at the end of the bag
func unequip_to_bag(slot_id: String) -> bool:
	if is_bag_slot(slot_id):
		return false
	var item = equipment.get(slot_id)
	if item == null:
		return false
	equipment[slot_id] = null
	bag.append(item)
	_announce_change(slot_id, "")
	return true


# Right-click shortcut. An item in the bag goes into the matching equipment slot (an empty one
# if there is one, otherwise it swaps with the first). An equipped item goes back to the bag.
func quick_move(slot_id: String) -> bool:
	var item = get_item(slot_id)
	if item == null:
		return false

	if not is_bag_slot(slot_id):
		return unequip_to_bag(slot_id)

	var kind: String = item.get("slot", "")
	if kind == "":
		return false
	var candidates := []
	for id in EQUIPMENT_SLOTS:
		if EQUIPMENT_SLOTS[id] == kind:
			candidates.append(id)
	if candidates.is_empty():
		return false
	for id in candidates:
		if get_item(id) == null:
			return move_item(slot_id, id)
	return move_item(slot_id, candidates[0])


# Drops the item in a slot: it leaves the inventory, and the player puts it on the ground
func drop_item(slot_id: String) -> bool:
	var item = get_item(slot_id)
	if item == null:
		return false
	_set_item(slot_id, null)
	_compact_bag()
	_announce_change(slot_id, "")
	item_dropped.emit(item)
	return true


func _announce_change(from_id: String, to_id: String) -> void:
	changed.emit()
	if EQUIPMENT_SLOTS.get(from_id, "") == "weapon" or EQUIPMENT_SLOTS.get(to_id, "") == "weapon":
		weapons_changed.emit()


# ---------------------------------------------------------------- adding items

# Puts an item in the bag, merging it into existing stacks first if it stacks. The bag has no
# limit, so this always works (but too many items slows the player down).
func add_item(item: Dictionary) -> bool:
	if int(item.get("max_stack", 1)) > 1:
		for existing in bag:
			if _can_stack(item, existing):
				var room: int = int(existing.get("max_stack", 1)) - int(existing.get("count", 1))
				var moved: int = mini(room, int(item.get("count", 1)))
				existing["count"] = int(existing.get("count", 1)) + moved
				item["count"] = int(item.get("count", 1)) - moved
				if item["count"] <= 0:
					changed.emit()
					return true
	bag.append(item)
	changed.emit()
	return true


# Builds an item Dictionary with every key filled in. "extra" adds or overrides keys.
# (Items.create_item uses this; most of the time you'll call that instead.)
func make_item(id: String, item_name: String, slot: String, color: Color, description: String = "", extra: Dictionary = {}) -> Dictionary:
	var item := {
		"id": id,
		"name": item_name,
		"slot": slot,
		"color": color,
		"icon": null,
		"description": description,
		"count": 1,
		"max_stack": 1,
		"stats": {},
	}
	item.merge(extra, true)
	return item


# Which weapon (an index into Weapons.LIST) is in weapon slot 0 or 1, or -1 if it's empty
func get_weapon_index(slot_number: int) -> int:
	var item = equipment.get("weapon%d" % (slot_number + 1))
	if item == null:
		return -1
	return int(item.get("weapon_index", -1))


# Adds up the pips of everything equipped, giving {"pip id": total}. This is what the
# character's stats are, once things like health and resistances are used in combat.
func get_total_pips() -> Dictionary:
	var totals := {}
	for slot_id in equipment:
		var item = equipment[slot_id]
		if item == null:
			continue
		var stats: Dictionary = item.get("stats", {})
		for pip_id in stats:
			totals[pip_id] = int(totals.get(pip_id, 0)) + int(stats[pip_id])
	return totals


# Starting items so there's something to try out. They come from the item database (Items.gd),
# so armor and rings roll random stars and pips.
func _add_demo_items() -> void:
	equipment["weapon1"] = Items.create_item("pistol")
	equipment["weapon2"] = Items.create_item("sword")
	for item_id in ["rifle", "burst_rifle", "shotgun", "spear", "hammer",
			"neon_visor", "chrome_gauntlets", "mag_boots",
			"static_ring", "static_ring", "ember_ring", "scrap"]:
		add_item(Items.create_item(item_id))
