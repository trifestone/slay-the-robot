## ISSUE-017a — Map generator (pure data, AFK).
##
## Generates a deterministic StS-style tree map for one full run:
##   3 acts × 6 floors × 3 columns.
## Each floor's 3 cells are a slot in (col 0, col 1, col 2).
## Floor 0 of each act is the entry row (always 3 Normal nodes).
## Floors 1-4 mix Normal/Elite/Shop/Camp/Event by weighted RNG.
## Floor 5 is a single Boss node centered at col 1; floor-4 nodes
## funnel into it regardless of column.
##
## Edges: floor[i][col] -> floor[i+1] in cols (col-1, col, col+1) clamped
## to 0..2. Forward-only by construction (i strictly increases) so the
## graph is acyclic.
##
## Public API:
##   generate(seed) -> Dictionary {acts: Array[Act]}
##     Act = {act_index: int, floors: Array[Array[Dict]], edges: Array[Array[String]]}
##     Floor cell Dict = {id: String, type: String, act: int, floor: int, col: int}
##     Edge = [src_id, dst_id]
##
##   reachable_from(map, current_id) -> Array[String]
##     Returns ids of nodes directly reachable in one step from current_id.
##     Used by the UI to gate clickable nodes.
##
## Determinism: same seed → same map; tested via test_map_generator.
extends RefCounted

const ACT_COUNT: int = 3
const FLOORS_PER_ACT: int = 6   # 0..5; 0 = entry, 5 = boss
const COLS_PER_FLOOR: int = 3
const BOSS_FLOOR: int = 5

# Weights for interior floors (1..4). Sum is irrelevant; we use cumulative.
const TYPE_WEIGHTS := [
	["Normal", 50],
	["Elite",  15],
	["Shop",   15],
	["Camp",   10],
	["Event",  10],
]


## Build the full map for `seed`.
func generate(seed: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var acts: Array = []
	for a in range(ACT_COUNT):
		acts.append(_build_act(a, rng))
	return {"acts": acts}


## Return ids of nodes one step forward from `current_id`. Empty if the
## current node has no outgoing edges (boss or unknown id).
func reachable_from(map: Dictionary, current_id: String) -> Array:
	var out: Array = []
	for act in map["acts"]:
		for edge in act["edges"]:
			if edge[0] == current_id:
				out.append(edge[1])
	return out


# ---------------------------------------------------------------------------
# Internal
# ---------------------------------------------------------------------------

func _build_act(act_index: int, rng: RandomNumberGenerator) -> Dictionary:
	var floors: Array = []

	# Floor 0: 3 Normal entries
	floors.append(_make_row(act_index, 0, ["Normal", "Normal", "Normal"]))

	# Floors 1..4: weighted random per cell
	for f in range(1, BOSS_FLOOR):
		var row_types: Array = []
		for c in range(COLS_PER_FLOOR):
			row_types.append(_pick_type(rng))
		floors.append(_make_row(act_index, f, row_types))

	# Floor 5: single Boss centered at col 1. Cols 0/2 are placeholder
	# absent cells (null) so the structure stays rectangular but UI ignores them.
	floors.append([null, _make_cell(act_index, BOSS_FLOOR, 1, "Boss"), null])

	# Edges: floor[i][col] -> floor[i+1][col-1..col+1] (or boss at col 1).
	var edges: Array = []
	for f in range(BOSS_FLOOR):
		for c in range(COLS_PER_FLOOR):
			var src = floors[f][c]
			if src == null:
				continue
			if f + 1 == BOSS_FLOOR:
				# Funnel into boss at col 1.
				var boss = floors[BOSS_FLOOR][1]
				edges.append([src["id"], boss["id"]])
			else:
				for dc in [c - 1, c, c + 1]:
					if dc < 0 or dc >= COLS_PER_FLOOR:
						continue
					var dst = floors[f + 1][dc]
					if dst == null:
						continue
					edges.append([src["id"], dst["id"]])

	return {
		"act_index": act_index,
		"floors": floors,
		"edges": edges,
	}


func _make_row(act: int, floor: int, types: Array) -> Array:
	var row: Array = []
	for c in range(types.size()):
		row.append(_make_cell(act, floor, c, types[c]))
	return row


func _make_cell(act: int, floor: int, col: int, type_str: String) -> Dictionary:
	return {
		"id": "a%d_f%d_c%d" % [act, floor, col],
		"type": type_str,
		"act": act,
		"floor": floor,
		"col": col,
	}


func _pick_type(rng: RandomNumberGenerator) -> String:
	var total: int = 0
	for entry in TYPE_WEIGHTS:
		total += int(entry[1])
	var roll: int = rng.randi_range(1, total)
	var acc: int = 0
	for entry in TYPE_WEIGHTS:
		acc += int(entry[1])
		if roll <= acc:
			return String(entry[0])
	return "Normal"  # unreachable
