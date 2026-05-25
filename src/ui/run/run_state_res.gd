## RunStateRes — Resource wrapper around the Dictionary RunState produced by
## core/run.gd, so UI scenes (which use property access like _run.gold) can
## bind to it. Mutations on this resource flow back into the dict via
## the sync helpers, so battle/run logic that operates on the dict still works.
##
## Construction:
##   var rs := RunStateRes.from_dict(dict_state)
##   var dict := rs.to_dict()
##
## NOTE: deck and inventory are full sub-resources here so scenes can call
## inventory.unsocketed / inventory.has_space etc.
extends Resource

const InventoryScript := preload("res://data/inventory.gd")

@export var seed: int                     = 0
@export var player_hp: int                = 80
@export var max_hp: int                   = 80
@export var gold: int                     = 0
@export var dismantle_points: int         = 0
@export var rare_items: int               = 0
@export var battles_won: int              = 0
@export var current_battle: int           = 0
@export var current_node_id: String       = ""
@export var visited: Array                = []   # Array[String]
@export var traits_collected: Array       = []   # Array[String]
@export var deck: Array                   = []   # Array[Card]
@export var inventory: Resource           = null # Inventory
@export var trait_rarity_map: Dictionary  = {}
@export var outcome: String               = "ongoing"


static func from_dict(d: Dictionary) -> Resource:
	var r: Resource = load("res://ui/run/run_state_res.gd").new()
	r.seed             = int(d.get("seed", 0))
	r.player_hp        = int(d.get("player_hp", 80))
	r.max_hp           = int(d.get("max_hp", 80))
	r.gold             = int(d.get("gold", 0))
	r.dismantle_points = int(d.get("dismantle_points", 0))
	r.rare_items       = int(d.get("rare_items", 0))
	r.battles_won      = int(d.get("battles_won", 0))
	r.current_battle   = int(d.get("current_battle", 0))
	r.current_node_id  = String(d.get("current_node_id", ""))
	r.visited          = Array(d.get("visited", []))
	r.traits_collected = Array(d.get("traits_collected", []))
	r.deck             = Array(d.get("deck", []))
	r.trait_rarity_map = Dictionary(d.get("trait_rarity_map", {}))
	r.outcome          = String(d.get("outcome", "ongoing"))

	# Build a real Inventory Resource from raw ids or array of trait Resources.
	var inv: Resource = InventoryScript.new()
	for t in d.get("inventory", []):
		# t may already be a Trait Resource, or just a String id placeholder.
		if t != null and not (t is String):
			inv.unsocketed.append(t)
	r.inventory = inv
	return r


func to_dict() -> Dictionary:
	var inv_arr: Array = []
	if inventory != null:
		for t in inventory.unsocketed:
			inv_arr.append(t)
	return {
		"seed":             seed,
		"player_hp":        player_hp,
		"max_hp":           max_hp,
		"gold":             gold,
		"dismantle_points": dismantle_points,
		"rare_items":       rare_items,
		"battles_won":      battles_won,
		"current_battle":   current_battle,
		"current_node_id":  current_node_id,
		"visited":          visited.duplicate(),
		"traits_collected": traits_collected.duplicate(),
		"deck":             deck.duplicate(),
		"inventory":        inv_arr,
		"trait_rarity_map": trait_rarity_map.duplicate(),
		"outcome":          outcome,
	}
