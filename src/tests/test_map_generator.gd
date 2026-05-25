## ISSUE-017a — Tests for map_generator.
## Verifies structure (3 acts × 6 floors), boss-at-top per act, type
## distribution, forward-only DAG, deterministic-by-seed, reachability.
extends GdUnitTestSuite

const Map := preload("res://core/map_generator.gd")


func _gen(seed: int) -> Dictionary:
	return Map.new().generate(seed)


# ---------------------------------------------------------------------------
# Structure
# ---------------------------------------------------------------------------

func test_generated_map_has_3_acts() -> void:
	var m: Dictionary = _gen(42)
	assert_int(m["acts"].size()).is_equal(3)


func test_each_act_has_6_floors() -> void:
	var m: Dictionary = _gen(42)
	for act in m["acts"]:
		assert_int(act["floors"].size()).is_equal(6)


func test_floor_0_is_three_normal_entries() -> void:
	var m: Dictionary = _gen(42)
	for act in m["acts"]:
		var row: Array = act["floors"][0]
		assert_int(row.size()).is_equal(3)
		for cell in row:
			assert_str(cell["type"]).is_equal("Normal")


func test_boss_at_top_of_each_act() -> void:
	var m: Dictionary = _gen(42)
	for act in m["acts"]:
		var top_row: Array = act["floors"][5]
		# col 1 holds the boss; cols 0/2 are null placeholders
		assert_object(top_row[0]).is_null()
		assert_object(top_row[2]).is_null()
		assert_str(top_row[1]["type"]).is_equal("Boss")


func test_interior_floors_only_use_known_types() -> void:
	var allowed := ["Normal", "Elite", "Shop", "Camp", "Event"]
	var m: Dictionary = _gen(42)
	for act in m["acts"]:
		for f in range(1, 5):
			for cell in act["floors"][f]:
				assert_array(allowed).contains([cell["type"]])


# ---------------------------------------------------------------------------
# Edges / reachability
# ---------------------------------------------------------------------------

func test_edges_are_forward_only() -> void:
	# Edge always goes from floor F to floor F+1. Acyclic by construction.
	var m: Dictionary = _gen(42)
	for act in m["acts"]:
		var by_id: Dictionary = {}
		for f in range(6):
			for cell in act["floors"][f]:
				if cell != null:
					by_id[cell["id"]] = cell
		for edge in act["edges"]:
			var src: Dictionary = by_id[edge[0]]
			var dst: Dictionary = by_id[edge[1]]
			assert_int(int(dst["floor"])).is_equal(int(src["floor"]) + 1)


func test_floor_4_funnels_into_boss() -> void:
	var m: Dictionary = _gen(42)
	for act in m["acts"]:
		var boss_id: String = act["floors"][5][1]["id"]
		# Every non-null floor-4 cell has an edge to boss.
		for cell in act["floors"][4]:
			if cell == null:
				continue
			var found: bool = false
			for edge in act["edges"]:
				if edge[0] == cell["id"] and edge[1] == boss_id:
					found = true
					break
			assert_bool(found).is_true()


func test_reachable_from_returns_one_hop_neighbors() -> void:
	var g: Object = Map.new()
	var m: Dictionary = g.generate(42)
	var act: Dictionary = m["acts"][0]
	var entry_id: String = act["floors"][0][1]["id"]  # middle entry
	var nbrs: Array = g.reachable_from(m, entry_id)
	# col 1 → cols 0,1,2 of floor 1 (all 3 cells present)
	assert_int(nbrs.size()).is_equal(3)
	for nbr_id in nbrs:
		assert_str(String(nbr_id)).starts_with("a0_f1_c")


func test_reachable_from_boss_returns_empty() -> void:
	var g: Object = Map.new()
	var m: Dictionary = g.generate(42)
	var boss_id: String = m["acts"][0]["floors"][5][1]["id"]
	assert_int(g.reachable_from(m, boss_id).size()).is_equal(0)


# ---------------------------------------------------------------------------
# Determinism
# ---------------------------------------------------------------------------

func test_same_seed_yields_same_map() -> void:
	var a: Dictionary = _gen(123)
	var b: Dictionary = _gen(123)
	# Compare every interior cell type
	for ai in range(3):
		for f in range(6):
			for c in range(3):
				var ca = a["acts"][ai]["floors"][f][c]
				var cb = b["acts"][ai]["floors"][f][c]
				if ca == null:
					assert_object(cb).is_null()
				else:
					assert_str(cb["type"]).is_equal(ca["type"])


func test_different_seeds_differ_somewhere() -> void:
	# Two seeds should produce at least one different interior cell type.
	var a: Dictionary = _gen(1)
	var b: Dictionary = _gen(999)
	var diff: bool = false
	for ai in range(3):
		for f in range(1, 5):
			for c in range(3):
				if a["acts"][ai]["floors"][f][c]["type"] != b["acts"][ai]["floors"][f][c]["type"]:
					diff = true
					break
			if diff:
				break
		if diff:
			break
	assert_bool(diff).is_true()


# ---------------------------------------------------------------------------
# Distribution sanity (loose — any seed)
# ---------------------------------------------------------------------------

func test_interior_distribution_includes_variety() -> void:
	# Across all 3 acts × 4 interior floors × 3 cols = 36 cells, we expect
	# at least 3 distinct types (defensive — combats single-type bugs).
	var m: Dictionary = _gen(42)
	var seen: Dictionary = {}
	for act in m["acts"]:
		for f in range(1, 5):
			for cell in act["floors"][f]:
				seen[cell["type"]] = true
	assert_int(seen.size()).is_greater_equal(3)
